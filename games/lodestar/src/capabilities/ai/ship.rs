//! The AI of every thinking object that is not a missile (RULES C.5.2 items 2 to 4, C.5.3).

use crate::capabilities::ai::{
    launch_child, pointing, steer, Hit, Thought, ECM_FITTED, ENEMY_LAUNCH, PACIFIED, STATION_POLICE,
};
use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{self, ALIEN_DRONE, ALIEN_MOTHERSHIP, ESCAPE_POD, MISSILE, POLICE, TRADER};
use crate::capabilities::space::{coarse, SignMagnitude, Vec3};

/// A hostile station launches police when its byte is at least this (RULES C.5.2).
pub const POLICE_LAUNCH_CHANCE: u8 = 140;
/// A hostile station launches only while fewer police than this are in the bubble.
pub const STATION_POLICE_LIMIT: u8 = 4;
/// A ship rolls at random when its byte is at least this (RULES C.5.3 step 4).
pub const RANDOM_ROLL_CHANCE: u8 = 250;
/// The random roll's magnitude is at least this: the drawn byte OR 104.
const RANDOM_ROLL_BITS: u8 = 104;
/// A badly hurt ship ejects when its byte is at least this (RULES C.5.3 step 5.1).
pub const ESCAPE_CHANCE: u8 = 230;
/// A ship fires only while every coarse coordinate is below this (|v| < 8192).
pub const LASER_RANGE_COARSE: u8 = 32;
/// Rounded P at or below which the ship's beam shows, and at or below which it hits.
const FIRES_AT: f64 = -32.0;
const HITS_AT: f64 = -35.0;
/// The bits of a ship's byte compared with its missiles left (RULES C.5.3 step 5.2).
const MISSILE_ROLL_MASK: u8 = 31;
/// The heading byte's top bit is set before it is compared with the AI byte.
const HEADING_TOP_BIT: u8 = 0x80;

/// The escape pod's think (RULES C.5.2 item 2): steer toward the unit vector of the planet's
/// position, or (0, 0, 1) when there is no planet, with P = 0 and no speed change.
pub(crate) fn head_for_planet(bubble: &mut Bubble, slot: usize) {
    let target = bubble
        .iter()
        .find(|o| ships::is_planet(o.kind))
        .map_or(Vec3::new(0.0, 0.0, 1.0), |planet| planet.position.normalised());
    if let Some(pod) = bubble.get_mut(slot) {
        steer(pod, target, 0.0, false);
    }
}

/// The hostile station's think (RULES C.5.2 item 3): one byte; at 140 or more, and with fewer
/// than 4 police in the bubble, it launches a police interceptor with AI byte 0xF1.
pub(crate) fn think_station(bubble: &mut Bubble, slot: usize, random: &mut MainGenerator) {
    if random.byte() < POLICE_LAUNCH_CHANCE {
        return;
    }
    if bubble.count_of(POLICE) < STATION_POLICE_LIMIT {
        if let Some(station) = bubble.get(slot).copied() {
            launch_child(bubble, &station, POLICE, STATION_POLICE, random);
        }
    }
}

/// A drone with no mothership in the bubble (RULES C.5.2 item 4): it loses its E.C.M. bit and
/// halves its speed.
pub(crate) fn drift(bubble: &mut Bubble, slot: usize) {
    if let Some(drone) = bubble.get_mut(slot) {
        drone.ai &= !ECM_FITTED;
        drone.speed /= 2;
    }
}

/// The full AI of every other ship (RULES C.5.3), in order: safe-zone pacification,
/// regeneration, the pointing value, the random roll, the low-energy escape and missile launch,
/// the laser, and choosing a heading. Returns the laser's hit on the player, if it hit.
pub fn think_ship(bubble: &mut Bubble, slot: usize, cockpit: &mut Cockpit, random: &mut MainGenerator) -> Thought {
    let Some(mut ship) = bubble.get(slot).copied() else {
        return Thought::default();
    };
    let Some(stats) = ships::stats(ship.kind) else {
        return Thought::default();
    };

    // 1. Safe-zone pacification, permanent.
    if ship.kind < TRADER && ship.kind != POLICE && cockpit.station_present {
        ship.ai &= PACIFIED;
    }
    // 2. Regeneration.
    if ship.energy < stats.energy {
        ship.energy += 1;
    }
    // 3. Pointing value.
    let aim = pointing(&ship);
    // 4. Random roll.
    if random.byte() >= RANDOM_ROLL_CHANCE {
        ship.roll = SignMagnitude(random.byte() | RANDOM_ROLL_BITS);
    }
    // 5. Low energy.
    if ship.energy <= stats.energy / 2 {
        if ship.energy <= stats.energy / 8 && random.byte() >= ESCAPE_CHANCE && ship.kind != ALIEN_MOTHERSHIP {
            ship.ai = 0;
            store(bubble, slot, ship);
            launch_child(bubble, &ship, ESCAPE_POD, ENEMY_LAUNCH, random);
            return Thought::default();
        }
        if ship.missiles != 0 {
            let roll = random.byte();
            if roll & MISSILE_ROLL_MASK < ship.missiles && !cockpit.ecm_active() {
                ship.missiles -= 1;
                store(bubble, slot, ship);
                if ship.kind == ALIEN_MOTHERSHIP {
                    launch_child(bubble, &ship, ALIEN_DRONE, ship.ai, random);
                } else if launch_child(bubble, &ship, MISSILE, ENEMY_LAUNCH, random).is_some() {
                    cockpit.show(Message::IncomingMissile);
                }
                return Thought::default();
            }
        }
    }
    // 6. Lasers.
    let p = ship.position;
    let in_range = [p.x, p.y, p.z].iter().all(|&v| coarse(v) < LASER_RANGE_COARSE);
    if in_range {
        let rounded = round_half_up(aim.value);
        if rounded <= FIRES_AT {
            ship.flags.firing = true;
        }
        if rounded <= HITS_AT {
            ship.acceleration = ship.acceleration.wrapping_sub(1);
            store(bubble, slot, ship);
            return Thought { hit: Some(Hit { damage: stats.hit_damage(), from_z: p.z }), kill: false };
        }
    }
    // 7. Choose a heading.
    let close = coarse(p.z) < 3 && (coarse(p.x) | coarse(p.y)) < 2;
    let towards = !close && (random.byte() | HEADING_TOP_BIT) < ship.ai;
    if towards {
        steer(&mut ship, -aim.direction, -aim.value, true);
    } else {
        steer(&mut ship, aim.direction, aim.value, true);
    }
    store(bubble, slot, ship);
    Thought::default()
}

/// R: P rounded to the nearest integer, halves toward +∞ (RULES C.5.3 step 6, C.17 item 3).
fn round_half_up(p: f64) -> f64 {
    (p + 0.5).floor()
}

fn store(bubble: &mut Bubble, slot: usize, ship: crate::capabilities::bubble::Object) {
    if let Some(o) = bubble.get_mut(slot) {
        *o = ship;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::{find, next_draw};
    use crate::capabilities::ai::think;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{HEAVY_FIGHTER, PLANET_A, SMALL_PIRATE_A, SMALL_PIRATE_B, STATION, SUN};

    fn space() -> Bubble {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 60_000.0, 80_000.0)));
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, -300_000.0)));
        b
    }

    fn ship(kind: u8, at: Vec3, ai: u8) -> Object {
        let mut s = Object::new(kind, at);
        s.ai = ai;
        s
    }

    #[test]
    fn an_escape_pod_heads_for_the_planet_without_changing_speed() {
        let mut b = space();
        let mut pod = ship(ESCAPE_POD, Vec3::new(0.0, 0.0, 500.0), ENEMY_LAUNCH);
        pod.speed = 4;
        let slot = b.add(pod).unwrap();
        let mut random = MainGenerator::new();
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        let pod = b.get(slot).unwrap();
        // Planet direction (0, 0.6, 0.8): roof · T = 0.6 → pitch negative; side · T = 0 → roll
        // negative (q true, r false).
        assert_eq!(pod.pitch, SignMagnitude::new(true, 3));
        assert_eq!(pod.roll, SignMagnitude::new(true, 5));
        assert_eq!((pod.speed, pod.acceleration), (4, 0));
        assert_eq!(random, MainGenerator::new(), "no draw");
    }

    #[test]
    fn with_no_planet_a_pod_heads_along_plus_z() {
        let mut b = Bubble::new();
        let slot = b.add(ship(ESCAPE_POD, Vec3::new(0.0, 0.0, 500.0), ENEMY_LAUNCH)).unwrap();
        think(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        // T = (0, 0, 1): roof · T = 0 counts as ≥ 0.
        assert_eq!(b.get(slot).unwrap().pitch, SignMagnitude::new(true, 3));
    }

    fn hostile_station() -> (Bubble, usize) {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 80_000.0)));
        let mut station = ship(STATION, Vec3::new(0.0, 0.0, 2000.0), 0x81);
        station.roll = SignMagnitude(0xFF);
        b.add(station);
        (b, 1)
    }

    #[test]
    fn a_hostile_station_launches_police_on_a_high_byte() {
        let (mut b, slot) = hostile_station();
        think(&mut b, slot, &mut Cockpit::new(), &mut next_draw(139, 0));
        assert_eq!(b.len(), 2, "139 launches nothing");
        think(&mut b, slot, &mut Cockpit::new(), &mut next_draw(140, 0));
        assert_eq!(b.len(), 3);
        let police = b.get(2).unwrap();
        assert_eq!((police.kind, police.ai, police.speed), (POLICE, 0xF1, 32));
        assert_eq!(police.position, Vec3::new(0.0, 0.0, 1808.0));
        assert_eq!(b.get(1).unwrap().energy, 220, "the station never regenerates or changes");
    }

    #[test]
    fn a_hostile_station_stops_at_four_police() {
        let (mut b, slot) = hostile_station();
        for _ in 0..4 {
            b.add(ship(POLICE, Vec3::ZERO, 0xC0));
        }
        let mut random = next_draw(255, 0);
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(b.count_of(POLICE), 4);
        let mut expected = next_draw(255, 0);
        expected.draw();
        assert_eq!(random, expected, "one byte only");
    }

    #[test]
    fn a_drone_without_a_mothership_drifts() {
        let mut b = space();
        let mut drone = ship(ALIEN_DRONE, Vec3::new(0.0, 0.0, 900.0), 0xFF);
        drone.speed = 31;
        let slot = b.add(drone).unwrap();
        let mut random = MainGenerator::new();
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        let d = b.get(slot).unwrap();
        assert_eq!((d.ai, d.speed), (0xFE, 15));
        assert_eq!(random, MainGenerator::new());
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(b.get(slot).unwrap().speed, 7, "coasting to a halt");
    }

    #[test]
    fn a_drone_with_a_mothership_fights_like_a_ship() {
        let mut b = space();
        b.add(ship(ALIEN_MOTHERSHIP, Vec3::new(0.0, 0.0, 30_000.0), 0xFF));
        let mut drone = ship(ALIEN_DRONE, Vec3::new(0.0, 0.0, 9_000.0), 0xFF);
        drone.energy = 20;
        let slot = b.add(drone).unwrap();
        let mut random = MainGenerator::new();
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(b.get(slot).unwrap().energy, 21, "it regenerated");
        assert_ne!(random, MainGenerator::new());
    }

    /// The draws of a ship with full energy, far away: the roll byte, then the heading byte.
    #[test]
    fn a_healthy_far_ship_draws_roll_then_heading() {
        let mut b = space();
        let slot = b.add(ship(SMALL_PIRATE_B, Vec3::new(0.0, 0.0, 9000.0), 0xC0)).unwrap();
        let mut random = MainGenerator::new();
        let mut expected = MainGenerator::new();
        let roll = expected.byte();
        let heading = expected.byte();
        assert!(roll < 250, "the starting stream's first byte is 0xAC");
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(random, expected);
        let s = b.get(slot).unwrap();
        // 0xE1 | 0x80 = 0xE1 ≥ 0xC0, so it turns away: T = D = (0, 0, 1), P = −36 → brake.
        assert_eq!(heading, 0xE1);
        assert_eq!(s.acceleration, 255);
        assert_eq!(s.pitch, SignMagnitude::new(true, 3));
    }

    #[test]
    fn a_high_roll_byte_draws_a_new_roll() {
        let mut b = space();
        let slot = b.add(ship(SMALL_PIRATE_B, Vec3::new(0.0, 0.0, 9000.0), 0xC0)).unwrap();
        let random = find(|r| r.byte() >= 250 && r.byte() < 0x80);
        let mut expected = random;
        expected.byte();
        let a = expected.byte();
        let mut random = random;
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        // The roll counter a OR 104 has magnitude ≥ 104, so the steer leaves it alone.
        assert_eq!(b.get(slot).unwrap().roll, SignMagnitude(a | 104));
        assert!(b.get(slot).unwrap().roll.magnitude() >= 104);
        expected.byte();
        assert_eq!(random, expected, "roll, its value, then the heading byte");
    }

    #[test]
    fn pacification_is_permanent_and_spares_police_and_traders() {
        let mut b = space();
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let pirate = b.add(ship(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 9000.0), 0xFF)).unwrap();
        let police = b.add(ship(POLICE, Vec3::new(0.0, 0.0, 9000.0), 0xFF)).unwrap();
        let trader = b.add(ship(TRADER, Vec3::new(0.0, 0.0, 9000.0), 0xFF)).unwrap();
        let mother = b.add(ship(ALIEN_MOTHERSHIP, Vec3::new(0.0, 0.0, 9000.0), 0xFF)).unwrap();
        for slot in [pirate, police, trader, mother] {
            think(&mut b, slot, &mut cockpit, &mut MainGenerator::new());
        }
        assert_eq!(b.get(pirate).unwrap().ai, 0x81);
        assert_eq!(b.get(mother).unwrap().ai, 0x81, "the mothership too");
        assert_eq!(b.get(police).unwrap().ai, 0xFF);
        assert_eq!(b.get(trader).unwrap().ai, 0xFF);
        cockpit.station_present = false;
        think(&mut b, pirate, &mut cockpit, &mut MainGenerator::new());
        assert_eq!(b.get(pirate).unwrap().ai, 0x81, "it does not come back");
    }

    #[test]
    fn regeneration_stops_at_the_types_energy() {
        let mut b = space();
        let mut s = ship(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 9000.0), 0xC0);
        s.energy = 63;
        let slot = b.add(s).unwrap();
        think(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        assert_eq!(b.get(slot).unwrap().energy, 64);
        think(&mut b, slot, &mut Cockpit::new(), &mut MainGenerator::new());
        assert_eq!(b.get(slot).unwrap().energy, 64);
    }

    #[test]
    fn a_dying_ship_ejects_a_pod_on_a_high_byte() {
        let mut b = space();
        // Heavy fighter: energy 230, an eighth is 28. At 27 it regenerates to 28, still ≤ 28.
        let mut s = ship(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 9000.0), 0xC1);
        s.energy = 27;
        s.roll = SignMagnitude(0x07);
        let slot = b.add(s).unwrap();
        let mut random = find(|r| r.byte() < 250 && r.byte() >= 230);
        let mut expected = random;
        expected.discard(2);
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(random, expected, "roll byte, escape byte, nothing more");
        assert_eq!(b.get(slot).unwrap().ai, 0, "the abandoned ship goes passive");
        assert_eq!(b.get(slot).unwrap().energy, 28);
        let pod = b.get(slot + 1).unwrap();
        assert_eq!((pod.kind, pod.ai, pod.roll), (ESCAPE_POD, 0xFE, SignMagnitude(0x06)));
    }

    #[test]
    fn the_mothership_draws_the_escape_byte_but_never_ejects() {
        let mut b = space();
        let mut s = ship(ALIEN_MOTHERSHIP, Vec3::new(0.0, 0.0, 20_000.0), 0xFF);
        s.energy = 10;
        s.missiles = 0;
        let slot = b.add(s).unwrap();
        let mut random = find(|r| r.byte() < 250 && r.byte() >= 230);
        let mut expected = random;
        expected.discard(3);
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(random, expected, "roll, escape, heading");
        assert_eq!(b.len(), 3);
        assert_eq!(b.get(slot).unwrap().ai, 0xFF);
    }

    #[test]
    fn a_hurt_ship_launches_a_missile_and_warns_the_player() {
        let mut b = space();
        // Police: energy 120, half 60; two missiles.
        let mut s = ship(POLICE, Vec3::new(0.0, 0.0, 20_000.0), 0xC0);
        s.energy = 50;
        let slot = b.add(s).unwrap();
        let mut random = find(|r| r.byte() < 250 && r.byte() & 31 < 2);
        let mut cockpit = Cockpit::new();
        think(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(b.get(slot).unwrap().missiles, 1);
        let m = b.get(slot + 1).unwrap();
        assert_eq!((m.kind, m.ai), (MISSILE, 0xFE));
        assert_eq!(cockpit.message, Some(Message::IncomingMissile));
    }

    #[test]
    fn no_launch_while_an_ecm_pulse_runs() {
        let mut b = space();
        let mut s = ship(POLICE, Vec3::new(0.0, 0.0, 20_000.0), 0xC0);
        s.energy = 50;
        let slot = b.add(s).unwrap();
        let random = find(|r| r.byte() < 250 && r.byte() & 31 < 2);
        let mut cockpit = Cockpit::new();
        cockpit.start_ecm(false);
        let mut r = random;
        think(&mut b, slot, &mut cockpit, &mut r);
        assert_eq!(b.get(slot).unwrap().missiles, 2);
        assert_eq!(b.len(), 3);
        let mut expected = random;
        expected.discard(3);
        assert_eq!(r, expected, "roll, missile, then the heading byte");
    }

    #[test]
    fn a_full_bubble_still_costs_the_enemy_a_missile() {
        let mut b = space();
        let mut s = ship(POLICE, Vec3::new(0.0, 0.0, 20_000.0), 0xC0);
        s.energy = 50;
        let slot = b.add(s).unwrap();
        while b.add(Object::new(SUN, Vec3::ZERO)).is_some() {}
        let mut random = find(|r| r.byte() < 250 && r.byte() & 31 < 2);
        let mut cockpit = Cockpit::new();
        think(&mut b, slot, &mut cockpit, &mut random);
        assert_eq!(b.get(slot).unwrap().missiles, 1);
        assert_eq!(cockpit.message, None, "no warning when nothing launched");
    }

    #[test]
    fn the_mothership_launches_a_drone_with_its_own_ai_byte() {
        let mut b = space();
        let mut s = ship(ALIEN_MOTHERSHIP, Vec3::new(0.0, 0.0, 20_000.0), 0xA3);
        s.energy = 100;
        let slot = b.add(s).unwrap();
        let mut random = find(|r| r.byte() < 250 && r.byte() & 31 < 5);
        let mut cockpit = Cockpit::new();
        think(&mut b, slot, &mut cockpit, &mut random);
        let d = b.get(slot + 1).unwrap();
        assert_eq!((d.kind, d.ai), (ALIEN_DRONE, 0xA3));
        assert_eq!(b.get(slot).unwrap().missiles, 4);
        assert_eq!(cockpit.message, None);
    }

    #[test]
    fn a_ship_pointing_at_the_player_fires_and_hits() {
        let mut b = space();
        // Heavy fighter nose (0, 0, −1) at (0, 0, 8191): P = −36, rounded −36 ≤ −35.
        let slot = b.add(ship(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 8191.0), 0xC0)).unwrap();
        let mut random = next_draw(0, 0);
        let t = think(&mut b, slot, &mut Cockpit::new(), &mut random);
        assert_eq!(t, Thought { hit: Some(Hit { damage: 18, from_z: 8191.0 }), kill: false });
        let s = b.get(slot).unwrap();
        assert!(s.flags.firing);
        assert_eq!(s.acceleration, 255);
        let mut expected = next_draw(0, 0);
        expected.draw();
        assert_eq!(random, expected, "no heading byte after a hit");
    }

    #[test]
    fn enemy_damage_uses_the_records_missiles_not_those_left() {
        let mut b = space();
        let mut s = ship(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 500.0), 0xC0);
        s.missiles = 0;
        let slot = b.add(s).unwrap();
        let t = think(&mut b, slot, &mut Cockpit::new(), &mut next_draw(0, 0));
        assert_eq!(t.hit.map(|h| h.damage), Some(18), "4 × 4 + ⌊4 / 2⌋");
    }

    #[test]
    fn beyond_8192_a_ship_never_fires() {
        let mut b = space();
        let slot = b.add(ship(HEAVY_FIGHTER, Vec3::new(0.0, 0.0, 8192.0), 0xC0)).unwrap();
        let t = think(&mut b, slot, &mut Cockpit::new(), &mut next_draw(0, 0));
        assert_eq!(t, Thought::default());
        assert!(!b.get(slot).unwrap().flags.firing);
    }

    #[test]
    fn halves_round_toward_plus_infinity() {
        assert_eq!(round_half_up(-34.5), -34.0);
        assert_eq!(round_half_up(-34.51), -35.0);
        assert_eq!(round_half_up(-31.5), -31.0);
        assert_eq!(round_half_up(-31.51), -32.0);
        assert_eq!(round_half_up(-36.0), -36.0);
    }

    #[test]
    fn the_laser_fires_and_hits_by_rounded_pointing() {
        // A ship on +z has D = (0, 0, 1), so P = 36 × nose z.
        let fire_and_hit = |p: f64| {
            let mut b = space();
            let mut s = ship(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 4000.0), 0xC0);
            let z = p / 36.0;
            s.nose = Vec3::new((1.0 - z * z).sqrt(), 0.0, z);
            let slot = b.add(s).unwrap();
            let t = think(&mut b, slot, &mut Cockpit::new(), &mut next_draw(0, 0));
            (b.get(slot).unwrap().flags.firing, t.hit.is_some())
        };
        assert_eq!(fire_and_hit(-31.5), (false, false), "−31.5 rounds to −31");
        assert_eq!(fire_and_hit(-31.6), (true, false));
        assert_eq!(fire_and_hit(-34.2), (true, false));
        assert_eq!(fire_and_hit(-34.6), (true, true));
        assert_eq!(fire_and_hit(-36.0), (true, true));
    }

    #[test]
    fn a_close_ship_always_turns_away_without_a_draw() {
        let mut b = space();
        // |z| < 768 and |x|, |y| < 512, nose pointing away from the player so it cannot fire.
        let mut s = ship(SMALL_PIRATE_A, Vec3::new(500.0, -300.0, 700.0), 0xFF);
        s.nose = Vec3::new(0.0, 0.0, 1.0);
        let slot = b.add(s).unwrap();
        let mut random = next_draw(0, 0);
        think(&mut b, slot, &mut Cockpit::new(), &mut random);
        let mut expected = next_draw(0, 0);
        expected.draw();
        assert_eq!(random, expected, "only the roll byte");
    }

    #[test]
    fn aggression_decides_turning_towards() {
        // Far ship, nose pointing away (P = +36 from D). The heading byte | 0x80 against the AI
        // byte 0xC0: below turns towards (T = −D, P = −36 → brake), at or above away (+3).
        let run = |heading: u8| {
            let mut b = space();
            let mut s = ship(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 9000.0), 0xC0);
            s.nose = Vec3::new(0.0, 0.0, 1.0);
            let slot = b.add(s).unwrap();
            let mut random = find(|r| r.byte() < 250 && r.byte() | 0x80 == heading);
            think(&mut b, slot, &mut Cockpit::new(), &mut random);
            b.get(slot).unwrap().acceleration
        };
        assert_eq!(run(0xBF), 255, "towards");
        assert_eq!(run(0xC0), 3, "away");
    }
}
