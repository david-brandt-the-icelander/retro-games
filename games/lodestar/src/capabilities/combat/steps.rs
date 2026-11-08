//! The combat steps of processing one object in the slot loop (RULES C.4, B.3.4), one function per
//! step, for the flight tick to call in order. Re-orthonormalising (step 3's first part) and the
//! once-per-tick motion bookkeeping (step 4) are the flight capability's `tidy_if_due` and
//! `own_motion_tick`; contact (step 6) is [`crate::capabilities::combat::contact`].

use crate::capabilities::ai::{self, Thought};
use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::combat::damage::{take_damage, Damage};
use crate::capabilities::combat::explosion::{advance_explosion, start_explosion};
use crate::capabilities::combat::kills::{count_kill, on_police_exploded, pay_bounty};
use crate::capabilities::combat::lasers::{in_sights, laser_hit, LaserHit};
use crate::capabilities::combat::missiles::{fix_up_after_removal, try_lock};
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{TypeNumber, POLICE, STATION};

/// What step 3's AI did.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct AiStep {
    /// The object thought this tick.
    pub ran: bool,
    /// What the think's hit did to the player, if it hit.
    pub damage: Option<Damage>,
    /// A kill was counted (a missile was destroyed).
    pub kill: bool,
}

impl AiStep {
    /// True when the player died during the AI: the caller runs the death (RULES C.10.4) and
    /// stops processing this object.
    pub fn player_died(&self) -> bool {
        self.damage == Some(Damage::Died)
    }
}

/// What step 7 did.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SightsStep {
    /// The armed missile locked onto this object (the beep plays).
    pub locked: bool,
    /// The laser hit it.
    pub hit: Option<LaserHit>,
}

/// A finished explosion removed in step 8.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Exploded {
    pub kind: TypeNumber,
    /// Tenths of a credit paid; 0 when none was due or the bounty was lost.
    pub bounty: u16,
    /// The player's lock was on it: the target-lost message showed.
    pub target_lost: bool,
}

/// Step 1, the area blast (RULES C.4, C.9): while the blast is active, a ship that is not the
/// station and neither killed nor exploding is marked killed and a kill counted. Returns whether
/// it was.
pub fn area_blast_step(pilot: &mut Pilot, cockpit: &mut Cockpit, bubble: &mut Bubble, slot: usize) -> bool {
    if cockpit.area_blast == 0 {
        return false;
    }
    let Some(ship) = bubble.get_mut(slot) else {
        return false;
    };
    if ship.is_body() || ship.kind == STATION || ship.flags.killed || ship.flags.exploding {
        return false;
    }
    ship.flags.killed = true;
    count_kill(pilot, cockpit);
    true
}

/// Step 2, the explosion start (RULES C.4, C.12 item 1): a killed ship that is not yet
/// exploding starts to explode, drawing its four seeds. Returns whether it started.
pub fn explosion_start_step(bubble: &mut Bubble, slot: usize, random: &mut MainGenerator) -> bool {
    let Some(ship) = bubble.get_mut(slot) else {
        return false;
    };
    if ship.is_body() || !ship.flags.killed || ship.flags.exploding {
        return false;
    }
    start_explosion(ship, random);
    true
}

/// Step 3's AI (RULES C.4, C.5): when [`ai::due`] (C is the cockpit's counter), the object
/// thinks; its hit on the player is applied (RULES C.10.2), then a destroyed missile's kill is
/// counted. Call the flight capability's `tidy_if_due` first.
pub fn ai_step(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    slot: usize,
    random: &mut MainGenerator,
) -> AiStep {
    let due = bubble.get(slot).is_some_and(|o| ai::due(o, cockpit.counter, slot));
    if !due {
        return AiStep::default();
    }
    let Thought { hit, kill } = ai::think(bubble, slot, cockpit, random);
    let damage = hit.map(|h| take_damage(pilot, cockpit, random, h.damage, h.from_z));
    if kill {
        count_kill(pilot, cockpit);
    }
    AiStep { ran: true, damage, kill }
}

/// Step 5, explosion progress (RULES C.4, C.12 item 3): an exploding object's cloud grows; when
/// it is spent the object is marked killed. Returns whether it was spent this tick.
pub fn explosion_progress_step(bubble: &mut Bubble, slot: usize) -> bool {
    bubble.get_mut(slot).is_some_and(advance_explosion)
}

/// Step 7, the sights (RULES C.4, C.6.3, C.7.1, C.6.4): only while the flight view shows
/// (deliberate difference 9), for a ship in the active mount's sights: first the armed missile's
/// lock, then the laser hit.
pub fn sights_step(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    slot: usize,
    random: &mut MainGenerator,
    flight_view: bool,
) -> SightsStep {
    let seen = flight_view && bubble.get(slot).is_some_and(|o| in_sights(o, cockpit.active_mount));
    if !seen {
        return SightsStep::default();
    }
    let locked = try_lock(cockpit, bubble, slot);
    let hit = laser_hit(pilot, cockpit, bubble, slot, random);
    SightsStep { locked, hit }
}

/// Step 8's first part, a finished explosion (RULES C.4, C.13, C.15.2): an object both killed
/// and exploding is removed: a police interceptor sets legal status bit 6, its bounty is paid
/// (RULES C.13's message rule), it leaves the bubble and the missiles and the lock follow
/// (RULES C.7.4). Returns `None` when the object is still there; the caller then runs the
/// removal for distance (RULES B.9.4).
pub fn removal_step(pilot: &mut Pilot, cockpit: &mut Cockpit, bubble: &mut Bubble, slot: usize) -> Option<Exploded> {
    let object = bubble.get(slot)?;
    if !(object.flags.killed && object.flags.exploding) {
        return None;
    }
    let kind = object.kind;
    if kind == POLICE {
        on_police_exploded(pilot);
    }
    let bounty = pay_bounty(pilot, cockpit, kind);
    bubble.remove(slot);
    let target_lost = fix_up_after_removal(cockpit, bubble, slot);
    Some(Exploded { kind, bounty, target_lost })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::player_missile;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::cockpit::Message;
    use crate::capabilities::ships::{ALIEN_MOTHERSHIP, CANISTER, HEAVY_FIGHTER, MISSILE, PLANET_A, SMALL_PIRATE_A, SUN};
    use crate::capabilities::space::Vec3;

    fn world() -> (Pilot, Cockpit, Bubble) {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 80_000.0)));
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, -300_000.0)));
        (Pilot::start(), Cockpit::new(), b)
    }

    #[test]
    fn the_area_blast_kills_everything_but_the_station_and_bodies() {
        let (mut pilot, mut cockpit, mut b) = world();
        let mut station = Object::new(STATION, Vec3::ZERO);
        station.ai = 1;
        b.replace(1, station);
        let canister = b.add(Object::new(CANISTER, Vec3::ZERO)).unwrap();
        let missile = b.add(Object::new(MISSILE, Vec3::ZERO)).unwrap();
        let mut dead = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        dead.flags.exploding = true;
        let exploding = b.add(dead).unwrap();
        assert!(!area_blast_step(&mut pilot, &mut cockpit, &mut b, canister), "inactive");
        cockpit.area_blast = 4;
        let killed: Vec<bool> = (0..b.len()).map(|s| area_blast_step(&mut pilot, &mut cockpit, &mut b, s)).collect();
        assert_eq!(killed, [false, false, true, true, false]);
        assert_eq!(pilot.kills, 2);
        assert!(b.get(missile).unwrap().flags.killed);
        assert!(!b.get(exploding).unwrap().flags.killed);
        assert!(!area_blast_step(&mut pilot, &mut cockpit, &mut b, canister), "already killed");
    }

    #[test]
    fn a_killed_ship_starts_exploding_once() {
        let (_, _, mut b) = world();
        let mut s = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        s.flags.killed = true;
        let slot = b.add(s).unwrap();
        let mut random = MainGenerator::new();
        assert!(explosion_start_step(&mut b, slot, &mut random));
        assert!(!explosion_start_step(&mut b, slot, &mut random));
        let mut expected = MainGenerator::new();
        expected.discard(4);
        assert_eq!(random, expected);
        b.get_mut(0).unwrap().flags.killed = true;
        assert!(!explosion_start_step(&mut b, 0, &mut random), "bodies never explode");
    }

    #[test]
    fn the_ai_step_applies_the_hit_and_reports_a_death() {
        let (mut pilot, mut cockpit, mut b) = world();
        let mut s = Object::new(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 1000.0));
        s.ai = 0xC0;
        let slot = b.add(s).unwrap();
        cockpit.counter = 2; // (2 XOR 2) AND 7 = 0
        let mut random = MainGenerator::new();
        let step = ai_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(step, AiStep { ran: true, damage: Some(Damage::Shielded), kill: false });
        assert_eq!(cockpit.fore_shield, 255 - 18);
        cockpit.fore_shield = 0;
        cockpit.energy = 18;
        let step = ai_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert!(step.player_died());
        cockpit.counter = 3;
        assert_eq!(ai_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random), AiStep::default());
    }

    #[test]
    fn a_destroyed_missile_counts_a_kill_after_its_damage() {
        let (mut pilot, mut cockpit, mut b) = world();
        let mut m = Object::new(MISSILE, Vec3::new(0.0, 0.5, 0.5));
        m.ai = player_missile(7);
        let slot = b.add(m).unwrap();
        cockpit.start_ecm(false);
        cockpit.counter = 1;
        let step = ai_step(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::with_seed([0, 0, 0, 0x80]));
        assert_eq!(step, AiStep { ran: true, damage: Some(Damage::Shielded), kill: true });
        assert_eq!((pilot.kills, cockpit.fore_shield), (1, 175));
    }

    #[test]
    fn explosion_progress_marks_the_ship_killed_when_spent() {
        let (_, _, mut b) = world();
        let mut s = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        s.flags.exploding = true;
        s.explosion.counter = 250;
        let slot = b.add(s).unwrap();
        assert!(!explosion_progress_step(&mut b, slot));
        assert!(explosion_progress_step(&mut b, slot));
        assert!(b.get(slot).unwrap().flags.killed);
        assert!(!explosion_progress_step(&mut b, 0));
    }

    #[test]
    fn the_sights_lock_then_hit_only_in_the_flight_view() {
        let (mut pilot, mut cockpit, mut b) = world();
        let slot = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 10.0, 3000.0))).unwrap();
        cockpit.missile.armed = true;
        cockpit.shot_damage = 15;
        let mut random = MainGenerator::new();
        assert_eq!(sights_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random, false), SightsStep::default());
        let step = sights_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random, true);
        assert_eq!(step, SightsStep { locked: true, hit: Some(LaserHit::Damaged) });
        assert_eq!(cockpit.missile.target, Some(slot));
        assert_eq!(b.get(slot).unwrap().energy, 49);
        assert_eq!(sights_step(&mut pilot, &mut cockpit, &mut b, 0, &mut random, true), SightsStep::default());
    }

    #[test]
    fn one_shot_hits_every_ship_in_line() {
        let (mut pilot, mut cockpit, mut b) = world();
        let near = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 500.0))).unwrap();
        let far = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 40_000.0))).unwrap();
        cockpit.shot_damage = 15;
        let mut random = MainGenerator::new();
        for slot in 0..b.len() {
            sights_step(&mut pilot, &mut cockpit, &mut b, slot, &mut random, true);
        }
        assert_eq!((b.get(near).unwrap().energy, b.get(far).unwrap().energy), (49, 49));
    }

    #[test]
    fn a_finished_explosion_pays_and_leaves() {
        let (mut pilot, mut cockpit, mut b) = world();
        let mut s = Object::new(ALIEN_MOTHERSHIP, Vec3::ZERO);
        s.flags.killed = true;
        s.flags.exploding = true;
        let slot = b.add(s).unwrap();
        let mut m = Object::new(MISSILE, Vec3::ZERO);
        m.ai = player_missile(slot);
        b.add(m);
        cockpit.missile.target = Some(slot);
        let r = removal_step(&mut pilot, &mut cockpit, &mut b, slot);
        assert_eq!(r, Some(Exploded { kind: ALIEN_MOTHERSHIP, bounty: 450, target_lost: true }));
        assert_eq!(pilot.cash, 1_450);
        assert_eq!(b.len(), 3);
        assert_eq!(b.get(slot).unwrap().ai, 0, "the missile chasing it goes unguided");
        assert_eq!(cockpit.message, Some(Message::TargetLost), "the later message replaces the bounty's");
        assert_eq!(removal_step(&mut pilot, &mut cockpit, &mut b, slot), None);
    }

    #[test]
    fn a_police_explosion_marks_the_record() {
        let (mut pilot, mut cockpit, mut b) = world();
        let mut s = Object::new(POLICE, Vec3::ZERO);
        s.flags.killed = true;
        s.flags.exploding = true;
        let slot = b.add(s).unwrap();
        cockpit.show(Message::EnergyLow);
        let r = removal_step(&mut pilot, &mut cockpit, &mut b, slot).unwrap();
        assert_eq!(r.bounty, 0);
        assert_eq!(pilot.legal, 64);
    }

    #[test]
    fn a_bounty_lost_to_a_showing_message() {
        let (mut pilot, mut cockpit, mut b) = world();
        for _ in 0..2 {
            let mut s = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
            s.flags.killed = true;
            s.flags.exploding = true;
            b.add(s);
        }
        let first = removal_step(&mut pilot, &mut cockpit, &mut b, 2).unwrap();
        let second = removal_step(&mut pilot, &mut cockpit, &mut b, 2).unwrap();
        assert_eq!((first.bounty, second.bounty), (60, 0));
        assert_eq!(pilot.cash, 1_060);
    }
}
