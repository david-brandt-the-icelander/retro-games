//! The periodic spawn: the event the tick runs when the main counter reaches 0 (RULES B.10.8,
//! C.16.1 to C.16.5, C.16.8).

use super::template::{alien_group, hostile_template, signed, Template, HOSTILE_AI};
use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::{ALIEN_MOTHERSHIP, ASTEROID, CANISTER, POLICE, TRADER};
use crate::capabilities::space::{SignMagnitude, Vec3};

/// The event's first byte below this may give a benign spawn (RULES C.16.2).
pub const BENIGN_BELOW: u8 = 35;
/// Fewer asteroids than this, or the benign spawn does not happen (RULES C.16.8).
pub const ROCK_CAP: u8 = 3;
/// The benign template's distance ahead: 38 K (RULES C.16.5).
pub const BENIGN_Z: f64 = 9728.0;
/// The hostile spawn's government byte stops at this or above, outside government 0
/// (RULES C.16.3 step 6).
pub const GOVERNMENT_STOP_FROM: u8 = 90;
/// The second template's byte from this up gives a pirate pack (RULES C.16.3 step 8).
pub const PACK_FROM: u8 = 200;
/// A lone ship's second byte from this up fits an E.C.M.; the alien roll from this up brings
/// the group (RULES C.16.3 step 9).
const LONE_ROLL_FROM: u8 = 200;
/// An asteroid when the benign spawn's last byte is this or more, else a canister.
const ROCK_FROM: u8 = 5;

/// The extra-encounter delay E (D in RULES C.16): a signed counter that holds back hostile
/// spawns after a pack or a lone ship. The tick keeps it beside the cockpit; ordinary arrival
/// and the in-system jump set it to 0, a galactic or mis-jump arrival does not (RULES B.23 Q-B12).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SpawnDelay(pub i16);

impl SpawnDelay {
    /// E ← 0.
    pub fn reset(&mut self) {
        self.0 = 0;
    }

    /// RULES C.16.3 step 5: E ← E − 1; true (go on) when that went below 0, which sets E to 0.
    fn count_down(&mut self) -> bool {
        self.0 -= 1;
        if self.0 >= 0 {
            false
        } else {
            self.0 = 0;
            true
        }
    }
}

/// The periodic spawn (RULES B.10.8, C.16.2): the tick calls it when the main counter has just
/// reached 0 and the player is not dying. In mis-jump space it does nothing and draws nothing.
/// Otherwise one byte decides between the benign spawn (below 35, with fewer than 3 asteroids
/// present) and the hostile spawn. `government` is the current system's.
pub fn periodic_spawn(
    pilot: &Pilot,
    cockpit: &Cockpit,
    bubble: &mut Bubble,
    delay: &mut SpawnDelay,
    government: u8,
    random: &mut MainGenerator,
) {
    if cockpit.misjump {
        return;
    }
    let a = random.byte();
    if a < BENIGN_BELOW && bubble.count_of(ASTEROID) < ROCK_CAP {
        benign_spawn(cockpit, bubble, random);
    } else {
        hostile_spawn(pilot, cockpit, bubble, delay, government, random);
    }
}

/// The benign spawn (RULES B.10.8 step 1, C.16.5): a trader, or (outside the safe zone) an
/// asteroid or a cargo canister, 38 K ahead. The x offset takes 512 more when the position draw
/// leaves the carry set (RULES C.17 item 15).
fn benign_spawn(cockpit: &Cockpit, bubble: &mut Bubble, random: &mut MainGenerator) {
    let mut template = Template::at(Vec3::new(0.0, 0.0, BENIGN_Z));
    let place = random.draw();
    let offset = if random.carry() { 512.0 } else { 0.0 };
    template.position.x = signed(f64::from(place.a & 127) + offset, place.a);
    template.position.y = signed(f64::from(place.x & 127), place.x);

    let b = random.draw();
    if b.a & 0x40 != 0 {
        template.ai = b.a / 2;
        template.roll = SignMagnitude(b.a / 2);
        template.speed = (b.a & 31) | 16;
        bubble.add(template.make(TRADER));
        return;
    }
    template.roll = SignMagnitude(b.a | 0x6F);
    if cockpit.station_present {
        return;
    }
    if b.a & 0x80 != 0 {
        template.pitch = SignMagnitude(b.x | 0x7F);
    } else {
        template.speed = (b.x & 31) | 16;
    }
    let kind = if random.byte() >= ROCK_FROM { ASTEROID } else { CANISTER };
    bubble.add(template.make(kind));
}

/// The hostile spawn (RULES B.10.8 step 2, C.16.3): police for contraband or a bad record, then,
/// when the delay allows and the government lets it through, a pirate pack, a lone hunter or the
/// alien group. Nothing in the safe zone.
fn hostile_spawn(
    pilot: &Pilot,
    cockpit: &Cockpit,
    bubble: &mut Bubble,
    delay: &mut SpawnDelay,
    government: u8,
    random: &mut MainGenerator,
) {
    if cockpit.station_present {
        return;
    }
    let mut bar = pilot.contraband().wrapping_mul(2);
    if bubble.count_of(POLICE) > 0 {
        bar |= pilot.legal;
    }
    let (police, roll) = hostile_template(random);
    if roll.a < bar {
        bubble.add(police.make(POLICE));
    }
    if bubble.count_of(POLICE) > 0 || !delay.count_down() {
        return;
    }
    if !government_lets_through(random.byte(), government) {
        return;
    }
    let (template, roll) = hostile_template(random);
    if roll.a >= PACK_FROM {
        let extra = roll.a & 3;
        delay.0 = i16::from(extra);
        for _ in 0..=extra {
            let kind = (random.byte() & 3) | 1;
            bubble.add(template.make(kind));
        }
        return;
    }
    delay.0 += 1;
    let kind = (roll.a & 3) + 3;
    if kind == ALIEN_MOTHERSHIP {
        if random.byte() >= LONE_ROLL_FROM {
            alien_group(bubble, random);
        }
        return;
    }
    let mut ship = template.make(kind);
    ship.ai = HOSTILE_AI | u8::from(roll.x >= LONE_ROLL_FROM);
    bubble.add(ship);
}

/// RULES C.16.3 step 6: government 0 always goes on; any other stops when the byte is 90 or
/// more, or when its low three bits are below the government.
fn government_lets_through(byte: u8, government: u8) -> bool {
    government == 0 || (byte < GOVERNMENT_STOP_FROM && byte & 7 >= government)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::features::spawning::test_support::replay;
    use crate::capabilities::ships::{ALIEN_DRONE, HEAVY_FIGHTER, HUNTER, PLANET_A, SMALL_PIRATE_A, SMALL_PIRATE_B, STATION, SUN};

    fn system_bubble() -> Bubble {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 3.0 * 65536.0)));
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, -65536.0)));
        b
    }

    /// Runs one event from a seeded generator with an empty record and government 0.
    fn event(seed: [u8; 4], cockpit: &Cockpit, bubble: &mut Bubble, delay: &mut SpawnDelay) -> MainGenerator {
        let mut random = MainGenerator::with_seed(seed);
        periodic_spawn(&Pilot::start(), cockpit, bubble, delay, 0, &mut random);
        random
    }

    /// The generator after `pattern` from `seed` (`n` ordinary, `c` carry-cleared draws).
    fn draws_from(seed: [u8; 4], pattern: &str) -> MainGenerator {
        replay(MainGenerator::with_seed(seed), pattern)
    }

    #[test]
    fn nothing_spawns_and_nothing_is_drawn_in_mis_jump_space() {
        let mut cockpit = Cockpit::new();
        cockpit.misjump = true;
        let mut bubble = Bubble::new();
        let random = event([1, 2, 3, 4], &cockpit, &mut bubble, &mut SpawnDelay::default());
        assert_eq!(random, MainGenerator::with_seed([1, 2, 3, 4]));
        assert!(bubble.is_empty());
    }

    #[test]
    fn the_benign_trader() {
        // Seed 7E BE 4B 4D: a = 0x0C (< 35); position draw (0xCB, 0x0C), carry clear: x = −75,
        // y = 12 (the event's own byte, RULES C.16.5 step 2); then b = 0xD7 has bit 6 set: a
        // trader with AI and roll 0xD7 / 2 = 107 and speed (0xD7 & 31) | 16 = 23.
        let mut bubble = system_bubble();
        let random = event([126, 190, 75, 77], &Cockpit::new(), &mut bubble, &mut SpawnDelay::default());
        let t = bubble.get(2).unwrap();
        assert_eq!(t.kind, TRADER);
        assert_eq!(t.position, Vec3::new(-75.0, 12.0, 9728.0));
        assert_eq!((t.ai, t.roll, t.speed), (107, SignMagnitude(107), 23));
        assert_eq!(t.pitch, SignMagnitude::ZERO);
        assert_eq!(random, draws_from([126, 190, 75, 77], "n n n"));
    }

    #[test]
    fn the_benign_trader_comes_in_the_safe_zone_too() {
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let mut bubble = system_bubble();
        event([126, 190, 75, 77], &cockpit, &mut bubble, &mut SpawnDelay::default());
        assert_eq!(bubble.get(2).unwrap().kind, TRADER);
    }

    #[test]
    fn the_benign_rock_takes_512_more_when_the_carry_is_set() {
        // Seed 9A FF 51 1F: the position draw's a has low bits 29 and leaves the carry set, so
        // x = 29 + 512 = 541; y = 30; b has bits 6 and 7 clear, so roll = b | 0x6F = 0x7F and
        // speed = (b' & 31) | 16 = 29; the last byte is 5 or more: an asteroid.
        let mut bubble = system_bubble();
        let random = event([154, 255, 81, 31], &Cockpit::new(), &mut bubble, &mut SpawnDelay::default());
        let r = bubble.get(2).unwrap();
        assert_eq!(r.kind, ASTEROID);
        assert_eq!(r.position, Vec3::new(541.0, 30.0, 9728.0));
        assert_eq!((r.roll, r.pitch, r.speed, r.ai), (SignMagnitude(0x7F), SignMagnitude::ZERO, 29, 0));
        assert_eq!(random, draws_from([154, 255, 81, 31], "n n n n"));
    }

    #[test]
    fn the_benign_rock_spins_forever_when_b_has_bit_7() {
        // Seed 49 98 40 71: x = −34, y = 9; b has bit 7: roll 0xEF, pitch b' | 0x7F = 0xFF
        // (magnitude 127, negative), speed 0.
        let mut bubble = system_bubble();
        event([73, 152, 64, 113], &Cockpit::new(), &mut bubble, &mut SpawnDelay::default());
        let r = bubble.get(2).unwrap();
        assert_eq!(r.kind, ASTEROID);
        assert_eq!(r.position, Vec3::new(-34.0, 9.0, 9728.0));
        assert_eq!((r.roll, r.pitch, r.speed), (SignMagnitude(0xEF), SignMagnitude(0xFF), 0));
    }

    #[test]
    fn the_benign_canister() {
        let mut bubble = system_bubble();
        event([132, 220, 191, 60], &Cockpit::new(), &mut bubble, &mut SpawnDelay::default());
        let c = bubble.get(2).unwrap();
        assert_eq!(c.kind, CANISTER);
        assert_eq!(c.position, Vec3::new(-116.0, 24.0, 9728.0));
        assert_eq!((c.roll, c.speed, c.ai), (SignMagnitude(0x6F), 20, 0));
    }

    #[test]
    fn the_safe_zone_stops_rocks_after_three_draws() {
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let mut bubble = system_bubble();
        let random = event([154, 255, 81, 31], &cockpit, &mut bubble, &mut SpawnDelay::default());
        assert_eq!(bubble.len(), 2);
        assert_eq!(random, draws_from([154, 255, 81, 31], "n n n"));
    }

    #[test]
    fn three_rocks_turn_a_benign_byte_hostile() {
        // With three asteroids present the same first byte goes to the hostile spawn, which the
        // safe zone stops at once: one draw only.
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let mut bubble = system_bubble();
        for _ in 0..3 {
            bubble.add(Object::new(ASTEROID, Vec3::ZERO));
        }
        let random = event([154, 255, 81, 31], &cockpit, &mut bubble, &mut SpawnDelay::default());
        assert_eq!(bubble.len(), 5);
        assert_eq!(random, draws_from([154, 255, 81, 31], "n"));
    }

    #[test]
    fn a_lone_pirate_pack_of_one() {
        // Seed 56 01 00 78: a = 0x79; the police template returns 0xF4, not below the bar of 0;
        // the delay goes to −1, so on with E = 0; government 0 takes its byte and goes on; the
        // second template, (0x64, 0x6F) then (0xD4, 0x64), is placed at (8192, 8192, 8192) and
        // returns 0xD4 = 212 ≥ 200: a pack of (212 & 3) + 1 = 1 ship, of type (0x39 & 3) | 1 = 1.
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        let random = event([86, 1, 0, 120], &Cockpit::new(), &mut bubble, &mut delay);
        assert_eq!(bubble.len(), 3);
        let p = bubble.get(2).unwrap();
        assert_eq!(p.kind, SMALL_PIRATE_A);
        assert_eq!(p.position, Vec3::new(8192.0, 8192.0, 8192.0));
        assert_eq!(p.ai, 0xC0);
        assert_eq!(delay, SpawnDelay(0));
        assert_eq!(random, draws_from([86, 1, 0, 120], "n nc n nc n"));
    }

    #[test]
    fn a_pack_of_two_shares_one_place_and_sets_the_delay() {
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        let random = event([0, 21, 86, 120], &Cockpit::new(), &mut bubble, &mut delay);
        let kinds: Vec<_> = bubble.iter().skip(2).map(|o| o.kind).collect();
        assert_eq!(kinds, [SMALL_PIRATE_A, SMALL_PIRATE_B]);
        assert!(bubble.iter().skip(2).all(|o| o.position == Vec3::new(8192.0, -8192.0, 8192.0)));
        assert_eq!(delay, SpawnDelay(1), "the next event skips its hostile ships");
        assert_eq!(random, draws_from([0, 21, 86, 120], "n nc n nc n n"));

        // The next event with E = 1 counts down to 0 and stops after the police template.
        let mut random = MainGenerator::new();
        periodic_spawn(&Pilot::start(), &Cockpit::new(), &mut bubble, &mut delay, 0, &mut random);
        assert_eq!(delay, SpawnDelay(0));
        assert_eq!(bubble.len(), 4);
        assert_eq!(random, draws_from([0x12, 0x34, 0x56, 0x78], "n nc"));
    }

    #[test]
    fn lone_hunters_take_the_second_bytes_ecm() {
        for (seed, kind, position, ai) in [
            ([86, 5, 0, 120], SMALL_PIRATE_B, Vec3::new(-8192.0, -8192.0, 8192.0), 0xC0),
            ([0, 49, 86, 120], HEAVY_FIGHTER, Vec3::new(-8192.0, 8192.0, 8192.0), 0xC1),
            ([0, 14, 86, 120], HUNTER, Vec3::new(-8192.0, -8192.0, 8192.0), 0xC1),
        ] {
            let mut bubble = system_bubble();
            let mut delay = SpawnDelay::default();
            event(seed, &Cockpit::new(), &mut bubble, &mut delay);
            let s = bubble.get(2).unwrap();
            assert_eq!((s.kind, s.position, s.ai), (kind, position, ai), "seed {seed:?}");
            assert_eq!(delay, SpawnDelay(1));
            assert_eq!(bubble.len(), 3);
        }
    }

    #[test]
    fn the_alien_roll() {
        // Seed 56 08 00 78: the type is 6; the roll is 200 or more: the alien group.
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        event([86, 8, 0, 120], &Cockpit::new(), &mut bubble, &mut delay);
        assert_eq!((bubble.count_of(ALIEN_MOTHERSHIP), bubble.count_of(ALIEN_DRONE)), (1, 1));
        assert_eq!(bubble.get(2).unwrap().position, Vec3::new(-8192.0, -8192.0, 8192.0));
        assert_eq!(delay, SpawnDelay(1));
        // Seed 56 00 00 78: the roll is 36: nothing, but the delay still rises.
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        let random = event([86, 0, 0, 120], &Cockpit::new(), &mut bubble, &mut delay);
        assert_eq!(bubble.len(), 2);
        assert_eq!(delay, SpawnDelay(1));
        assert_eq!(random, draws_from([86, 0, 0, 120], "n nc n nc n"));
    }

    #[test]
    fn contraband_brings_the_police_and_nothing_else() {
        // Seed 56 05 00 78: the police template returns a = 0. One jammer kit (item 10) gives a
        // contraband score of 1 and a bar of 2, and 0 < 2.
        let mut pilot = Pilot::start();
        pilot.cargo[10] = 1;
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        let mut random = MainGenerator::with_seed([86, 5, 0, 120]);
        periodic_spawn(&pilot, &Cockpit::new(), &mut bubble, &mut delay, 0, &mut random);
        let p = bubble.get(2).unwrap();
        assert_eq!((p.kind, p.position, p.ai), (POLICE, Vec3::new(-8192.0, 8192.0, 8192.0), 0xC0));
        assert_eq!(bubble.len(), 3);
        assert_eq!(delay, SpawnDelay(0), "the delay is not touched");
        assert_eq!(random, draws_from([86, 5, 0, 120], "n nc"));
    }

    #[test]
    fn police_present_add_the_legal_status_to_the_bar() {
        let mut pilot = Pilot::start();
        let mut bubble = system_bubble();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        // Clean record, no contraband: the bar is 0 and no more police come; the police present
        // stop the rest.
        let mut random = MainGenerator::with_seed([86, 5, 0, 120]);
        periodic_spawn(&pilot, &Cockpit::new(), &mut bubble, &mut SpawnDelay::default(), 0, &mut random);
        assert_eq!(bubble.count_of(POLICE), 1);
        assert_eq!(random, draws_from([86, 5, 0, 120], "n nc"));
        // An offender's record is OR-ed in: legal 1 makes the bar 1, and 0 < 1.
        pilot.legal = 1;
        let mut random = MainGenerator::with_seed([86, 5, 0, 120]);
        periodic_spawn(&pilot, &Cockpit::new(), &mut bubble, &mut SpawnDelay::default(), 0, &mut random);
        assert_eq!(bubble.count_of(POLICE), 2);
    }

    #[test]
    fn no_hostile_spawn_in_the_safe_zone() {
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let mut bubble = system_bubble();
        bubble.replace(1, Object::new(STATION, Vec3::ZERO));
        let random = event([86, 1, 0, 120], &cockpit, &mut bubble, &mut SpawnDelay::default());
        assert_eq!(bubble.len(), 2);
        assert_eq!(random, draws_from([86, 1, 0, 120], "n"));
    }

    #[test]
    fn the_government_table() {
        // RULES C.16.3: out of 256, the hostile spawn goes on 256, 78, 66, 55, 44, 33, 22, 11
        // times for governments 0..7.
        let counts: Vec<usize> = (0..8)
            .map(|g| (0..=255u8).filter(|&b| government_lets_through(b, g)).count())
            .collect();
        assert_eq!(counts, [256, 78, 66, 55, 44, 33, 22, 11]);
    }

    #[test]
    fn a_government_stops_the_spawn_after_its_byte() {
        // Seed 56 01 00 78 under government 1: the government byte is 0x6F = 111 ≥ 90.
        let mut bubble = system_bubble();
        let mut delay = SpawnDelay::default();
        let mut random = MainGenerator::with_seed([86, 1, 0, 120]);
        periodic_spawn(&Pilot::start(), &Cockpit::new(), &mut bubble, &mut delay, 1, &mut random);
        assert_eq!(bubble.len(), 2);
        assert_eq!(random, draws_from([86, 1, 0, 120], "n nc n"));
        assert_eq!(delay, SpawnDelay(0));
    }

    #[test]
    fn the_delay_counts_down_before_it_lets_a_spawn_through() {
        let mut d = SpawnDelay(2);
        assert!(!d.count_down());
        assert!(!d.count_down());
        assert_eq!(d, SpawnDelay(0));
        assert!(d.count_down());
        assert_eq!(d, SpawnDelay(0));
        d.0 = 3;
        d.reset();
        assert_eq!(d, SpawnDelay(0));
    }
}
