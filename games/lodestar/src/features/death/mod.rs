//! Death (RULES B.18, C.10.4, D.3.10): the reset at the speed's quarter, the four wreck
//! canisters, the 61 dying ticks and the return to the title with the last saved pilot.
//! Dying cancels a running hyperspace countdown (deliberate difference 5). See `death.md`.

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::ships::CANISTER;
use crate::capabilities::space::{SignMagnitude, Vec3};
use crate::features::hyperspace::Countdown;
use crate::features::saving::Pilots;
use crate::features::spawning::hostile_template;

/// The dying ticks before the title: round(5.1 × 12) (RULES B.18, C.10.4).
pub const DYING_TICKS: u8 = 61;
/// The wreck canisters left where the player was (RULES B.18).
pub const WRECKS: usize = 4;
/// The main counter at death (RULES B.18).
pub const COUNTER_AT_DEATH: u8 = 255;

/// Why the player died, for the death panel's epitaph (GDD `ui.epitaph`). The rules do the same
/// whatever the cause.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cause {
    /// Into the planet (RULES B.14).
    Crashed,
    /// Burned up by the sun (RULES B.15.1).
    Burned,
    /// A failed docking at speed 5 or more (RULES B.12.2).
    Docking,
    /// Damage took the energy to 0 (RULES C.10.2).
    Damage,
    /// The escape pod used in the Deep (RULES B.17).
    EscapeInTheDeep,
}

/// The death sequence under way. The lead's mode machine holds it while in Death mode and runs
/// the dying form of the tick logic (no player controls or actions, no periodic spawning) each
/// tick before [`Dying::tick`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Dying {
    ticks_left: u8,
    /// What killed the player.
    pub cause: Cause,
    /// True when the player died in the Deep (read before the reset clears it).
    pub in_the_deep: bool,
}

impl Dying {
    /// Counts one dying tick. Returns true when the 61 ticks are over and the title starts
    /// (then call [`return_to_title`]).
    pub fn tick(&mut self) -> bool {
        self.ticks_left = self.ticks_left.saturating_sub(1);
        self.ticks_left == 0
    }

    /// Dying ticks left.
    pub fn ticks_left(&self) -> u8 {
        self.ticks_left
    }
}

/// The player dies (RULES B.18, C.10.4, D.3.10). The lead calls this only when not already
/// dying, and clears held keys and queued presses. In order: the countdown is cancelled
/// (deliberate difference 5); k = ⌊speed / 4⌋; the flight state is reset (54 draws) with the
/// bubble emptied; speed k; the front mount; C = 255; four wreck canisters, each from the hostile
/// template's returned pair and one more byte that, when odd, marks it killed; then speed 0.
/// The mode becomes Death, showing the game-over notice.
pub fn die(
    cause: Cause,
    cockpit: &mut Cockpit,
    bubble: &mut Bubble,
    countdown: &mut Countdown,
    random: &mut MainGenerator,
) -> Dying {
    let in_the_deep = cockpit.misjump;
    countdown.cancel();
    let quarter = cockpit.speed / 4;
    cockpit.reset(random);
    bubble.clear();
    cockpit.speed = quarter;
    cockpit.active_mount = 0;
    cockpit.counter = COUNTER_AT_DEATH;
    for _ in 0..WRECKS {
        let (_, pair) = hostile_template(random);
        let x0 = (pair.a / 4) & 63;
        let position = Vec3::new(f64::from(x0), f64::from(x0 ^ 0x2A), f64::from(x0 | 0x50));
        let mut wreck = Object::new(CANISTER, position);
        wreck.roll = SignMagnitude(pair.x & 0x8F);
        wreck.pitch = SignMagnitude((pair.x / 2) & 0x87);
        wreck.ai = 0;
        wreck.nose = Vec3::new(0.0, 0.0, 1.0);
        wreck.side = Vec3::new(-1.0, 0.0, 0.0);
        wreck.roof = Vec3::new(0.0, 1.0, 0.0);
        wreck.speed = quarter.wrapping_mul(2);
        wreck.flags.killed = random.byte() & 1 == 1;
        bubble.add(wreck);
    }
    cockpit.speed = 0;
    Dying { ticks_left: DYING_TICKS, cause, in_the_deep }
}

/// The end of the death sequence (RULES D.3.10, A.7.3): the countdown is cancelled and the
/// playing pilot becomes the last saved or loaded one; nothing of the dead pilot is kept. The
/// mode becomes Title.
pub fn return_to_title(pilots: &mut Pilots, countdown: &mut Countdown) {
    countdown.cancel();
    pilots.on_death();
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::Object;
    use crate::capabilities::pilot::Pilot;
    use crate::capabilities::ships::POLICE;
    use crate::features::hyperspace::Destination;
    use crate::features::spawning::test_support::replay;

    #[test]
    fn the_four_wrecks_from_the_starting_state() {
        // After the reset's 54 draws, each wreck takes a template (ordinary then carry-cleared
        // draw) and one more byte. Worked from RULES C.2.1 and C.10.4:
        // wreck 0: pair (0xB3, 0x97): x0 = (179 / 4) & 63 = 44, y = 44 ^ 42 = 6,
        //   z = 44 | 80 = 124; roll = 0x97 & 0x8F = 0x87, pitch = (0x97 / 2) & 0x87 = 0x03;
        //   byte 0x4A even: not killed.
        // wreck 1: pair (0x48, 0xFE): 18, 56, 82; roll 0x8E, pitch 0x07; 0x46 even.
        // wreck 2: pair (0xD6, 0x8F): 53, 31, 117; roll 0x8F, pitch 0x07; 0x66 even.
        // wreck 3: pair (0xA3, 0x3C): 40, 2, 120; roll 0x0C, pitch 0x06; 0xDF odd: killed.
        let mut cockpit = Cockpit::new();
        cockpit.speed = 39;
        cockpit.active_mount = 1;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(POLICE, Vec3::ZERO));
        let mut countdown = Countdown::new();
        let mut random = MainGenerator::new();
        let dying = die(Cause::Damage, &mut cockpit, &mut bubble, &mut countdown, &mut random);
        let expected = [
            ((44.0, 6.0, 124.0), 0x87, 0x03, false),
            ((18.0, 56.0, 82.0), 0x8E, 0x07, false),
            ((53.0, 31.0, 117.0), 0x8F, 0x07, false),
            ((40.0, 2.0, 120.0), 0x0C, 0x06, true),
        ];
        assert_eq!(bubble.len(), 4);
        for (wreck, ((x, y, z), roll, pitch, killed)) in bubble.iter().zip(expected) {
            assert_eq!(wreck.kind, CANISTER);
            assert_eq!(wreck.position, Vec3::new(x, y, z));
            assert_eq!((wreck.roll.0, wreck.pitch.0, wreck.flags.killed), (roll, pitch, killed));
            assert_eq!((wreck.ai, wreck.speed), (0, 18), "speed 2 × ⌊39 / 4⌋");
            assert_eq!(wreck.nose, Vec3::new(0.0, 0.0, 1.0));
            assert_eq!(wreck.side, Vec3::new(-1.0, 0.0, 0.0));
            assert_eq!(wreck.roof, Vec3::new(0.0, 1.0, 0.0));
        }
        let pattern = format!("{} nc n nc n nc n nc n", "n".repeat(54));
        assert_eq!(random, replay(MainGenerator::new(), &pattern), "54, then 4 × (2 + 1)");
        assert_eq!((cockpit.speed, cockpit.counter, cockpit.active_mount), (0, 255, 0));
        assert_eq!((dying.ticks_left(), dying.cause, dying.in_the_deep), (61, Cause::Damage, false));
    }

    #[test]
    fn dying_cancels_the_countdown() {
        // Deliberate difference 5: no jump can rescue a dead pilot.
        let mut countdown = Countdown::new();
        countdown.start(Destination::NextGalaxy);
        let mut cockpit = Cockpit::new();
        cockpit.misjump = true;
        let dying = die(Cause::Crashed, &mut cockpit, &mut Bubble::new(), &mut countdown, &mut MainGenerator::new());
        assert!(!countdown.running());
        assert!(dying.in_the_deep);
        assert!(!cockpit.misjump, "the reset leaves the Deep");
    }

    #[test]
    fn sixty_one_dying_ticks_then_the_title_with_the_saved_pilot() {
        let mut cockpit = Cockpit::new();
        let mut countdown = Countdown::new();
        let mut dying = die(Cause::Burned, &mut cockpit, &mut Bubble::new(), &mut countdown, &mut MainGenerator::new());
        for _ in 0..60 {
            assert!(!dying.tick());
        }
        assert!(dying.tick());
        let mut pilots = Pilots::new(Pilot::start());
        pilots.playing.cash = 99_999;
        pilots.playing.kills = 300;
        return_to_title(&mut pilots, &mut countdown);
        assert_eq!(pilots.playing, Pilot::start(), "nothing of the dead pilot is kept");
    }

    #[test]
    fn the_wrecks_fly_at_twice_the_speeds_quarter() {
        // ⌊3 / 4⌋ = 0: a slow death leaves the wrecks still; ⌊40 / 4⌋ = 10 gives 20.
        let mut cockpit = Cockpit::new();
        let mut bubble = Bubble::new();
        die(Cause::Docking, &mut cockpit, &mut bubble, &mut Countdown::new(), &mut MainGenerator::new());
        assert!(bubble.iter().all(|w| w.speed == 0));
        let mut cockpit = Cockpit::new();
        cockpit.speed = 40;
        let mut bubble = Bubble::new();
        die(Cause::Docking, &mut cockpit, &mut bubble, &mut Countdown::new(), &mut MainGenerator::new());
        assert!(bubble.iter().all(|w| w.speed == 20));
    }
}
