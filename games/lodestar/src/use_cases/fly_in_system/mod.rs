//! Fly in a system: the pilot's goal while launched, and the owner of the 12 Hz tick.
//!
//! The document beside this file, `fly_in_system.md`, says what the use case does and what is
//! built yet. RULES B gives the order of everything a tick does.

use crate::capabilities::random::MainGenerator;

/// Logic ticks per second (RULES B: the logic runs at 12 Hz).
pub const TICKS_PER_SECOND: u32 = 12;

/// The longest frame the clock accepts, in seconds. A longer gap (a stall, a breakpoint) is
/// cut to this, so the sim never runs a burst of catch-up ticks.
pub const MAX_FRAME_SECONDS: f64 = 0.25;

/// Turns frame times into whole logic ticks, and says how far the picture is between the last
/// two ticks.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct TickClock {
    accumulated: f64,
}

impl TickClock {
    pub const fn new() -> Self {
        Self { accumulated: 0.0 }
    }

    /// Adds one frame's time and returns how many ticks to run now.
    pub fn advance(&mut self, frame_seconds: f64) -> u32 {
        let step = 1.0 / f64::from(TICKS_PER_SECOND);
        let frame = if frame_seconds.is_finite() { frame_seconds.clamp(0.0, MAX_FRAME_SECONDS) } else { 0.0 };
        self.accumulated += frame;
        let mut ticks = 0;
        while self.accumulated >= step {
            self.accumulated -= step;
            ticks += 1;
        }
        ticks
    }

    /// How far the present moment is from the last tick toward the next, 0.0..1.0. The picture
    /// interpolates between the previous and the current state by this much.
    pub fn alpha(&self) -> f64 {
        (self.accumulated * f64::from(TICKS_PER_SECOND)).clamp(0.0, 1.0)
    }
}

/// What the pilot did since the last tick: held actions sampled at the tick, and presses
/// queued so that a tap between two ticks is never lost (DESIGN § Keyboard controls).
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct InputRecord {
    pub held: HeldActions,
    pub presses: Vec<Press>,
}

/// Actions that count while held.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct HeldActions {
    pub dive: bool,
    pub climb: bool,
    pub roll_left: bool,
    pub roll_right: bool,
    pub speed_up: bool,
    pub slow_down: bool,
    pub fire: bool,
}

/// Actions that happen once per press.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Press {
    /// Choose the active laser mount: 0 front, 1 rear, 2 left, 3 right.
    Mount(u8),
}

/// Something a tick did that the picture or the sound should react to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Event {
    /// The active mount changed.
    MountSelected(u8),
}

/// The pilot in flight: the bubble, the player's ship and the tick that moves them.
#[derive(Clone, Debug, Default)]
pub struct FlyInSystem {
    ticks: u64,
    active_mount: u8,
    random: MainGenerator,
}

impl FlyInSystem {
    pub fn new() -> Self {
        Self::default()
    }

    /// Runs one logic tick and returns its events, in the order they happened.
    pub fn tick(&mut self, input: &InputRecord) -> Vec<Event> {
        let mut events = Vec::new();
        for press in &input.presses {
            match *press {
                Press::Mount(mount) if mount < 4 && mount != self.active_mount => {
                    self.active_mount = mount;
                    events.push(Event::MountSelected(mount));
                }
                Press::Mount(_) => {}
            }
        }
        self.ticks += 1;
        events
    }

    /// Ticks run since launch.
    pub fn ticks(&self) -> u64 {
        self.ticks
    }

    /// The mount whose lasers fire: 0 front, 1 rear, 2 left, 3 right.
    pub fn active_mount(&self) -> u8 {
        self.active_mount
    }

    /// The main generator, for the rules that draw from it.
    pub fn random(&mut self) -> &mut MainGenerator {
        &mut self.random
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twelve_ticks_a_second_whatever_the_frame_rate() {
        for fps in [30.0, 60.0, 144.0, 240.0] {
            let mut clock = TickClock::new();
            let frames = fps as usize * 10;
            let ticks: u32 = (0..frames).map(|_| clock.advance(1.0 / fps)).sum();
            assert!((119..=120).contains(&ticks), "{fps} fps gave {ticks} ticks in 10 s");
        }
    }

    #[test]
    fn alpha_tracks_the_time_since_the_last_tick() {
        let mut clock = TickClock::new();
        assert_eq!(clock.advance(1.0 / 24.0), 0);
        assert!((clock.alpha() - 0.5).abs() < 1e-9);
        assert_eq!(clock.advance(1.0 / 24.0), 1);
        assert!(clock.alpha() < 1e-9);
    }

    #[test]
    fn a_stall_is_cut_to_the_longest_frame() {
        let mut clock = TickClock::new();
        assert_eq!(clock.advance(10.0), 3);
        assert_eq!(clock.advance(f64::NAN), 0);
        assert_eq!(clock.advance(-1.0), 0);
    }

    #[test]
    fn a_mount_press_changes_the_active_mount_once() {
        let mut sim = FlyInSystem::new();
        let input = InputRecord { presses: vec![Press::Mount(2), Press::Mount(2), Press::Mount(9)], ..Default::default() };
        assert_eq!(sim.tick(&input), vec![Event::MountSelected(2)]);
        assert_eq!(sim.active_mount(), 2);
        assert_eq!(sim.ticks(), 1);
    }
}
