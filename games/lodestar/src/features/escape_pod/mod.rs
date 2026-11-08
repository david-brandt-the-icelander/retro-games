//! The escape pod (RULES B.17, C.10.5, D.3.9): the launch, the 97 ticks watching the abandoned
//! hull drift, and the rescue at the station, or death in the Deep. The hull never collides
//! with the player (deliberate difference 7). See `escape_pod.md`.

use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::equipment;
use crate::capabilities::flight::own_motion_tick;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::TRADER;
use crate::capabilities::space::SignMagnitude;
use crate::capabilities::universe::Selection;
use crate::features::death::{die, Cause, Dying};
use crate::features::docking::enter_docked;
use crate::features::hyperspace::{Countdown, Navigation};
use crate::features::spawning::launch_straight_ahead;

/// Ticks of the escape sequence (RULES B.17).
pub const ESCAPE_TICKS: u8 = 97;
/// The abandoned hull's speed (RULES B.17).
pub const HULL_SPEED: u8 = 8;
/// The abandoned hull's pitch counter: negative, magnitude 66, decaying to 0 (RULES B.17).
pub const HULL_PITCH: SignMagnitude = SignMagnitude(0xC2);

/// The escape sequence under way. The lead's mode machine holds it in Escape mode, where
/// presses are discarded and C, energy and the countdown are frozen.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Escape {
    ticks_left: u8,
    /// The pod was used in the Deep: the sequence ends in death.
    pub from_the_deep: bool,
    /// The abandoned hull's slot, when the bubble had room for it.
    pub hull: Option<usize>,
}

/// The escape-pod action (RULES B.17 steps 1 to 4, D.3.9). With no pod fitted it does nothing
/// and returns `None`. Otherwise: remember whether in the Deep; empty the bubble, leave the safe
/// zone and clear the missile lock (not the arming); add the abandoned hull (a medium multi-role
/// ship launched straight ahead, then speed 8, pitch 0xC2, AI 0) unless the bubble was full;
/// reset the controls. The player's speed is kept. The lead cancels any prompt, ends the
/// tick's player actions at once (no further queued actions, no laser) and lets the rest of
/// the tick run (RULES B.23 Q-B2); in that tick the hull takes no part in collision tests
/// (deliberate difference 7).
pub fn launch_pod(pilot: &Pilot, cockpit: &mut Cockpit, bubble: &mut Bubble) -> Option<Escape> {
    if !pilot.fitted.escape_pod {
        return None;
    }
    let from_the_deep = cockpit.misjump;
    let room = !bubble.is_full();
    bubble.clear();
    cockpit.station_present = false;
    cockpit.missile.target = None;
    let hull = room.then(|| {
        let mut hull = launch_straight_ahead(TRADER, 0, cockpit.speed);
        hull.speed = HULL_SPEED;
        hull.pitch = HULL_PITCH;
        hull.ai = 0;
        hull
    });
    let hull = hull.and_then(|h| bubble.add(h));
    cockpit.attitude.reset();
    Some(Escape { ticks_left: ESCAPE_TICKS, from_the_deep, hull })
}

impl Escape {
    /// One escape tick (RULES B.17 step 4): the hull's own-motion update (B.7.3), then the
    /// countdown. Returns true when the 97 ticks are over: then call [`aftermath`]. The lead
    /// still moves the bubble by two half-steps each tick with the player's kept speed.
    pub fn tick(&mut self, bubble: &mut Bubble) -> bool {
        if let Some(hull) = self.hull.and_then(|slot| bubble.get_mut(slot)) {
            own_motion_tick(hull);
        }
        self.ticks_left = self.ticks_left.saturating_sub(1);
        self.ticks_left == 0
    }

    /// Escape ticks left.
    pub fn ticks_left(&self) -> u8 {
        self.ticks_left
    }

    /// True on the launch tick only, for the hull in `slot`: the contact step skips it
    /// (deliberate difference 7).
    pub fn spares(&self, slot: usize) -> bool {
        self.ticks_left == ESCAPE_TICKS && self.hull == Some(slot)
    }
}

/// How the escape ended.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Aftermath {
    /// Rescued and docked at the current system's station; the selection the status screen made.
    Docked(Selection),
    /// The pod was used in the Deep: the death sequence runs, then the title.
    Died(Dying),
}

/// The end of the escape (RULES B.17 step 6, C.10.5, D.3.9): the flight state is reset (54
/// draws) with the bubble emptied. From the Deep the player then dies (the death's own reset
/// follows). Otherwise the rescue: the hold emptied, legal status clean, the pod used up, a full
/// tank, and the docked state at the current system's station; cash, equipment, missiles,
/// kills and the market are kept.
pub fn aftermath(
    escape: &Escape,
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    navigation: &mut Navigation,
    countdown: &mut Countdown,
    random: &mut MainGenerator,
) -> Aftermath {
    cockpit.reset(random);
    bubble.clear();
    if escape.from_the_deep {
        return Aftermath::Died(die(Cause::EscapeInTheDeep, cockpit, bubble, countdown, random));
    }
    equipment::escape_pod_rescue(pilot);
    Aftermath::Docked(enter_docked(pilot, navigation, countdown))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::{Object, CAPACITY};
    use crate::capabilities::cockpit::MissileLock;
    use crate::capabilities::ships::{CANISTER, POLICE, STATION};
    use crate::capabilities::space::Vec3;
    use crate::features::hyperspace::Destination;
    use crate::features::spawning::test_support::replay;

    fn fitted() -> Pilot {
        let mut p = Pilot::start();
        p.fitted.escape_pod = true;
        p
    }

    #[test]
    fn no_pod_no_escape() {
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        assert_eq!(launch_pod(&Pilot::start(), &mut cockpit, &mut bubble), None);
        assert_eq!(bubble.len(), 1);
    }

    #[test]
    fn the_launch_leaves_only_the_hull() {
        let mut cockpit = Cockpit::new();
        cockpit.station_present = true;
        cockpit.speed = 25;
        cockpit.missile = MissileLock { armed: true, target: Some(2) };
        cockpit.attitude.roll_rate = 200;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(128, Vec3::ZERO));
        bubble.add(Object::new(STATION, Vec3::ZERO));
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        let escape = launch_pod(&fitted(), &mut cockpit, &mut bubble).unwrap();
        assert_eq!((escape.ticks_left(), escape.from_the_deep, escape.hull), (97, false, Some(0)));
        assert_eq!(bubble.len(), 1);
        let hull = bubble.get(0).unwrap();
        assert_eq!(hull.kind, TRADER);
        assert_eq!(hull.position, Vec3::new(0.0, -28.0, 14.0));
        assert_eq!(hull.nose, Vec3::new(0.0, 0.0, 1.0));
        assert_eq!((hull.speed, hull.pitch, hull.roll, hull.ai), (8, SignMagnitude(0xC2), SignMagnitude::ZERO, 0));
        assert!(!cockpit.station_present);
        assert_eq!(cockpit.missile, MissileLock { armed: true, target: None }, "arming kept");
        assert_eq!(cockpit.attitude.roll_rate, 128);
        assert_eq!(cockpit.attitude.roll_angle, 3.0 / 256.0);
        assert_eq!(cockpit.speed, 25, "the player's speed is kept");
        assert!(escape.spares(0), "no collision with the hull on the launch tick");
    }

    #[test]
    fn a_full_bubble_leaves_no_hull() {
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        for _ in 0..CAPACITY {
            bubble.add(Object::new(CANISTER, Vec3::ZERO));
        }
        let escape = launch_pod(&fitted(), &mut cockpit, &mut bubble).unwrap();
        assert_eq!(escape.hull, None);
        assert!(bubble.is_empty());
    }

    #[test]
    fn ninety_seven_ticks_of_the_hull_drifting() {
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        let mut escape = launch_pod(&fitted(), &mut cockpit, &mut bubble).unwrap();
        assert!(!escape.tick(&mut bubble));
        assert!(!escape.spares(0), "only the launch tick");
        // The pitch counter decays by one a tick, from magnitude 66.
        assert_eq!(bubble.get(0).unwrap().pitch, SignMagnitude::new(true, 65));
        for _ in 0..95 {
            assert!(!escape.tick(&mut bubble));
        }
        assert!(escape.tick(&mut bubble));
        assert_eq!(bubble.get(0).unwrap().pitch, SignMagnitude::new(true, 0));
        assert_eq!(bubble.get(0).unwrap().speed, 8, "within the type's top speed");
    }

    #[test]
    fn the_rescue_docks_with_a_full_tank_and_an_empty_hold() {
        let mut pilot = fitted();
        pilot.cargo[3] = 4;
        pilot.legal = 60;
        pilot.fuel = 2;
        pilot.cash = 5_000;
        pilot.fitted.ecm = true;
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        let escape = launch_pod(&pilot, &mut cockpit, &mut bubble).unwrap();
        let mut nav = Navigation::start(&pilot);
        let mut countdown = Countdown::new();
        countdown.start(Destination::NextGalaxy);
        let mut random = MainGenerator::new();
        let end = aftermath(&escape, &mut pilot, &mut cockpit, &mut bubble, &mut nav, &mut countdown, &mut random);
        assert!(matches!(end, Aftermath::Docked(s) if s.system == 0));
        assert_eq!((pilot.cargo[3], pilot.legal, pilot.fuel, pilot.cash), (0, 0, 70, 5_000));
        assert!(!pilot.fitted.escape_pod && pilot.fitted.ecm);
        assert!(bubble.is_empty() && !countdown.running());
        assert_eq!(random, replay(MainGenerator::new(), &"n".repeat(54)));
    }

    #[test]
    fn the_pod_in_the_deep_ends_in_death() {
        let mut pilot = fitted();
        let mut cockpit = Cockpit::new();
        cockpit.misjump = true;
        let mut bubble = Bubble::new();
        let escape = launch_pod(&pilot, &mut cockpit, &mut bubble).unwrap();
        assert!(escape.from_the_deep);
        let before = pilot.clone();
        let mut random = MainGenerator::new();
        let end = aftermath(
            &escape,
            &mut pilot,
            &mut cockpit,
            &mut bubble,
            &mut Navigation::start(&before),
            &mut Countdown::new(),
            &mut random,
        );
        let Aftermath::Died(dying) = end else { panic!("expected death") };
        assert_eq!(dying.cause, Cause::EscapeInTheDeep);
        assert_eq!(pilot, before, "no rescue");
        assert_eq!(bubble.len(), 4, "the wrecks");
        let pattern = format!("{} {} nc n nc n nc n nc n", "n".repeat(54), "n".repeat(54));
        assert_eq!(random, replay(MainGenerator::new(), &pattern), "the escape's reset, then the death's");
    }
}
