//! The player's roll and pitch rates, the option flags, and the angles motion uses (RULES B.5).

use super::HeldControls;

/// The centre of both rates: no turn.
pub const CENTRE: u8 = 128;
/// How far one tick of a held roll key moves the roll rate.
pub const ROLL_STEP: u8 = 7;
/// How far one tick of a held climb or dive key moves the pitch rate.
pub const PITCH_STEP: u8 = 14;
/// The roll angle a control reset leaves until the next angle computation: +3/256 rad.
pub const RESET_ROLL_ANGLE: f64 = 3.0 / 256.0;

/// The player's attitude: roll rate R and pitch rate P (1..255, centre 128), the auto-centre and
/// damping options, and the per-tick roll angle ρ and pitch angle φ in radians.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Attitude {
    pub roll_rate: u8,
    pub pitch_rate: u8,
    pub auto_centre: bool,
    pub damping: bool,
    pub roll_angle: f64,
    pub pitch_angle: f64,
}

impl Default for Attitude {
    fn default() -> Self {
        Self::new()
    }
}

impl Attitude {
    /// Both options on (their default) and the controls as a control reset leaves them.
    pub fn new() -> Self {
        let mut a = Self {
            roll_rate: CENTRE,
            pitch_rate: CENTRE,
            auto_centre: true,
            damping: true,
            roll_angle: 0.0,
            pitch_angle: 0.0,
        };
        a.reset();
        a
    }

    /// The control reset (every flight-state reset, the title, the escape pod): R = P = 128, roll
    /// angle +3/256 and pitch angle 0 until the next angle computation. The options are kept.
    pub fn reset(&mut self) {
        self.roll_rate = CENTRE;
        self.pitch_rate = CENTRE;
        self.roll_angle = RESET_ROLL_ANGLE;
        self.pitch_angle = 0.0;
    }

    /// Applies the held keys in the order roll left, roll right, climb, dive (RULES B.5.2).
    pub fn apply_keys(&mut self, held: HeldControls) {
        if held.roll_left {
            self.roll_rate = raise(self.roll_rate, ROLL_STEP, self.auto_centre);
        }
        if held.roll_right {
            self.roll_rate = lower(self.roll_rate, ROLL_STEP, self.auto_centre);
        }
        if held.climb {
            self.pitch_rate = lower(self.pitch_rate, PITCH_STEP, self.auto_centre);
        }
        if held.dive {
            self.pitch_rate = raise(self.pitch_rate, PITCH_STEP, self.auto_centre);
        }
    }

    /// Damps the rates when damping is on (R twice, P once) and computes the angles motion uses
    /// from the next substep on (RULES B.5.3).
    pub fn damp_and_angles(&mut self) {
        if self.damping {
            self.roll_rate = toward_centre(toward_centre(self.roll_rate));
        }
        let r = i32::from(self.roll_rate) - i32::from(CENTRE);
        self.roll_angle = f64::from(r.signum()) * f64::from(roll_magnitude(self.roll_rate)) / 256.0;
        if self.damping {
            self.pitch_rate = toward_centre(self.pitch_rate);
        }
        let p = i32::from(self.pitch_rate) - i32::from(CENTRE);
        self.pitch_angle = -f64::from(p.signum()) * f64::from(pitch_magnitude(self.pitch_rate)) / 256.0;
    }

    /// Step 1 of the tick: the held keys, then damping and the angles. While dying the caller
    /// passes [`HeldControls::NONE`].
    pub fn tick(&mut self, held: HeldControls) {
        self.apply_keys(held);
        self.damp_and_angles();
    }

    /// The roll magnitude of the current roll rate, 0..31.
    pub fn roll_magnitude(&self) -> u8 {
        roll_magnitude(self.roll_rate)
    }

    /// The pitch magnitude of the current pitch rate, 0..8.
    pub fn pitch_magnitude(&self) -> u8 {
        pitch_magnitude(self.pitch_rate)
    }
}

/// The roll magnitude of a roll rate: a = ⌊|R − 128| / 4⌋, halved (rounding down) when below 8.
pub fn roll_magnitude(roll_rate: u8) -> u8 {
    let a = (i32::from(roll_rate) - i32::from(CENTRE)).unsigned_abs() / 4;
    (if a < 8 { a / 2 } else { a }) as u8
}

/// The pitch magnitude of a pitch rate: b = ⌊(|P − 128| + 4) / 16⌋, halved (rounding down) when
/// below 3, so 2 never occurs.
pub fn pitch_magnitude(pitch_rate: u8) -> u8 {
    let b = ((i32::from(pitch_rate) - i32::from(CENTRE)).unsigned_abs() + 4) / 16;
    (if b < 3 { b / 2 } else { b }) as u8
}

/// v + n capped at 255; with auto-centre, a result below the centre snaps to it.
fn raise(v: u8, n: u8, auto_centre: bool) -> u8 {
    let r = v.saturating_add(n);
    if auto_centre && r < CENTRE {
        CENTRE
    } else {
        r
    }
}

/// v − n floored at 1; with auto-centre, a result above the centre snaps to it.
fn lower(v: u8, n: u8, auto_centre: bool) -> u8 {
    let r = v.saturating_sub(n).max(1);
    if auto_centre && r > CENTRE {
        CENTRE
    } else {
        r
    }
}

/// One step toward the centre.
fn toward_centre(v: u8) -> u8 {
    match v.cmp(&CENTRE) {
        std::cmp::Ordering::Less => v + 1,
        std::cmp::Ordering::Greater => v - 1,
        std::cmp::Ordering::Equal => v,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn held(f: impl FnOnce(&mut HeldControls)) -> HeldControls {
        let mut h = HeldControls::NONE;
        f(&mut h);
        h
    }

    #[test]
    fn roll_left_held_rises_a_net_five_a_tick_to_253_and_magnitude_31_after_25_ticks() {
        let mut a = Attitude::new();
        let left = held(|h| h.roll_left = true);
        for tick in 1..=24 {
            a.tick(left);
            assert_eq!(a.roll_rate, 128 + 5 * tick, "tick {tick}");
        }
        assert_eq!(a.roll_magnitude(), 30, "248 gives 30");
        a.tick(left);
        assert_eq!(a.roll_rate, 253, "255 cap, then −2");
        assert_eq!(a.roll_magnitude(), 31);
        assert_eq!(a.roll_angle, 31.0 / 256.0);
        a.tick(left);
        assert_eq!(a.roll_rate, 253, "stays at 253 while held");
    }

    #[test]
    fn dive_held_rises_a_net_thirteen_a_tick_to_254_and_magnitude_8_after_10_ticks() {
        let mut a = Attitude::new();
        let dive = held(|h| h.dive = true);
        for tick in 1..=9 {
            a.tick(dive);
            assert_eq!(a.pitch_rate, 128 + 13 * tick, "tick {tick}");
        }
        assert_eq!(a.pitch_magnitude(), 7, "245 gives 7");
        a.tick(dive);
        assert_eq!(a.pitch_rate, 254);
        assert_eq!(a.pitch_magnitude(), 8);
        assert_eq!(a.pitch_angle, -8.0 / 256.0, "a dive gives a negative pitch angle");
    }

    #[test]
    fn roll_right_and_climb_go_down_symmetrically() {
        let mut a = Attitude::new();
        let keys = held(|h| {
            h.roll_right = true;
            h.climb = true;
        });
        a.tick(keys);
        assert_eq!((a.roll_rate, a.pitch_rate), (123, 115));
        for _ in 0..40 {
            a.tick(keys);
        }
        assert_eq!(a.roll_rate, 3, "floor 1, then +2");
        assert_eq!(a.pitch_rate, 2, "floor 1, then +1");
        assert_eq!(a.roll_angle, -31.0 / 256.0);
        assert_eq!(a.pitch_angle, 8.0 / 256.0, "a climb gives a positive pitch angle");
    }

    #[test]
    fn on_release_roll_decays_by_two_and_pitch_by_one() {
        let mut a = Attitude::new();
        a.roll_rate = 200;
        a.pitch_rate = 60;
        a.tick(HeldControls::NONE);
        assert_eq!((a.roll_rate, a.pitch_rate), (198, 61));
        a.roll_rate = 129;
        a.tick(HeldControls::NONE);
        assert_eq!(a.roll_rate, 128, "damping stops at the centre");
    }

    #[test]
    fn without_damping_the_rates_hold() {
        let mut a = Attitude::new();
        a.damping = false;
        a.roll_rate = 200;
        a.pitch_rate = 60;
        a.tick(HeldControls::NONE);
        assert_eq!((a.roll_rate, a.pitch_rate), (200, 60));
        assert_eq!(a.roll_angle, 18.0 / 256.0, "|r| = 72 gives 18");
        assert_eq!(a.pitch_angle, 4.0 / 256.0, "|p| = 68 gives 4");
    }

    #[test]
    fn auto_centre_snaps_an_opposite_press_to_the_centre() {
        let mut a = Attitude::new();
        a.damping = false;
        a.roll_rate = 200;
        a.apply_keys(held(|h| h.roll_right = true));
        assert_eq!(a.roll_rate, 128, "193 snaps back to 128");
        a.pitch_rate = 40;
        a.apply_keys(held(|h| h.dive = true));
        assert_eq!(a.pitch_rate, 128, "54 snaps up to 128");
        a.auto_centre = false;
        a.roll_rate = 200;
        a.apply_keys(held(|h| h.roll_right = true));
        assert_eq!(a.roll_rate, 193);
    }

    #[test]
    fn both_keys_of_a_pair_cancel_from_centre_with_or_without_auto_centre() {
        let both = held(|h| {
            h.roll_left = true;
            h.roll_right = true;
            h.climb = true;
            h.dive = true;
        });
        for auto_centre in [true, false] {
            let mut a = Attitude::new();
            a.auto_centre = auto_centre;
            for _ in 0..5 {
                a.tick(both);
            }
            assert_eq!((a.roll_rate, a.pitch_rate), (128, 128), "auto-centre {auto_centre}");
            assert_eq!((a.roll_angle, a.pitch_angle), (0.0, 0.0));
        }
    }

    #[test]
    fn roll_magnitude_steps() {
        let expect = |r: i32| roll_magnitude((128 + r) as u8);
        for r in 0..=7 {
            assert_eq!(expect(r), 0, "|r| = {r}");
        }
        for (lo, m) in [(8, 1), (16, 2), (24, 3)] {
            for r in lo..lo + 8 {
                assert_eq!(expect(r), m, "|r| = {r}");
                assert_eq!(expect(-r), m, "|r| = {r}");
            }
        }
        assert_eq!(expect(32), 8, "jumps to 8 at 32");
        assert_eq!(expect(35), 8);
        assert_eq!(expect(36), 9);
        assert_eq!(expect(127), 31);
        assert_eq!(expect(-127), 31, "R = 1");
        assert!((1..=255u8).all(|r| !(4..=7).contains(&roll_magnitude(r)) && roll_magnitude(r) <= 31));
    }

    #[test]
    fn pitch_magnitude_steps() {
        let expect = |p: i32| pitch_magnitude((128 + p) as u8);
        for p in 0..=27 {
            assert_eq!(expect(p), 0, "|p| = {p}");
            assert_eq!(expect(-p), 0, "|p| = {p}");
        }
        for p in 28..=43 {
            assert_eq!(expect(p), 1, "|p| = {p}");
        }
        for p in 44..=59 {
            assert_eq!(expect(p), 3, "|p| = {p}");
        }
        assert_eq!(expect(60), 4);
        assert_eq!(expect(76), 5);
        assert_eq!(expect(124), 8);
        assert_eq!(expect(127), 8);
        assert!((1..=255u8).all(|p| pitch_magnitude(p) != 2), "2 never occurs");
    }

    #[test]
    fn angle_signs_follow_the_rates() {
        let mut a = Attitude::new();
        a.damping = false;
        a.roll_rate = 128 - 40;
        a.pitch_rate = 128 - 50;
        a.damp_and_angles();
        assert_eq!(a.roll_angle, -10.0 / 256.0);
        assert_eq!(a.pitch_angle, 3.0 / 256.0);
    }

    #[test]
    fn control_reset_centres_the_rates_and_sets_the_reset_angles() {
        let mut a = Attitude::new();
        a.auto_centre = false;
        a.roll_rate = 7;
        a.pitch_rate = 250;
        a.roll_angle = -0.1;
        a.pitch_angle = 0.2;
        a.reset();
        assert_eq!((a.roll_rate, a.pitch_rate), (128, 128));
        assert_eq!(a.roll_angle, 3.0 / 256.0);
        assert_eq!(a.pitch_angle, 0.0);
        assert!(!a.auto_centre, "the reset keeps the options");
        a.damp_and_angles();
        assert_eq!(a.roll_angle, 0.0, "the reset angle lasts until the next computation");
    }

    #[test]
    fn options_are_on_by_default() {
        let a = Attitude::default();
        assert!(a.auto_centre && a.damping);
        assert_eq!(a.roll_angle, RESET_ROLL_ANGLE);
    }
}
