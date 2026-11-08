//! The hyperspace and galaxy-drive keys (RULES A.5.2, A.5.3, B.16.1), the jump when the
//! countdown ends (A.5.5, A.5.7, B.16.3) and the arrival after the tunnel (A.5.6, B.16.4,
//! B.16.5, C.16.6).

use super::countdown::{Countdown, Destination};
use super::navigation::{galaxy, Navigation};
use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::market;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::ALIEN_MOTHERSHIP;
use crate::capabilities::universe::{fuel_after_jump, is_misjump, misjump_position, reach_jump, Selection};
use crate::features::planet_and_sun::place_on_arrival;
use crate::features::spawning::{alien_group, SpawnDelay};

/// Ticks the hyperspace tunnel lasts; nothing runs during it (RULES A.5.5, D.3.4).
pub const TUNNEL_TICKS: u8 = 16;
/// The ambush fills the bubble until this many alien motherships are present (RULES B.16.5).
pub const AMBUSH_MOTHERSHIPS: u8 = 4;
/// The stardust draws an ambush arrival takes and discards: 3 particles × 3 (RULES B.16.5,
/// deliberate difference 3).
pub const AMBUSH_DUST_DRAWS: usize = 9;

/// What the hyperspace key did (RULES A.5.2). The presentation shows the notices: N3 when
/// docked, N2 out of range, N1 with the destination's name when started; after a selection a
/// chart on screen is redrawn.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HyperspaceKey {
    /// Docked: the "docked" notice and nothing else.
    NotWhileDocked,
    /// A countdown is already running: ignored, nothing selected.
    CountingDown,
    /// The selected system is where the pilot is: ignored silently.
    AlreadyHere(Selection),
    /// Farther than the fuel: the out-of-range notice, no countdown.
    OutOfRange(Selection),
    /// The countdown started towards this system: the destination line.
    Started(Selection),
}

/// The hyperspace key (RULES A.5.2), its checks in order: docked, countdown running, then select
/// from the cursor, distance 0, distance beyond the fuel; otherwise the countdown starts.
pub fn press_hyperspace(
    navigation: &mut Navigation,
    countdown: &mut Countdown,
    pilot: &Pilot,
    docked: bool,
) -> HyperspaceKey {
    if docked {
        return HyperspaceKey::NotWhileDocked;
    }
    if countdown.running() {
        return HyperspaceKey::CountingDown;
    }
    let selection = navigation.select(pilot, countdown);
    if selection.distance == 0 {
        HyperspaceKey::AlreadyHere(selection)
    } else if selection.distance > u16::from(pilot.fuel) {
        HyperspaceKey::OutOfRange(selection)
    } else {
        countdown.start(Destination::System(selection));
        HyperspaceKey::Started(selection)
    }
}

/// What the galaxy-drive key did (RULES A.5.3).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GalaxyDriveKey {
    /// Docked: the "docked" notice and nothing else.
    NotWhileDocked,
    /// A countdown is already running: ignored.
    CountingDown,
    /// No galaxy drive fitted: ignored silently.
    NotFitted,
    /// The drive is used up, legal status is clean and the galactic countdown runs.
    Started,
}

/// The galaxy-drive key (RULES A.5.3): at once, the drive is removed and legal status becomes
/// clean (RULES A.14 item 5), and the countdown starts in galactic mode. No notice.
pub fn press_galaxy_drive(countdown: &mut Countdown, pilot: &mut Pilot, docked: bool) -> GalaxyDriveKey {
    if docked {
        return GalaxyDriveKey::NotWhileDocked;
    }
    if countdown.running() {
        return GalaxyDriveKey::CountingDown;
    }
    if !pilot.fitted.galaxy_drive {
        return GalaxyDriveKey::NotFitted;
    }
    pilot.fitted.galaxy_drive = false;
    pilot.legal = 0;
    countdown.start(Destination::NextGalaxy);
    GalaxyDriveKey::Started
}

/// The tunnel a jump plays, and what the arrival after it does.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tunnel {
    /// A normal jump reaching this system.
    Arrival(Selection),
    /// A normal jump that mis-jumped into the Deep.
    Misjump,
    /// A galactic jump; the pilot is already placed in the new galaxy.
    Galactic,
}

/// The jump, on the tick the countdown reaches 0 (RULES A.5.5 steps 1 and 2, A.5.7 steps 1 to
/// 5, B.16.3). A normal jump takes the destination's distance from the fuel (never below 0,
/// deliberate difference 6) and draws one byte: 253 or more mis-jumps. A galactic jump moves the
/// pilot to the system nearest (96, 96) in the next galaxy, makes it current and selected with
/// distance 0, and sets the galactic-jump message (which the arrival's reset clears; the
/// presentation shows it during the tunnel, deliberate difference 10). The lead then runs the
/// 16-tick tunnel and calls [`arrive`] with the result.
pub fn jump(
    destination: Destination,
    pilot: &mut Pilot,
    navigation: &mut Navigation,
    cockpit: &mut Cockpit,
    random: &mut MainGenerator,
) -> Tunnel {
    match destination {
        Destination::System(target) => {
            pilot.fuel = fuel_after_jump(pilot.fuel, target.distance);
            if is_misjump(random.byte()) {
                Tunnel::Misjump
            } else {
                Tunnel::Arrival(target)
            }
        }
        Destination::NextGalaxy => {
            let (next, landing) = reach_jump(galaxy(pilot));
            pilot.galaxy = next.number;
            pilot.galaxy_state = next.state();
            pilot.position = landing.position;
            navigation.cursor.position = landing.position;
            navigation.selected = landing;
            navigation.current = landing.system;
            cockpit.show(Message::GalacticJump);
            Tunnel::Galactic
        }
    }
}

/// Where an arrival left the pilot. Either way the mode becomes Flight, front mount.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Arrived {
    /// In a system, with its planet and sun.
    InSystem,
    /// In the Deep, among the aliens.
    InTheDeep,
}

/// The arrival after the tunnel (RULES A.5.5 step 4, A.5.6, B.16.4, B.16.5).
///
/// A normal arrival makes the destination current, moves the pilot there, sets the spawn delay
/// to 0 and the selected distance to 0; then, as a galactic arrival does, the common arrival:
/// the market byte (one draw) and availability, the flight-state reset (54 draws) with the
/// bubble emptied, legal status halved, the planet and sun placed with the bit shifted out, and
/// the front mount active.
///
/// A mis-jump arrival resets the flight state (54 draws), enters the Deep with the pilot's y
/// flipped in its low 5 bits, keeps the current system, market, selection and spawn delay, fills
/// the bubble with alien groups until 4 motherships are present (2 draws each) and takes the 9
/// stardust draws it discards.
pub fn arrive(
    tunnel: Tunnel,
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    navigation: &mut Navigation,
    delay: &mut SpawnDelay,
    random: &mut MainGenerator,
) -> Arrived {
    match tunnel {
        Tunnel::Arrival(target) => {
            pilot.position = target.position;
            navigation.current = target.system;
            navigation.selected = Selection { distance: 0, ..target };
            delay.reset();
            common_arrival(pilot, cockpit, bubble, navigation, random);
            Arrived::InSystem
        }
        Tunnel::Galactic => {
            common_arrival(pilot, cockpit, bubble, navigation, random);
            Arrived::InSystem
        }
        Tunnel::Misjump => {
            cockpit.reset(random);
            bubble.clear();
            cockpit.misjump = true;
            cockpit.active_mount = 0;
            pilot.position = misjump_position(pilot.position);
            while bubble.count_of(ALIEN_MOTHERSHIP) < AMBUSH_MOTHERSHIPS {
                if !alien_group(bubble, random) {
                    break;
                }
            }
            random.discard(AMBUSH_DUST_DRAWS);
            Arrived::InTheDeep
        }
    }
}

/// The common arrival (RULES A.5.6), in the current system.
fn common_arrival(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    navigation: &Navigation,
    random: &mut MainGenerator,
) {
    let system = navigation.current_system(pilot);
    market::draw_and_arrive(pilot, system.economy, random);
    cockpit.reset(random);
    bubble.clear();
    let legal_low_bit = pilot.legal & 1 == 1;
    pilot.legal >>= 1;
    place_on_arrival(bubble, &system, legal_low_bit);
    cockpit.active_mount = 0;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::ships::{ALIEN_DRONE, POLICE, SUN};
    use crate::capabilities::space::{Vec3, FAR};
    use crate::capabilities::universe::{distance, Galaxy};
    use crate::features::spawning::test_support::replay;

    /// The home system's nearest neighbour, 2.0 LY away (GDD § 4.2).
    fn neighbour() -> Selection {
        let g = Galaxy::FIRST;
        let home = g.system(0).position();
        g.systems()
            .filter(|s| s.index != 0)
            .map(|s| Selection { system: s.index, position: s.position(), distance: distance(home, s.position()) })
            .min_by_key(|s| s.distance)
            .unwrap()
    }

    #[test]
    fn the_hyperspace_key_checks_in_order() {
        let mut pilot = Pilot::start();
        let mut nav = Navigation::start(&pilot);
        let mut countdown = Countdown::new();
        assert_eq!(press_hyperspace(&mut nav, &mut countdown, &pilot, true), HyperspaceKey::NotWhileDocked);
        // The cursor on home: distance 0, ignored.
        let here = press_hyperspace(&mut nav, &mut countdown, &pilot, false);
        assert!(matches!(here, HyperspaceKey::AlreadyHere(s) if s.system == 0));
        assert!(!countdown.running());
        // System 1, 52.4 LY away: out of range.
        nav.cursor.position = (168, 241);
        let out = press_hyperspace(&mut nav, &mut countdown, &pilot, false);
        assert!(matches!(out, HyperspaceKey::OutOfRange(s) if s.system == 1 && s.distance == 524));
        // The neighbour, 2.0 LY: started.
        let n = neighbour();
        assert_eq!(n.distance, 20);
        nav.cursor.position = n.position;
        assert_eq!(press_hyperspace(&mut nav, &mut countdown, &pilot, false), HyperspaceKey::Started(n));
        assert_eq!((countdown.shown(), countdown.destination()), (15, Some(Destination::System(n))));
        // Running: ignored before anything is selected.
        nav.cursor.position = (168, 241);
        assert_eq!(press_hyperspace(&mut nav, &mut countdown, &pilot, false), HyperspaceKey::CountingDown);
        assert_eq!(nav.selected, n);
        // Exactly the fuel is in range.
        pilot.fuel = 20;
        let mut countdown = Countdown::new();
        nav.cursor.position = n.position;
        assert_eq!(press_hyperspace(&mut nav, &mut countdown, &pilot, false), HyperspaceKey::Started(n));
        pilot.fuel = 19;
        let mut countdown = Countdown::new();
        assert_eq!(press_hyperspace(&mut nav, &mut countdown, &pilot, false), HyperspaceKey::OutOfRange(n));
    }

    #[test]
    fn the_galaxy_drive_key_uses_the_drive_and_clears_the_record_at_once() {
        let mut pilot = Pilot::start();
        pilot.legal = 77;
        let mut countdown = Countdown::new();
        assert_eq!(press_galaxy_drive(&mut countdown, &mut pilot, false), GalaxyDriveKey::NotFitted);
        pilot.fitted.galaxy_drive = true;
        assert_eq!(press_galaxy_drive(&mut countdown, &mut pilot, true), GalaxyDriveKey::NotWhileDocked);
        assert_eq!(press_galaxy_drive(&mut countdown, &mut pilot, false), GalaxyDriveKey::Started);
        assert!(!pilot.fitted.galaxy_drive);
        assert_eq!(pilot.legal, 0);
        assert_eq!(countdown.destination(), Some(Destination::NextGalaxy));
        pilot.fitted.galaxy_drive = true;
        assert_eq!(press_galaxy_drive(&mut countdown, &mut pilot, false), GalaxyDriveKey::CountingDown);
        assert!(pilot.fitted.galaxy_drive, "a second drive is kept");
    }

    #[test]
    fn a_normal_jump_charges_the_fuel_and_draws_the_mis_jump_byte() {
        let mut pilot = Pilot::start();
        let mut nav = Navigation::start(&pilot);
        let mut cockpit = Cockpit::new();
        // From the starting state the byte is 0xAC = 172: no mis-jump.
        let mut random = MainGenerator::new();
        let n = neighbour();
        let t = jump(Destination::System(n), &mut pilot, &mut nav, &mut cockpit, &mut random);
        assert_eq!(t, Tunnel::Arrival(n));
        assert_eq!(pilot.fuel, 50);
        assert_eq!(random, replay(MainGenerator::new(), "n"));
        // Seed 00 FE 00 00 draws 0xFE = 254: a mis-jump.
        let mut random = MainGenerator::with_seed([0, 0xFE, 0, 0]);
        let t = jump(Destination::System(n), &mut pilot, &mut nav, &mut cockpit, &mut random);
        assert_eq!((t, pilot.fuel), (Tunnel::Misjump, 30));
        // 253 is the first mis-jump byte, 252 the last safe one.
        let mut random = MainGenerator::with_seed([0, 0xFD, 0, 0]);
        assert_eq!(jump(Destination::System(n), &mut pilot, &mut nav, &mut cockpit, &mut random), Tunnel::Misjump);
        let mut random = MainGenerator::with_seed([0, 0xFC, 0, 0]);
        assert_eq!(jump(Destination::System(n), &mut pilot, &mut nav, &mut cockpit, &mut random), Tunnel::Arrival(n));
        assert_eq!(pilot.fuel, 0, "never below 0");
    }

    #[test]
    fn a_normal_arrival() {
        let mut pilot = Pilot::start();
        pilot.legal = 5;
        let mut nav = Navigation::start(&pilot);
        let mut cockpit = Cockpit::new();
        cockpit.active_mount = 3;
        cockpit.speed = 30;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        let mut delay = SpawnDelay(2);
        let mut random = MainGenerator::new();
        let n = neighbour();
        let arrived = arrive(Tunnel::Arrival(n), &mut pilot, &mut cockpit, &mut bubble, &mut nav, &mut delay, &mut random);
        assert_eq!(arrived, Arrived::InSystem);
        assert_eq!(pilot.position, n.position);
        assert_eq!(nav.current, n.system);
        assert_eq!(nav.selected, Selection { distance: 0, ..n });
        assert_eq!(delay, SpawnDelay(0));
        // The market byte is the first draw (0xAC), then the reset's 54.
        let system = Galaxy::FIRST.system(n.system);
        assert_eq!(pilot.market_byte, 0xAC);
        assert_eq!(pilot.availability, market::availabilities(system.economy, 0xAC));
        assert_eq!(random, replay(MainGenerator::new(), &"n".repeat(55)));
        // Legal 5 halves to 2; its low bit 1 places the planet.
        assert_eq!(pilot.legal, 2);
        let mut expected = Bubble::new();
        place_on_arrival(&mut expected, &system, true);
        assert_eq!(bubble, expected);
        assert_eq!((cockpit.speed, cockpit.counter, cockpit.active_mount), (3, 0, 0));
        assert!(!cockpit.station_present && !cockpit.misjump);
    }

    #[test]
    fn a_galactic_jump_and_arrival() {
        let mut pilot = Pilot::start();
        pilot.fuel = 33;
        let mut nav = Navigation::start(&pilot);
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        let mut delay = SpawnDelay(2);
        let mut random = MainGenerator::new();
        let t = jump(Destination::NextGalaxy, &mut pilot, &mut nav, &mut cockpit, &mut random);
        assert_eq!(t, Tunnel::Galactic);
        assert_eq!(random, MainGenerator::new(), "no mis-jump byte");
        // Reach 2, system 78 at (81, 97), nearest (96, 96).
        assert_eq!((pilot.galaxy, pilot.galaxy_state), (1, Galaxy::reach(1).state()));
        assert_eq!(pilot.position, (81, 97));
        assert_eq!(nav.cursor.position, (81, 97));
        assert_eq!(nav.selected, Selection { system: 78, position: (81, 97), distance: 0 });
        assert_eq!(nav.current, 78);
        assert_eq!(pilot.fuel, 33, "no fuel used");
        assert_eq!(cockpit.message, Some(Message::GalacticJump));
        arrive(t, &mut pilot, &mut cockpit, &mut bubble, &mut nav, &mut delay, &mut random);
        assert_eq!(cockpit.message, None, "cleared by the arrival's reset (Q-B10)");
        assert_eq!(delay, SpawnDelay(2), "a galactic arrival keeps the delay (Q-B12)");
        assert_eq!(pilot.market_byte, 0xAC);
        assert_eq!(bubble.len(), 2);
        assert_eq!(bubble.get(1).unwrap().kind, SUN);
    }

    #[test]
    fn a_mis_jump_arrival_is_the_ambush() {
        let mut pilot = Pilot::start();
        pilot.market_byte = 9;
        let before = pilot.clone();
        let mut nav = Navigation::start(&pilot);
        nav.selected = neighbour();
        let nav_before = nav;
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        let mut delay = SpawnDelay(2);
        let mut random = MainGenerator::new();
        let arrived = arrive(Tunnel::Misjump, &mut pilot, &mut cockpit, &mut bubble, &mut nav, &mut delay, &mut random);
        assert_eq!(arrived, Arrived::InTheDeep);
        assert!(cockpit.misjump && !cockpit.station_present);
        assert_eq!(pilot.position, (60, 93 ^ 31), "y flipped in its low 5 bits");
        assert_eq!(nav, nav_before, "current system and stale selection kept");
        assert_eq!((pilot.market_byte, pilot.availability), (before.market_byte, before.availability));
        assert_eq!(delay, SpawnDelay(2));
        assert_eq!((bubble.count_of(ALIEN_MOTHERSHIP), bubble.count_of(ALIEN_DRONE), bubble.len()), (4, 4, 8));
        let kinds: Vec<_> = bubble.iter().map(|o| o.kind).collect();
        assert_eq!(kinds, [6, 12, 6, 12, 6, 12, 6, 12]);
        assert!(bubble.iter().all(|o| o.ai == 0xFF && o.position.z == 8192.0));
        let expected = replay(MainGenerator::new(), &format!("{} nc nc nc nc {}", "n".repeat(54), "n".repeat(9)));
        assert_eq!(random, expected, "54, then 4 × 2, then 9");
        assert!(bubble.iter().all(|o| o.position.x.abs() == 8192.0 && o.position.y.abs() == 8192.0));
        assert!(bubble.iter().all(|o| o.position.z < FAR), "no planet, sun or station");
    }
}
