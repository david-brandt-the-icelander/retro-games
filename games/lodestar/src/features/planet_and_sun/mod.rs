//! The planet and the sun: where they are placed on arrival (RULES B.10.1), the altitude check
//! and crashing (B.14), and the sun's cabin heat and fuel scooping (B.15.1, B.15.2). See
//! `planet_and_sun.md`.

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::{Cockpit, Message, ALTITUDE_FAR, CABIN_COOL, LOW_ENERGY};
use crate::capabilities::equipment;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::ships::{self, TypeNumber, SUN};
use crate::capabilities::space::{coarse, far, fine, SignMagnitude, Vec3};
use crate::capabilities::universe::System;

/// The main counter's phase (C mod 32) of the altitude check (RULES B.3.3 step 6, B.14).
pub const ALTITUDE_PHASE: u8 = 10;
/// The main counter's phase of the sun check (RULES B.3.3 step 6, B.15.1).
pub const SUN_PHASE: u8 = 20;
/// The coarse squared distance below which the player is inside the planet (RULES B.14).
pub const PLANET_SURFACE: i32 = 37;
/// Cabin temperature from which the fuel scoop takes fuel from the sun (RULES B.15.2).
pub const SCOOP_HEAT: u8 = 224;
/// Cabin temperature with the sun within a far unit but far away (RULES B.23 Q-B7).
pub const CABIN_FAR_SUN: u8 = 31;

/// A planet of `kind` at `position`: default orientation and both counters at magnitude 127,
/// positive, so it spins for ever (RULES B.9.2).
pub fn new_planet(kind: TypeNumber, position: Vec3) -> Object {
    let mut planet = Object::new(kind, position);
    planet.pitch = SignMagnitude::new(false, SignMagnitude::FOREVER);
    planet.roll = SignMagnitude::new(false, SignMagnitude::FOREVER);
    planet
}

/// Places the planet (slot 0) and the sun (slot 1) on arrival in `system` (RULES B.10.1, A.3.7),
/// into an emptied bubble. `legal_low_bit` is bit 0 of legal status before the arrival halves
/// it. The sun keeps the default orientation and counters 0.
pub fn place_on_arrival(bubble: &mut Bubble, system: &System, legal_low_bit: bool) {
    let style = system.planet_style().object_type();
    bubble.add(new_planet(style, system.planet_position(legal_low_bit)));
    bubble.add(Object::new(SUN, system.sun_position()));
}

/// What the planet and sun checks found.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BodyCheck {
    /// Nothing fatal; the tick goes on.
    Clear,
    /// The player hit the planet: dies, and the tick ends here (RULES B.14, B.23 Q-B11).
    Crashed,
    /// The sun burned the player up: dies, and the tick ends here (RULES B.15.1).
    Burned,
}

/// RULES B.3.3 step 6: outside mis-jump space, at C mod 32 = 10 the altitude check, at
/// C mod 32 = 20 the sun check; nothing on other ticks. A crash or burn ends the tick.
pub fn planet_and_sun_checks(pilot: &mut Pilot, cockpit: &mut Cockpit, bubble: &Bubble) -> BodyCheck {
    if cockpit.misjump {
        return BodyCheck::Clear;
    }
    match cockpit.counter % 32 {
        ALTITUDE_PHASE => altitude_check(cockpit, bubble),
        SUN_PHASE => sun_check(pilot, cockpit, bubble),
        _ => BodyCheck::Clear,
    }
}

/// The altitude check (RULES B.14): the low-energy warning when energy is below 50 (message M2),
/// then the altitude from the coarse distance to the planet in slot 0. Inside the planet, or at
/// altitude 0 (which needs the planet's x fine value to be 0, RULES B.23 Q-B6), the player
/// crashes.
pub fn altitude_check(cockpit: &mut Cockpit, bubble: &Bubble) -> BodyCheck {
    if cockpit.energy < LOW_ENERGY {
        cockpit.show(Message::EnergyLow);
    }
    cockpit.altitude = ALTITUDE_FAR;
    let Some(planet) = bubble.get(0).filter(|o| ships::is_planet(o.kind)) else {
        return BodyCheck::Clear;
    };
    let p = planet.position;
    if p.components().into_iter().any(far) {
        return BodyCheck::Clear;
    }
    let s = coarse_square(p) / 256;
    if s > 255 {
        return BodyCheck::Clear;
    }
    let above = s as i32 - PLANET_SURFACE;
    if above < 0 {
        return BodyCheck::Crashed;
    }
    let altitude = f64::from(256 * above + i32::from(fine(p.x))).sqrt().floor() as u32;
    if altitude == 0 {
        return BodyCheck::Crashed;
    }
    cockpit.altitude = altitude.min(255) as u8;
    BodyCheck::Clear
}

/// The sun check (RULES B.15.1, B.15.2): cabin temperature from the coarse distance to the sun,
/// burning up when it would pass 255; then, at 224 or more with the fuel scoop fitted, fuel
/// `+ ⌊speed / 8⌋` up to a full tank and the fuel-scooping message M1, shown even when nothing
/// was gained (RULES A.14 item 15). In the safe zone the temperature reads 30.
pub fn sun_check(pilot: &mut Pilot, cockpit: &mut Cockpit, bubble: &Bubble) -> BodyCheck {
    cockpit.cabin_temperature = CABIN_COOL;
    if cockpit.station_present {
        return BodyCheck::Clear;
    }
    let Some(sun) = bubble.iter().find(|o| o.kind == SUN) else {
        return BodyCheck::Clear;
    };
    if sun.position.components().into_iter().any(far) {
        return BodyCheck::Clear;
    }
    let s = coarse_square(sun.position) / 256;
    if s > 255 {
        cockpit.cabin_temperature = CABIN_FAR_SUN;
        return BodyCheck::Clear;
    }
    let heat = 255 - s + u32::from(CABIN_COOL);
    if heat > 255 {
        return BodyCheck::Burned;
    }
    cockpit.cabin_temperature = heat as u8;
    if cockpit.cabin_temperature >= SCOOP_HEAT && equipment::scoop_sun_fuel(pilot, cockpit.speed) {
        cockpit.show(Message::FuelScooping);
    }
    BodyCheck::Clear
}

/// c(x)² + c(y)² + c(z)² for a position (RULES B.14, B.15.1).
fn coarse_square(p: Vec3) -> u32 {
    p.components().into_iter().map(|v| u32::from(coarse(v)).pow(2)).sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{PLANET_A, PLANET_B, STATION};
    use crate::capabilities::space::FAR;
    use crate::capabilities::universe::Galaxy;

    fn bodies(planet: Vec3, sun: Vec3) -> Bubble {
        let mut b = Bubble::new();
        b.add(new_planet(PLANET_A, planet));
        b.add(Object::new(SUN, sun));
        b
    }

    fn at_phase(phase: u8) -> Cockpit {
        let mut c = Cockpit::new();
        c.counter = phase;
        c
    }

    #[test]
    fn arrival_places_the_planet_ahead_and_the_sun_behind() {
        // Home, system 0 of Reach 1: b1 = 0x5D, so P = 5; b3 = 0x3C, so S = 4 and b5 = 0x0E, so
        // X = 2. With g = 0: q = 5 + 6 + 0 = 11, odd, n = 5, m = 2: the planet at
        // (−2L, −2L, 5L). The sun at z = −(4 | 1)L = −5L, x = 2L + 2 × 256.
        let home = Galaxy::FIRST.system(0);
        let mut bubble = Bubble::new();
        place_on_arrival(&mut bubble, &home, false);
        let planet = bubble.get(0).unwrap();
        assert_eq!(planet.position, Vec3::new(-2.0 * FAR, -2.0 * FAR, 5.0 * FAR));
        assert_eq!(planet.kind, home.planet_style().object_type());
        assert_eq!((planet.pitch.0, planet.roll.0), (127, 127), "spins for ever, positive");
        let sun = bubble.get(1).unwrap();
        assert_eq!(sun.kind, SUN);
        assert_eq!(sun.position, Vec3::new(2.0 * FAR + 512.0, 0.0, -5.0 * FAR));
        assert_eq!((sun.pitch.0, sun.roll.0), (0, 0));
        assert_eq!(sun.nose, Vec3::new(0.0, 0.0, -1.0));
        // With g = 1: q = 12, even, n = 6, m = 3: (3L, 3L, 6L).
        let mut bubble = Bubble::new();
        place_on_arrival(&mut bubble, &home, true);
        assert_eq!(bubble.get(0).unwrap().position, Vec3::new(3.0 * FAR, 3.0 * FAR, 6.0 * FAR));
        assert!(home.tech_level & 2 == 0 || bubble.get(0).unwrap().kind == PLANET_B);
    }

    #[test]
    fn the_checks_run_only_at_their_phases_and_not_in_the_deep() {
        let mut pilot = Pilot::start();
        let bubble = bodies(Vec3::new(0.0, 0.0, 1000.0), Vec3::new(0.0, 0.0, 1000.0));
        let mut c = at_phase(11);
        assert_eq!(planet_and_sun_checks(&mut pilot, &mut c, &bubble), BodyCheck::Clear);
        let mut c = at_phase(42);
        assert_eq!(planet_and_sun_checks(&mut pilot, &mut c, &bubble), BodyCheck::Crashed, "42 mod 32 = 10");
        let mut c = at_phase(20);
        assert_eq!(planet_and_sun_checks(&mut pilot, &mut c, &bubble), BodyCheck::Burned);
        let mut c = at_phase(10);
        c.misjump = true;
        assert_eq!(planet_and_sun_checks(&mut pilot, &mut c, &bubble), BodyCheck::Clear);
    }

    #[test]
    fn altitude_from_coarse_values_and_the_planets_x_fine_value() {
        // Planet at (300, 0, 25 × 256 + 10): c = (1, 0, 25), s = ⌊(1 + 625) / 256⌋ = 2... too
        // close: 2 − 37 < 0 is a crash.
        let mut c = at_phase(10);
        let bubble = bodies(Vec3::new(300.0, 0.0, 6410.0), Vec3::ZERO);
        assert_eq!(altitude_check(&mut c, &bubble), BodyCheck::Crashed);
        // Planet at z = 100 K exactly: s = ⌊10000 / 256⌋ = 39, a = 2, alt = ⌊√(512 + 0)⌋ = 22.
        let bubble = bodies(Vec3::new(0.0, 0.0, 25_600.0), Vec3::ZERO);
        assert_eq!(altitude_check(&mut c, &bubble), BodyCheck::Clear);
        assert_eq!(c.altitude, 22);
        // The fine value of x (here 200) is added, not one of the distance (Q-B6):
        // alt = ⌊√(512 + 200)⌋ = 26.
        let bubble = bodies(Vec3::new(200.0, 0.0, 25_600.0), Vec3::ZERO);
        altitude_check(&mut c, &bubble);
        assert_eq!(c.altitude, 26);
        // s = 37 exactly (coarse z = 97, 9409 / 256 = 36.75 → 36; coarse 98: 9604 / 256 = 37):
        // a = 0, and with f(x) = 0 the altitude is 0: a crash.
        let bubble = bodies(Vec3::new(0.0, 0.0, 98.0 * 256.0), Vec3::ZERO);
        assert_eq!(altitude_check(&mut c, &bubble), BodyCheck::Crashed);
        // The same with f(x) = 1 survives at altitude 1.
        let bubble = bodies(Vec3::new(1.0, 0.0, 98.0 * 256.0), Vec3::ZERO);
        assert_eq!(altitude_check(&mut c, &bubble), BodyCheck::Clear);
        assert_eq!(c.altitude, 1);
    }

    #[test]
    fn altitude_is_255_when_far_and_capped_at_255() {
        let mut c = at_phase(10);
        c.altitude = 3;
        // A far unit away on any axis: 255.
        altitude_check(&mut c, &bodies(Vec3::new(0.0, 0.0, FAR), Vec3::ZERO));
        assert_eq!(c.altitude, 255);
        // s > 255: c(z) = 255 gives 65025 / 256 = 254, so use two axes: 2 × 200² / 256 = 312.
        c.altitude = 3;
        altitude_check(&mut c, &bodies(Vec3::new(200.0 * 256.0, 0.0, 200.0 * 256.0), Vec3::ZERO));
        assert_eq!(c.altitude, 255);
        // s = 254 (c(z) = 255): a = 217, alt = ⌊√55552⌋ = 235.
        altitude_check(&mut c, &bodies(Vec3::new(0.0, 0.0, 255.0 * 256.0), Vec3::ZERO));
        assert_eq!(c.altitude, 235);
        // No planet (mis-jump space or an empty bubble): 255 and no crash.
        c.altitude = 3;
        assert_eq!(altitude_check(&mut c, &Bubble::new()), BodyCheck::Clear);
        assert_eq!(c.altitude, 255);
    }

    #[test]
    fn the_low_energy_warning_shows_below_50() {
        let mut c = at_phase(10);
        c.energy = 50;
        altitude_check(&mut c, &Bubble::new());
        assert_eq!(c.message, None);
        c.energy = 49;
        altitude_check(&mut c, &Bubble::new());
        assert_eq!(c.message, Some(Message::EnergyLow));
        assert_eq!(c.message_timer, 22);
    }

    #[test]
    fn cabin_temperature_rises_toward_the_sun() {
        let mut pilot = Pilot::start();
        let mut c = at_phase(20);
        // Sun at coarse z = 100: s = 10000, ⌊s / 256⌋ = 39, T = 255 − 39 + 30 = 246.
        let bubble = bodies(Vec3::new(0.0, 0.0, 1e6), Vec3::new(0.0, 0.0, 25_600.0));
        assert_eq!(sun_check(&mut pilot, &mut c, &bubble), BodyCheck::Clear);
        assert_eq!(c.cabin_temperature, 246);
        // ⌊s / 256⌋ = 30 is the hottest that survives: T = 255. Coarse z = 88: 7744 / 256 = 30.
        let bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 88.0 * 256.0));
        assert_eq!(sun_check(&mut pilot, &mut c, &bubble), BodyCheck::Clear);
        assert_eq!(c.cabin_temperature, 255);
        // Coarse z = 87: 7569 / 256 = 29, T would be 256: burned up.
        let bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 87.0 * 256.0));
        assert_eq!(sun_check(&mut pilot, &mut c, &bubble), BodyCheck::Burned);
    }

    #[test]
    fn temperature_readings_far_away_and_in_the_safe_zone() {
        let mut pilot = Pilot::start();
        let mut c = at_phase(20);
        // A far unit or more away: 30 (Q-B7).
        sun_check(&mut pilot, &mut c, &bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, -FAR)));
        assert_eq!(c.cabin_temperature, 30);
        // Within a far unit on every axis but ⌊s / 256⌋ > 255: 31 (Q-B7).
        sun_check(&mut pilot, &mut c, &bodies(Vec3::ZERO, Vec3::new(200.0 * 256.0, 0.0, -200.0 * 256.0)));
        assert_eq!(c.cabin_temperature, 31);
        // In the safe zone the sun check does not run: 30, even beside the sun.
        let mut bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 87.0 * 256.0));
        bubble.add(Object::new(STATION, Vec3::ZERO));
        c.station_present = true;
        assert_eq!(sun_check(&mut pilot, &mut c, &bubble), BodyCheck::Clear);
        assert_eq!(c.cabin_temperature, 30);
    }

    #[test]
    fn fuel_scooping_at_224_and_above() {
        let mut pilot = Pilot::start();
        pilot.fuel = 10;
        pilot.fitted.fuel_scoop = true;
        let mut c = at_phase(20);
        c.speed = 40;
        // ⌊s / 256⌋ = 61 gives T = 224: scooping, fuel + 40 / 8 = 15.
        let bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 125.0 * 256.0));
        sun_check(&mut pilot, &mut c, &bubble);
        assert_eq!((c.cabin_temperature, pilot.fuel), (224, 15));
        assert_eq!(c.message, Some(Message::FuelScooping));
        // ⌊s / 256⌋ = 62 gives T = 223: no scooping.
        let mut c = at_phase(20);
        c.speed = 40;
        let bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 126.0 * 256.0));
        sun_check(&mut pilot, &mut c, &bubble);
        assert_eq!((c.cabin_temperature, pilot.fuel, c.message), (223, 15, None));
    }

    #[test]
    fn the_scooping_message_shows_even_when_nothing_is_gained() {
        let mut pilot = Pilot::start();
        pilot.fuel = 10;
        pilot.fitted.fuel_scoop = true;
        let mut c = at_phase(20);
        c.speed = 7;
        let bubble = bodies(Vec3::ZERO, Vec3::new(0.0, 0.0, 100.0 * 256.0));
        sun_check(&mut pilot, &mut c, &bubble);
        assert_eq!(pilot.fuel, 10, "⌊7 / 8⌋ = 0");
        assert_eq!(c.message, Some(Message::FuelScooping), "RULES A.14 item 15");
        // Never above a full tank.
        pilot.fuel = 68;
        c.speed = 40;
        sun_check(&mut pilot, &mut c, &bubble);
        assert_eq!(pilot.fuel, 70);
        // Without the scoop: no fuel, no message.
        pilot.fitted.fuel_scoop = false;
        pilot.fuel = 10;
        let mut c = at_phase(20);
        c.speed = 40;
        sun_check(&mut pilot, &mut c, &bubble);
        assert_eq!((pilot.fuel, c.message), (10, None));
    }
}
