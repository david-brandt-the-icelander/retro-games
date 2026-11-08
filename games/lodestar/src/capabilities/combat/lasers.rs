//! The player's lasers: firing from the active mount, heat and cooldown (RULES C.6.2), the sights
//! test (RULES C.6.3) and what a hit does (RULES C.6.4).

use crate::capabilities::ai::{anger, launch_child, ACTIVE};
use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::{Cockpit, LASER_TOO_HOT};
use crate::capabilities::combat::kills::count_kill;
use crate::capabilities::pilot::{Mount, Pilot};
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{self, CANISTER, STATION, TRADER};
use crate::capabilities::space::Vec3;

/// A mount's laser value: bits 0..6 the power, bit 7 the beam type (RULES A.7.1, D.4.1).
pub const POWER_BITS: u8 = 0x7F;
pub const BEAM_BIT: u8 = 0x80;
/// The cooldown after a pulse shot; a beam laser's is 0.
pub const PULSE_COOLDOWN: u8 = 10;
/// The cooldown falls by this at the end of every flight tick.
pub const COOLDOWN_STEP: u8 = 5;
/// Laser heat gained per shot, capped at 255.
pub const HEAT_PER_SHOT: u8 = 8;
/// The sights' square cross-section: |x′| and |y′| below this.
pub const SIGHTS_HALF_WIDTH: f64 = 256.0;
/// The beam's convergence point is jittered by (byte AND 7) − 4 on each axis.
const JITTER_BITS: u8 = 7;
const JITTER_CENTRE: i8 = 4;

/// A shot fired this tick.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Shot {
    /// The damage every ship in the sights takes this tick.
    pub damage: u8,
    /// The two bytes RULES draws for the beam's convergence point, as offsets −4..3 from the
    /// view centre (x, then y). Drawn for parity; the picture may use them.
    pub jitter: [i8; 2],
}

/// What a laser hit did to the ship in the sights (RULES C.6.4).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LaserHit {
    /// It lost energy and lives.
    Damaged,
    /// The station's energy reached 0: it is not destroyed but turns hostile.
    StationTurned,
    /// It was marked killed. `canisters` is how many launches were tried (types 1..7);
    /// `kill` is whether a kill was counted (types 1..7 only).
    Destroyed { canisters: u8, kill: bool },
}

/// The start of the tick's key handling: this tick's shot damage is 0 until the laser fires
/// (RULES C.6.2, D.3.6 step 2).
pub fn start_key_handling(cockpit: &mut Cockpit) {
    cockpit.shot_damage = 0;
}

/// Fires the active mount's laser if it can (RULES C.6.2): the cooldown is 0, fire is held, the
/// heat is below 242, the active mount has a laser and the flight view shows (deliberate
/// difference 9). Then the shot damage is the laser's power, two bytes are drawn for the beam's
/// convergence point, heat +8 (capped), energy drained by 1, and the cooldown becomes 10 for a
/// pulse laser, 0 for a beam laser.
pub fn fire_lasers(
    pilot: &Pilot,
    cockpit: &mut Cockpit,
    random: &mut MainGenerator,
    fire_held: bool,
    flight_view: bool,
) -> Option<Shot> {
    let laser = pilot.lasers.get(cockpit.active_mount).copied().unwrap_or(0);
    let can_fire = cockpit.laser_cooldown == 0
        && fire_held
        && cockpit.laser_temperature < LASER_TOO_HOT
        && laser != 0
        && flight_view;
    if !can_fire {
        return None;
    }
    cockpit.shot_damage = laser & POWER_BITS;
    let jitter = [jitter(random.byte()), jitter(random.byte())];
    cockpit.laser_temperature = cockpit.laser_temperature.saturating_add(HEAT_PER_SHOT);
    cockpit.drain_energy();
    cockpit.laser_cooldown = if laser & BEAM_BIT != 0 { 0 } else { PULSE_COOLDOWN };
    Some(Shot { damage: cockpit.shot_damage, jitter })
}

fn jitter(byte: u8) -> i8 {
    (byte & JITTER_BITS) as i8 - JITTER_CENTRE
}

/// The end-of-tick cooldown (RULES C.6.2, D.3.6 step 7): it falls by 5, not below 0.
pub fn cool_down(cockpit: &mut Cockpit) {
    cockpit.laser_cooldown = cockpit.laser_cooldown.saturating_sub(COOLDOWN_STEP);
}

/// A position in a mount's frame, forward axis z′ (RULES C.6.3, B.20): front (x, y, z), rear
/// (−x, y, −z), left (z, y, −x), right (−z, y, x). Any other mount number reads as front.
pub fn mount_frame(position: Vec3, mount: Mount) -> Vec3 {
    let Vec3 { x, y, z } = position;
    match mount {
        1 => Vec3::new(-x, y, -z),
        2 => Vec3::new(z, y, -x),
        3 => Vec3::new(-z, y, x),
        _ => Vec3::new(x, y, z),
    }
}

/// The sights test (RULES C.6.3): the object is not a planet or the sun and not exploding, and in
/// the mount's frame z′ > 0, |x′| and |y′| are below 256, and ⌊|x′|⌋² + ⌊|y′|⌋² ≤ its hit size.
/// There is no range limit.
pub fn in_sights(object: &Object, mount: Mount) -> bool {
    if object.is_body() || object.flags.exploding {
        return false;
    }
    let Some(stats) = ships::stats(object.kind) else {
        return false;
    };
    let p = mount_frame(object.position, mount);
    if p.z <= 0.0 || p.x.abs() >= SIGHTS_HALF_WIDTH || p.y.abs() >= SIGHTS_HALF_WIDTH {
        return false;
    }
    let (fx, fy) = (p.x.abs().floor() as u32, p.y.abs().floor() as u32);
    fx * fx + fy * fy <= u32::from(stats.hit_size)
}

/// A laser hit on the ship in `slot`, which the caller found in the sights (RULES C.6.4). Does
/// nothing (and returns `None`) when no shot was fired this tick. Otherwise the ship loses the
/// shot's damage (planets and the sun are never hit); at 0 energy the station turns hostile and any other ship is marked killed,
/// with types 1..7 drawing a pair and, if A's top bit is set, launching (A AND canisters)
/// canisters (each drawing its own pair), then counting a kill. Every hit angers the ship.
pub fn laser_hit(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    slot: usize,
    random: &mut MainGenerator,
) -> Option<LaserHit> {
    let damage = cockpit.shot_damage;
    if damage == 0 {
        return None;
    }
    let ship = bubble.get_mut(slot).filter(|o| !o.is_body())?;
    let outcome = if ship.energy > damage {
        ship.energy -= damage;
        LaserHit::Damaged
    } else {
        ship.energy = 0;
        if ship.kind == STATION {
            ship.ai |= ACTIVE;
            LaserHit::StationTurned
        } else {
            ship.flags.killed = true;
            let parent = *ship;
            if (1..=TRADER).contains(&parent.kind) {
                let roll = random.draw();
                let mut canisters = 0;
                if roll.a & 0x80 != 0 {
                    canisters = roll.a & ships::stats(parent.kind).map_or(0, |s| s.canisters);
                    for _ in 0..canisters {
                        launch_child(bubble, &parent, CANISTER, 0, random);
                    }
                }
                count_kill(pilot, cockpit);
                LaserHit::Destroyed { canisters, kill: true }
            } else {
                LaserHit::Destroyed { canisters: 0, kill: false }
            }
        }
    };
    anger(bubble, slot);
    Some(outcome)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::{find, next_draw};
    use crate::capabilities::pilot::{BEAM_LASER, PULSE_LASER};
    use crate::capabilities::ships::{ASTEROID, HEAVY_FIGHTER, MISSILE, PLANET_A, SMALL_PIRATE_A, SUN};
    use crate::capabilities::space::SignMagnitude;

    fn ready() -> (Pilot, Cockpit) {
        (Pilot::start(), Cockpit::new())
    }

    #[test]
    fn a_pulse_laser_fires_draws_two_bytes_heats_drains_and_cools_down() {
        let (pilot, mut cockpit) = ready();
        let mut random = MainGenerator::new();
        let shot = fire_lasers(&pilot, &mut cockpit, &mut random, true, true).unwrap();
        // The first two bytes of the starting stream are 0xAC and 0xE1: 4 − 4 and 1 − 4.
        assert_eq!(shot, Shot { damage: 15, jitter: [0, -3] });
        assert_eq!(cockpit.shot_damage, 15);
        assert_eq!((cockpit.laser_temperature, cockpit.energy, cockpit.laser_cooldown), (8, 254, 10));
        let mut expected = MainGenerator::new();
        expected.discard(2);
        assert_eq!(random, expected);
    }

    #[test]
    fn a_pulse_laser_fires_every_second_tick_and_a_beam_every_tick() {
        for (laser, shots) in [(PULSE_LASER, 6), (BEAM_LASER, 12)] {
            let (mut pilot, mut cockpit) = ready();
            pilot.lasers[0] = laser;
            let mut random = MainGenerator::new();
            let mut fired = 0;
            for _ in 0..12 {
                start_key_handling(&mut cockpit);
                if fire_lasers(&pilot, &mut cockpit, &mut random, true, true).is_some() {
                    fired += 1;
                }
                cool_down(&mut cockpit);
            }
            assert_eq!(fired, shots, "laser {laser}");
            assert_eq!(cockpit.laser_temperature, 8 * shots);
        }
    }

    #[test]
    fn the_beam_lasers_power_drops_its_top_bit() {
        let (mut pilot, mut cockpit) = ready();
        pilot.lasers[0] = BEAM_LASER;
        let shot = fire_lasers(&pilot, &mut cockpit, &mut MainGenerator::new(), true, true).unwrap();
        assert_eq!((shot.damage, cockpit.laser_cooldown), (15, 0));
    }

    #[test]
    fn each_condition_stops_the_laser_without_a_draw() {
        let check = |setup: &dyn Fn(&mut Pilot, &mut Cockpit), held: bool, view: bool| {
            let (mut pilot, mut cockpit) = ready();
            setup(&mut pilot, &mut cockpit);
            let mut random = MainGenerator::new();
            let fired = fire_lasers(&pilot, &mut cockpit, &mut random, held, view);
            assert!(fired.is_none());
            assert_eq!(cockpit.shot_damage, 0);
            assert_eq!(random, MainGenerator::new());
        };
        check(&|_, c| c.laser_cooldown = 5, true, true);
        check(&|_, _| {}, false, true);
        check(&|_, c| c.laser_temperature = 242, true, true);
        check(&|_, c| c.active_mount = 1, true, true);
        check(&|_, _| {}, true, false);
        let (pilot, mut cockpit) = ready();
        cockpit.laser_temperature = 241;
        assert!(fire_lasers(&pilot, &mut cockpit, &mut MainGenerator::new(), true, true).is_some());
        assert_eq!(cockpit.laser_temperature, 249);
    }

    #[test]
    fn the_hottest_shot_and_the_energy_floor() {
        let (mut pilot, mut cockpit) = ready();
        pilot.lasers[2] = BEAM_LASER;
        cockpit.active_mount = 2;
        cockpit.laser_temperature = 241;
        cockpit.energy = 1;
        fire_lasers(&pilot, &mut cockpit, &mut MainGenerator::new(), true, true).unwrap();
        assert_eq!((cockpit.laser_temperature, cockpit.energy), (249, 1), "fires from the left mount");
        assert!(fire_lasers(&pilot, &mut cockpit, &mut MainGenerator::new(), true, true).is_none());
    }

    #[test]
    fn the_mount_frames() {
        let p = Vec3::new(1.0, 2.0, 3.0);
        assert_eq!(mount_frame(p, 0), Vec3::new(1.0, 2.0, 3.0));
        assert_eq!(mount_frame(p, 1), Vec3::new(-1.0, 2.0, -3.0));
        assert_eq!(mount_frame(p, 2), Vec3::new(3.0, 2.0, -1.0));
        assert_eq!(mount_frame(p, 3), Vec3::new(-3.0, 2.0, 1.0));
    }

    #[test]
    fn the_sights_are_a_cylinder_clipped_to_a_square() {
        // Station hit size 22500: radius 150.
        let at = |x: f64, y: f64, z: f64| Object::new(STATION, Vec3::new(x, y, z));
        assert!(in_sights(&at(0.0, 0.0, 60_000.0), 0), "no range limit");
        assert!(!in_sights(&at(0.0, 0.0, 0.0), 0), "z′ must be above 0");
        assert!(in_sights(&at(90.9, 120.9, 10.0), 0), "90² + 120² = 22500");
        assert!(!in_sights(&at(91.0, 120.0, 10.0), 0), "91² + 120² > 22500");
        assert!(in_sights(&at(-150.5, 0.0, 10.0), 0), "floored magnitudes");
        assert!(!in_sights(&at(0.0, 0.0, 10.0), 1), "the rear mount looks along −z");
        assert!(in_sights(&at(0.0, 0.0, -10.0), 1));
        assert!(in_sights(&at(-10.0, 0.0, 0.0), 2), "left: z′ = −x");
        assert!(in_sights(&at(10.0, 0.0, 0.0), 3), "right: z′ = x");
        assert!(!in_sights(&at(10.0, 0.0, 0.0), 2));
    }

    #[test]
    fn exploding_ships_planets_and_the_sun_are_never_in_the_sights() {
        let mut o = Object::new(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 100.0));
        o.flags.killed = true;
        assert!(in_sights(&o, 0), "merely killed still counts");
        o.flags.exploding = true;
        assert!(!in_sights(&o, 0));
        assert!(!in_sights(&Object::new(PLANET_A, Vec3::new(0.0, 0.0, 100.0)), 0));
        assert!(!in_sights(&Object::new(SUN, Vec3::new(0.0, 0.0, 100.0)), 0));
    }

    #[test]
    fn the_players_own_missile_starts_in_the_front_sights() {
        let m = Object::new(MISSILE, Vec3::new(0.0, -28.0, 14.0));
        assert!(in_sights(&m, 0), "28² = 784 ≤ the missile's hit size");
    }

    fn fired() -> (Pilot, Cockpit) {
        let (pilot, mut cockpit) = ready();
        cockpit.shot_damage = 15;
        (pilot, cockpit)
    }

    #[test]
    fn no_shot_no_hit() {
        let (mut pilot, mut cockpit) = ready();
        let mut b = Bubble::new();
        let slot = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 100.0))).unwrap();
        assert_eq!(laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut MainGenerator::new()), None);
        assert_eq!(b.get(slot).unwrap().energy, 64);
        cockpit.shot_damage = 15;
        let planet = b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 100.0))).unwrap();
        assert_eq!(laser_hit(&mut pilot, &mut cockpit, &mut b, planet, &mut MainGenerator::new()), None);
        assert!(!b.get(planet).unwrap().flags.killed);
    }

    #[test]
    fn a_hit_takes_fifteen_and_angers() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        let mut p = Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 100.0));
        p.ai = 0x40;
        let slot = b.add(p).unwrap();
        let mut random = MainGenerator::new();
        assert_eq!(laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut random), Some(LaserHit::Damaged));
        let s = b.get(slot).unwrap();
        assert_eq!((s.energy, s.ai, s.acceleration, s.pitch), (49, 0xC0, 2, SignMagnitude::new(false, 4)));
        assert_eq!(random, MainGenerator::new());
    }

    #[test]
    fn the_station_turns_hostile_at_zero_but_is_not_destroyed() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::ZERO));
        let mut s = Object::new(STATION, Vec3::new(0.0, 0.0, 100.0));
        s.energy = 15;
        s.ai = 1;
        b.add(s);
        let r = laser_hit(&mut pilot, &mut cockpit, &mut b, 1, &mut MainGenerator::new());
        assert_eq!(r, Some(LaserHit::StationTurned));
        let s = b.get(1).unwrap();
        assert_eq!((s.energy, s.ai, s.flags.killed), (0, 0x81, false));
        assert_eq!(pilot.kills, 0);
        assert_eq!(laser_hit(&mut pilot, &mut cockpit, &mut b, 1, &mut MainGenerator::new()), Some(LaserHit::StationTurned));
    }

    #[test]
    fn a_kill_of_types_1_to_7_rolls_for_canisters_and_counts() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        let mut p = Object::new(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 100.0));
        p.energy = 10;
        p.ai = 0xC0;
        let slot = b.add(p).unwrap();
        // A = 0x85: top bit set, 0x85 AND 7 = 5 canisters.
        let mut random = next_draw(0x85, 0);
        let r = laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(r, Some(LaserHit::Destroyed { canisters: 5, kill: true }));
        assert_eq!(b.count_of(CANISTER), 5);
        assert_eq!(pilot.kills, 1);
        let s = b.get(slot).unwrap();
        assert!(s.flags.killed);
        assert_eq!((s.energy, s.acceleration), (0, 2), "angered as well");
        let mut expected = next_draw(0x85, 0);
        expected.discard(6);
        assert_eq!(random, expected, "the roll, then one pair per canister");
    }

    #[test]
    fn a_low_roll_drops_nothing() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        let mut p = Object::new(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 100.0));
        p.energy = 15;
        let slot = b.add(p).unwrap();
        let r = laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut next_draw(0x7F, 0));
        assert_eq!(r, Some(LaserHit::Destroyed { canisters: 0, kill: true }));
        assert_eq!(b.len(), 1);
    }

    #[test]
    fn canister_launches_stop_silently_when_the_bubble_fills() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        for _ in 0..10 {
            b.add(Object::new(SUN, Vec3::ZERO));
        }
        let mut p = Object::new(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 100.0));
        p.energy = 1;
        let slot = b.add(p).unwrap();
        let mut random = next_draw(0x87, 0);
        laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(b.count_of(CANISTER), 2);
        let mut expected = next_draw(0x87, 0);
        expected.discard(8);
        assert_eq!(random, expected, "seven canister pairs drawn although two fitted");
    }

    #[test]
    fn light_objects_shot_down_give_no_kill_and_no_draw() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        let slot = b.add(Object::new(MISSILE, Vec3::new(0.0, -28.0, 14.0))).unwrap();
        let rock = b.add(Object::new(ASTEROID, Vec3::new(0.0, 0.0, 400.0))).unwrap();
        b.get_mut(rock).unwrap().energy = 15;
        let mut random = MainGenerator::new();
        let r = laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(r, Some(LaserHit::Destroyed { canisters: 0, kill: false }));
        laser_hit(&mut pilot, &mut cockpit, &mut b, rock, &mut random);
        assert!(b.get(slot).unwrap().flags.killed && b.get(rock).unwrap().flags.killed);
        assert_eq!(pilot.kills, 0);
        assert_eq!(random, MainGenerator::new());
    }

    #[test]
    fn a_killed_ship_hit_again_to_zero_counts_again() {
        let (mut pilot, mut cockpit) = fired();
        let mut b = Bubble::new();
        let mut p = Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 100.0));
        p.flags.killed = true;
        p.energy = 4;
        let slot = b.add(p).unwrap();
        let mut random = find(|r| r.draw().a < 0x80);
        let r = laser_hit(&mut pilot, &mut cockpit, &mut b, slot, &mut random);
        assert_eq!(r, Some(LaserHit::Destroyed { canisters: 0, kill: true }));
        assert_eq!(pilot.kills, 1);
    }
}
