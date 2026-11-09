//! The flight tick logic (RULES B.3.3, B.3.4, C.4, D.3.6), in Flight mode and in its dying form.
//! Each step calls the capability or feature that owns its rule; this file owns only the order.

use super::{Event, FlyInSystem, HeldActions, Mode, Press, TunnelKind};
use crate::capabilities::combat::{self, Contact, Damage};
use crate::capabilities::flight::{self, apply_speed_keys, HeldControls};
use crate::features::death::Cause;
use crate::features::docking::{self, DockingContact};
use crate::features::escape_pod;
use crate::features::hyperspace;
use crate::features::in_system_jump::in_system_jump;
use crate::features::planet_and_sun::{planet_and_sun_checks, BodyCheck};
use crate::features::spawning::periodic_spawn;
use crate::features::station;

impl FlyInSystem {
    /// One tick of flight logic (RULES D.3.6). `dying` runs it without player controls or
    /// actions and without periodic spawning.
    pub(super) fn flight_logic(&mut self, held: HeldActions, dying: bool) {
        // 1. Attitude.
        let controls = if dying { HeldControls::NONE } else { controls(held) };
        self.cockpit.attitude.tick(controls);

        // 2. Player actions.
        combat::start_key_handling(&mut self.cockpit);
        if !dying {
            self.cockpit.speed = apply_speed_keys(self.cockpit.speed, controls);
            if self.queued_actions() {
                let flight_view = self.flight_view();
                let pilot = &self.pilots.playing;
                if combat::fire_lasers(pilot, &mut self.cockpit, &mut self.random, held.fire, flight_view).is_some() {
                    self.events.push(Event::LaserFired);
                }
            }
        }
        self.queued.clear();

        // 3. The slot loop.
        self.slot_loop();

        // 4. Area blast and recharge.
        combat::count_down_area_blast(&mut self.cockpit);
        if self.cockpit.recharge_due() {
            self.cockpit.recharge(self.pilots.playing.fitted.energy_booster);
        }

        // 5. The station appears.
        station::station_appearance(&mut self.cockpit, &mut self.bubble);

        // 6. Planet and sun; a crash or burn ends the tick.
        if !self.cockpit.misjump {
            match planet_and_sun_checks(&mut self.pilots.playing, &mut self.cockpit, &self.bubble) {
                BodyCheck::Clear => {}
                BodyCheck::Crashed => return self.die(Cause::Crashed),
                BodyCheck::Burned => return self.die(Cause::Burned),
            }
        }

        // 7. Laser and E.C.M. bookkeeping.
        if combat::laser_and_ecm_bookkeeping(&mut self.cockpit) {
            self.events.push(Event::EcmStopped);
        }

        // 8. The message timer.
        self.cockpit.count_down_message();

        // 9. The main counter and periodic spawning.
        let dying_now = matches!(self.mode, Mode::Dying(_));
        if self.cockpit.count_down_counter() && !dying_now {
            let government = self.navigation.current_system(&self.pilots.playing).government;
            periodic_spawn(
                &self.pilots.playing,
                &self.cockpit,
                &mut self.bubble,
                &mut self.delay,
                government,
                &mut self.random,
            );
        }

        // 10. Laser heat.
        self.cockpit.cool_laser();

        // 11. The hyperspace countdown. A pod launched this tick takes the player out of the
        // countdown's hands: it runs only in Flight and Death modes.
        let counting = matches!(self.mode, Mode::Flight | Mode::Dying(_));
        if let Some(destination) = self.countdown.tick().filter(|_| counting) {
            let tunnel = hyperspace::jump(
                destination,
                &mut self.pilots.playing,
                &mut self.navigation,
                &mut self.cockpit,
                &mut self.random,
            );
            self.start_tunnel(TunnelKind::Hyperspace(tunnel));
        }
    }

    /// The queued flight actions in press order (RULES B.3.3 step 2). Returns false when the
    /// escape pod or a successful auto-dock ended the step: later actions are dropped and the
    /// lasers do not fire.
    fn queued_actions(&mut self) -> bool {
        let queued = std::mem::take(&mut self.queued);
        for press in queued {
            let pilot = &mut self.pilots.playing;
            match press {
                Press::UnarmMissile => {
                    if combat::unarm_missile(pilot, &mut self.cockpit) {
                        self.events.push(Event::MissileUnarmed);
                    }
                }
                Press::ArmMissile => {
                    if combat::arm_missile(pilot, &mut self.cockpit) {
                        self.events.push(Event::MissileArmed);
                    }
                }
                Press::FireMissile => {
                    let fired = combat::fire_missile(pilot, &mut self.cockpit, &mut self.bubble);
                    self.events.push(Event::MissileFired(fired));
                }
                Press::AreaBlast => {
                    if combat::trigger_area_blast(pilot, &mut self.cockpit) {
                        self.events.push(Event::AreaBlast);
                    }
                }
                Press::EscapePod => {
                    if let Some(escape) = escape_pod::launch_pod(pilot, &mut self.cockpit, &mut self.bubble) {
                        self.set_mode(Mode::Escape(escape));
                        return false;
                    }
                }
                Press::InSystemJump => {
                    let jump = in_system_jump(&mut self.cockpit, &mut self.bubble, &mut self.delay);
                    self.events.push(Event::InSystemJump(jump));
                }
                Press::Ecm => {
                    if combat::fire_ecm(pilot, &mut self.cockpit) {
                        self.events.push(Event::EcmStarted);
                    }
                }
                Press::AutoDock if docking::auto_dock(pilot, &self.cockpit, &self.bubble) => {
                    self.dock();
                    return false;
                }
                _ => {}
            }
        }
        true
    }

    /// Docking succeeded: the countdown is cleared and the docking tunnel starts; the rest of the
    /// tick still runs (RULES D.3.11, B.23 Q-B13).
    fn dock(&mut self) {
        docking::dock(&mut self.countdown);
        self.start_tunnel(TunnelKind::Docking);
    }

    /// RULES B.3.3 step 3: every slot in order; a slot whose object was removed is processed
    /// again, and a death part-way carries on from the next slot over the new bubble (Q-B14).
    fn slot_loop(&mut self) {
        let mut slot = 0;
        while slot < self.bubble.len() {
            if !self.process(slot) {
                slot += 1;
            }
        }
    }

    /// Processes the object in `slot` (RULES C.4, B.3.4). Returns true when it left the slot,
    /// so the slot is processed again.
    fn process(&mut self, slot: usize) -> bool {
        let pilot = &mut self.pilots.playing;
        // 1. Area blast; 2. explosion start.
        combat::area_blast_step(pilot, &mut self.cockpit, &mut self.bubble, slot);
        combat::explosion_start_step(&mut self.bubble, slot, &mut self.random);

        // 3. Tidy and AI.
        let Some(object) = self.bubble.get(slot).copied() else { return false };
        if !object.is_body() && !object.flags.killed && !object.flags.exploding {
            if let Some(o) = self.bubble.get_mut(slot) {
                flight::tidy_if_due(o, self.cockpit.counter, slot);
            }
            let thought = combat::ai_step(pilot, &mut self.cockpit, &mut self.bubble, slot, &mut self.random);
            if let Some(damage) = thought.damage {
                self.events.push(Event::Damaged(damage));
            }
            if thought.player_died() {
                self.die(Cause::Damage);
                return false;
            }
        }

        // 4. Own motion.
        if let Some(o) = self.bubble.get_mut(slot).filter(|o| !o.is_body()) {
            flight::own_motion_tick(o);
        }

        // 5. Explosion progress.
        combat::explosion_progress_step(&mut self.bubble, slot);

        // 6. Contact, except the escape pod's hull on its launch tick (deliberate difference 7).
        let spared = matches!(self.mode, Mode::Escape(e) if e.spares(slot));
        if !spared && self.contact(slot) {
            return false;
        }

        // 7. Sights.
        let flight_view = self.flight_view();
        let pilot = &mut self.pilots.playing;
        let sights = combat::sights_step(pilot, &mut self.cockpit, &mut self.bubble, slot, &mut self.random, flight_view);
        if sights.locked {
            self.events.push(Event::MissileLocked { slot });
        }
        if sights.hit.is_some() {
            self.events.push(Event::LaserHit { slot });
        }

        // 8. Removal.
        if let Some(exploded) = combat::removal_step(pilot, &mut self.cockpit, &mut self.bubble, slot) {
            self.events.push(Event::Exploded { kind: exploded.kind, bounty: exploded.bounty });
            return true;
        }
        let Some(object) = self.bubble.get(slot).copied() else { return false };
        if station::too_far(&object) {
            if object.kind == crate::capabilities::ships::STATION && slot == station::STATION_SLOT {
                station::station_leaves(&mut self.cockpit, &mut self.bubble);
            } else {
                self.bubble.remove(slot);
                combat::fix_up_after_removal(&mut self.cockpit, &mut self.bubble, slot);
            }
            return true;
        }
        false
    }

    /// Step 6, contact (RULES C.11, B.12). Returns true when the player died, which ends this
    /// object's processing.
    fn contact(&mut self, slot: usize) -> bool {
        let pilot = &mut self.pilots.playing;
        match combat::contact(pilot, &mut self.cockpit, &mut self.bubble, slot, &mut self.random) {
            Contact::None => false,
            Contact::Scooped { item, gained } => {
                self.events.push(Event::Scooped { item, gained });
                false
            }
            Contact::Collided(damage) => self.damaged(damage, Cause::Damage),
            Contact::DockingBox => {
                let Some(station) = self.bubble.get(slot).copied() else { return false };
                match docking::docking_contact(&station) {
                    DockingContact::OutOfBox => false,
                    DockingContact::Docks => {
                        if !matches!(self.mode, Mode::Dying(_) | Mode::Tunnel { .. }) {
                            self.dock();
                        }
                        false
                    }
                    DockingContact::Fails => {
                        let z = station.position.z;
                        let damage = combat::failed_docking(pilot, &mut self.cockpit, &mut self.random, z);
                        self.damaged(damage, Cause::Docking)
                    }
                }
            }
        }
    }

    fn damaged(&mut self, damage: Damage, cause: Cause) -> bool {
        self.events.push(Event::Damaged(damage));
        if damage == Damage::Died {
            self.die(cause);
            true
        } else {
            false
        }
    }
}

fn controls(held: HeldActions) -> HeldControls {
    HeldControls {
        roll_left: held.roll_left,
        roll_right: held.roll_right,
        climb: held.climb,
        dive: held.dive,
        speed_up: held.speed_up,
        slow_down: held.slow_down,
    }
}
