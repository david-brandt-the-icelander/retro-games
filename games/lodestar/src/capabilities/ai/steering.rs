//! The pointing value and the steering rule every thinking object turns by (RULES C.5.3 step 3,
//! C.5.4).

use crate::capabilities::bubble::Object;
use crate::capabilities::ships::MISSILE;
use crate::capabilities::space::{SignMagnitude, Vec3};

/// P = 36 × (nose · D): −36 when the nose points straight at the player.
pub const POINTING_SCALE: f64 = 36.0;
/// The pitch magnitude every steer sets.
const PITCH_MAGNITUDE: u8 = 3;
/// The roll magnitude a steer sets, and the magnitude below which it may.
const ROLL_MAGNITUDE: u8 = 5;
const ROLL_BUSY: u8 = 16;
/// The speed thresholds on P, and the accelerations they give.
const SPEED_UP_FROM: f64 = 22.0;
const HOLD_BELOW: f64 = 18.0;
const SPEED_UP: u8 = 3;
/// −2 for a missile, −1 for any other ship, as signed bytes.
const MISSILE_BRAKE: u8 = (-2i8) as u8;
const SHIP_BRAKE: u8 = (-1i8) as u8;

/// The direction from the player to an object and how well its nose points along it.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Pointing {
    /// D: the unit vector from the player to the object.
    pub direction: Vec3,
    /// P = 36 × (nose · D), in −36..36 for a unit nose; −36 means the nose points at the player.
    pub value: f64,
}

/// D and P for an object (RULES C.5.3 step 3). The nose is used as stored.
pub fn pointing(object: &Object) -> Pointing {
    let direction = object.position.normalised();
    Pointing { direction, value: POINTING_SCALE * object.nose.dot(direction) }
}

/// The steering rule (RULES C.5.4): turn toward the unit vector `target` with pointing value `p`,
/// and, when `adjust_speed`, set the acceleration from the unrounded `p`.
///
/// The pitch counter becomes magnitude 3, negative when roof · T ≥ 0. Only if the roll counter's
/// magnitude is below 16, it becomes magnitude 5, negative exactly when "the pitch is negative"
/// differs from "side · T < 0" (the baseline's sign, kept by decision 9). With P ≥ 22 the
/// acceleration is +3; with |P| < 18 it is left alone; otherwise −2 for a missile, −1 for any
/// other ship.
pub fn steer(object: &mut Object, target: Vec3, p: f64, adjust_speed: bool) {
    let pitch_negative = object.roof.dot(target) >= 0.0;
    object.pitch = SignMagnitude::new(pitch_negative, PITCH_MAGNITUDE);
    if object.roll.magnitude() < ROLL_BUSY {
        let side_negative = object.side.dot(target) < 0.0;
        object.roll = SignMagnitude::new(pitch_negative != side_negative, ROLL_MAGNITUDE);
    }
    if adjust_speed {
        if p >= SPEED_UP_FROM {
            object.acceleration = SPEED_UP;
        } else if p.abs() >= HOLD_BELOW {
            object.acceleration = if object.kind == MISSILE { MISSILE_BRAKE } else { SHIP_BRAKE };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{SMALL_PIRATE_A, TRADER};

    fn ship() -> Object {
        Object::new(TRADER, Vec3::new(0.0, 0.0, 1000.0))
    }

    #[test]
    fn a_new_ship_points_straight_at_the_player() {
        let p = pointing(&ship());
        assert_eq!(p.direction, Vec3::new(0.0, 0.0, 1.0));
        assert_eq!(p.value, -36.0);
        let mut away = ship();
        away.position = Vec3::new(0.0, 0.0, -500.0);
        assert_eq!(pointing(&away).value, 36.0);
        let mut beside = ship();
        beside.position = Vec3::new(300.0, 0.0, 0.0);
        assert_eq!(pointing(&beside).value, 0.0);
    }

    #[test]
    fn pitch_sign_follows_the_roof() {
        let mut s = ship();
        // Default roof (0, 1, 0): a target above gives roof · T > 0, so a negative pitch.
        steer(&mut s, Vec3::new(0.0, 1.0, 0.0), 0.0, false);
        assert_eq!(s.pitch, SignMagnitude::new(true, 3));
        steer(&mut s, Vec3::new(0.0, -1.0, 0.0), 0.0, false);
        assert_eq!(s.pitch, SignMagnitude::new(false, 3));
        // roof · T = 0 counts as ≥ 0.
        steer(&mut s, Vec3::new(1.0, 0.0, 0.0), 0.0, false);
        assert!(s.pitch.is_negative());
    }

    #[test]
    fn roll_sign_is_the_baselines() {
        let mut s = ship();
        // Target above and to +x: pitch negative (q), side (1,0,0) · T > 0 so r false → negative.
        steer(&mut s, Vec3::new(0.6, 0.8, 0.0), 0.0, false);
        assert_eq!(s.roll, SignMagnitude::new(true, 5));
        // Target above and to −x: q true, r true → positive.
        s.roll = SignMagnitude::ZERO;
        steer(&mut s, Vec3::new(-0.6, 0.8, 0.0), 0.0, false);
        assert_eq!(s.roll, SignMagnitude::new(false, 5));
        // Target below and to −x: q false, r true → negative.
        steer(&mut s, Vec3::new(-0.6, -0.8, 0.0), 0.0, false);
        assert_eq!(s.roll, SignMagnitude::new(true, 5));
    }

    #[test]
    fn a_busy_roll_is_left_alone() {
        let mut s = ship();
        s.roll = SignMagnitude::new(false, 16);
        steer(&mut s, Vec3::new(0.6, 0.8, 0.0), 0.0, false);
        assert_eq!(s.roll, SignMagnitude::new(false, 16));
        s.roll = SignMagnitude::new(false, 15);
        steer(&mut s, Vec3::new(0.6, 0.8, 0.0), 0.0, false);
        assert_eq!(s.roll, SignMagnitude::new(true, 5));
    }

    #[test]
    fn speed_from_the_unrounded_pointing_value() {
        let t = Vec3::new(0.0, 0.0, 1.0);
        let mut s = ship();
        steer(&mut s, t, 22.0, true);
        assert_eq!(s.acceleration, 3);
        s.acceleration = 0;
        steer(&mut s, t, 21.99, true);
        assert_eq!(s.acceleration, 255, "18 ≤ P < 22 brakes");
        s.acceleration = 9;
        steer(&mut s, t, 17.99, true);
        assert_eq!(s.acceleration, 9, "|P| < 18 leaves it");
        steer(&mut s, t, -17.99, true);
        assert_eq!(s.acceleration, 9);
        steer(&mut s, t, -18.0, true);
        assert_eq!(s.acceleration, 255);
        steer(&mut s, t, 30.0, false);
        assert_eq!(s.acceleration, 255, "no adjustment when not asked");
        let mut missile = Object::new(MISSILE, Vec3::ZERO);
        steer(&mut missile, t, -20.0, true);
        assert_eq!(missile.acceleration, 254, "a missile brakes by 2");
        let mut fighter = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        steer(&mut fighter, t, -36.0, true);
        assert_eq!(fighter.acceleration, 255);
    }
}
