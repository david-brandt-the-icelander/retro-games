//! Re-orthonormalisation: straightening an object's orientation vectors every 16 ticks
//! (RULES B.8).

use crate::capabilities::bubble::Object;

/// True on the ticks an object in `slot` is due: (C XOR slot) mod 16 = 0, with C the main counter
/// before this tick's decrement.
pub fn tidy_due(counter: u8, slot: usize) -> bool {
    (usize::from(counter) ^ slot).is_multiple_of(16)
}

/// Re-orthonormalises the object's vectors: nose to unit length; roof made perpendicular to the
/// nose, then to unit length; side ← nose × roof. A zero-length vector is left unscaled. Planets
/// and the sun are never re-orthonormalised, so bodies are left alone.
pub fn tidy(object: &mut Object) {
    if object.is_body() {
        return;
    }
    let nose = object.nose.normalised();
    let roof = (object.roof - nose * object.roof.dot(nose)).normalised();
    object.nose = nose;
    object.roof = roof;
    object.side = nose.cross(roof);
}

/// Step 3's first part of processing an object (RULES B.3.4): tidies a non-body that is neither
/// exploding nor killed when it is due. Returns whether it tidied.
pub fn tidy_if_due(object: &mut Object, counter: u8, slot: usize) -> bool {
    let due = !object.is_body() && !object.flags.exploding && !object.flags.killed && tidy_due(counter, slot);
    if due {
        tidy(object);
    }
    due
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{PLANET_A, SMALL_PIRATE_A, STATION, SUN};
    use crate::capabilities::space::Vec3;

    fn close(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-12
    }

    fn near(a: Vec3, b: Vec3) -> bool {
        (a - b).length() < 1e-15
    }

    fn assert_orthonormal(o: &Object) {
        for v in [o.nose, o.roof, o.side] {
            assert!(close(v.length(), 1.0), "{v:?} has length {}", v.length());
        }
        assert!(close(o.nose.dot(o.roof), 0.0));
        assert!(close(o.nose.dot(o.side), 0.0));
        assert!(close(o.roof.dot(o.side), 0.0));
    }

    #[test]
    fn the_schedule_is_every_sixteen_ticks_staggered_by_slot() {
        assert!(tidy_due(0, 0));
        assert!(tidy_due(16, 0));
        assert!(tidy_due(3, 3));
        assert!(tidy_due(19, 3));
        assert!(tidy_due(0x2C, 12), "0x2C XOR 12 = 0x20");
        assert!(!tidy_due(3, 2));
        assert!(!tidy_due(1, 0));
        for slot in 0..13 {
            let due = (0..=255u8).filter(|&c| tidy_due(c, slot)).count();
            assert_eq!(due, 16, "slot {slot}");
        }
    }

    #[test]
    fn a_hand_worked_frame() {
        // nose (0, 0, 2) → (0, 0, 1); roof (3, 4, 5) − 5·(0, 0, 1) = (3, 4, 0) → (0.6, 0.8, 0);
        // side = nose × roof = (0·0 − 1·0.8, 1·0.6 − 0·0, 0) = (−0.8, 0.6, 0).
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.nose = Vec3::new(0.0, 0.0, 2.0);
        o.roof = Vec3::new(3.0, 4.0, 5.0);
        o.side = Vec3::new(9.0, 9.0, 9.0);
        tidy(&mut o);
        assert_eq!(o.nose, Vec3::new(0.0, 0.0, 1.0));
        assert!(near(o.roof, Vec3::new(0.6, 0.8, 0.0)), "roof {:?}", o.roof);
        assert!(near(o.side, Vec3::new(-0.8, 0.6, 0.0)), "side {:?}", o.side);
        assert_orthonormal(&o);
    }

    #[test]
    fn a_skewed_shrunken_frame_comes_out_orthonormal() {
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.nose = Vec3::new(0.1, -0.3, -0.9);
        o.roof = Vec3::new(0.2, 0.95, 0.1);
        o.side = Vec3::new(0.7, 0.0, 0.0);
        tidy(&mut o);
        assert_orthonormal(&o);
        assert!(close(o.nose.cross(o.roof).dot(o.side), 1.0), "right-handed: side = nose × roof");
    }

    #[test]
    fn the_default_frame_gets_a_flipped_side() {
        // The default side (1, 0, 0) is replaced by nose × roof = (0,0,−1) × (0,1,0) = (1, 0, 0).
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        tidy(&mut o);
        assert_eq!(o.side, Vec3::new(1.0, 0.0, 0.0));
        // A mirrored frame like the new station's (nose (0, 0, 1), side copied) flips (Q-B9).
        let mut station = Object::new(STATION, Vec3::ZERO);
        station.nose = Vec3::new(0.0, 0.0, 1.0);
        tidy(&mut station);
        assert_eq!(station.side, Vec3::new(-1.0, 0.0, 0.0));
    }

    #[test]
    fn zero_vectors_are_left_unscaled() {
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.nose = Vec3::ZERO;
        o.roof = Vec3::new(0.0, 2.0, 0.0);
        tidy(&mut o);
        assert_eq!(o.nose, Vec3::ZERO);
        assert_eq!(o.roof, Vec3::new(0.0, 1.0, 0.0));
        assert_eq!(o.side, Vec3::ZERO);

        let mut parallel = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        parallel.nose = Vec3::new(0.0, 0.0, 4.0);
        parallel.roof = Vec3::new(0.0, 0.0, -3.0);
        tidy(&mut parallel);
        assert_eq!(parallel.nose, Vec3::new(0.0, 0.0, 1.0));
        assert_eq!(parallel.roof, Vec3::ZERO, "a roof along the nose projects to zero");
        assert_eq!(parallel.side, Vec3::ZERO);
    }

    #[test]
    fn bodies_are_never_tidied() {
        for kind in [PLANET_A, SUN] {
            let mut body = Object::new(kind, Vec3::ZERO);
            body.nose = Vec3::new(0.0, 0.0, -0.5);
            let before = body;
            tidy(&mut body);
            assert_eq!(body, before);
            assert!(!tidy_if_due(&mut body, 0, 0));
            assert_eq!(body, before);
        }
    }

    #[test]
    fn tidy_if_due_skips_exploding_and_killed_objects_and_off_schedule_ticks() {
        let shrunk = Vec3::new(0.0, 0.0, -0.5);
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.nose = shrunk;
        assert!(!tidy_if_due(&mut o, 1, 0));
        assert_eq!(o.nose, shrunk);
        o.flags.exploding = true;
        assert!(!tidy_if_due(&mut o, 0, 0));
        o.flags.exploding = false;
        o.flags.killed = true;
        assert!(!tidy_if_due(&mut o, 0, 0));
        assert_eq!(o.nose, shrunk);
        o.flags.killed = false;
        assert!(tidy_if_due(&mut o, 0x15, 5));
        assert_eq!(o.nose, Vec3::new(0.0, 0.0, -1.0));
    }
}
