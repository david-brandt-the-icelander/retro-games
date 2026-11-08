//! Space: vectors in sim units and the coarse, fine and far tests the rules use (RULES B.1, C.1),
//! and the sign-magnitude counters that turn objects (RULES B.7.1, C.1).

use std::ops::{Add, AddAssign, Mul, Neg, Sub, SubAssign};

/// Sim units per coarse unit (K).
pub const COARSE: f64 = 256.0;
/// Sim units per far unit (L).
pub const FAR: f64 = 65_536.0;

/// A vector in sim units: x right, y up, z forward, relative to the player.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Vec3 {
    pub const ZERO: Vec3 = Vec3::new(0.0, 0.0, 0.0);

    pub const fn new(x: f64, y: f64, z: f64) -> Self {
        Self { x, y, z }
    }

    pub fn dot(self, other: Vec3) -> f64 {
        self.x * other.x + self.y * other.y + self.z * other.z
    }

    /// The right-handed cross product RULES B.8 uses for re-orthonormalisation.
    pub fn cross(self, other: Vec3) -> Vec3 {
        Vec3::new(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x,
        )
    }

    pub fn length(self) -> f64 {
        self.dot(self).sqrt()
    }

    /// This vector scaled to unit length; a zero vector is returned unchanged (RULES B.8).
    pub fn normalised(self) -> Vec3 {
        let length = self.length();
        if length == 0.0 {
            self
        } else {
            self * (1.0 / length)
        }
    }

    /// The three coordinates in order x, y, z.
    pub fn components(self) -> [f64; 3] {
        [self.x, self.y, self.z]
    }
}

impl Add for Vec3 {
    type Output = Vec3;
    fn add(self, o: Vec3) -> Vec3 {
        Vec3::new(self.x + o.x, self.y + o.y, self.z + o.z)
    }
}

impl AddAssign for Vec3 {
    fn add_assign(&mut self, o: Vec3) {
        *self = *self + o;
    }
}

impl Sub for Vec3 {
    type Output = Vec3;
    fn sub(self, o: Vec3) -> Vec3 {
        Vec3::new(self.x - o.x, self.y - o.y, self.z - o.z)
    }
}

impl SubAssign for Vec3 {
    fn sub_assign(&mut self, o: Vec3) {
        *self = *self - o;
    }
}

impl Mul<f64> for Vec3 {
    type Output = Vec3;
    fn mul(self, k: f64) -> Vec3 {
        Vec3::new(self.x * k, self.y * k, self.z * k)
    }
}

impl Neg for Vec3 {
    type Output = Vec3;
    fn neg(self) -> Vec3 {
        Vec3::new(-self.x, -self.y, -self.z)
    }
}

/// The integer magnitude ⌊|v|⌋ of a coordinate.
pub fn magnitude(v: f64) -> u64 {
    v.abs().floor() as u64
}

/// The coarse value of a coordinate: (⌊|v|⌋ div 256) mod 256. It wraps: coarse(65536) = 0.
pub fn coarse(v: f64) -> u8 {
    ((magnitude(v) / 256) % 256) as u8
}

/// The fine value of a coordinate: ⌊|v|⌋ mod 256.
pub fn fine(v: f64) -> u8 {
    (magnitude(v) % 256) as u8
}

/// True when |v| ≥ 65536, one far unit.
pub fn far(v: f64) -> bool {
    v.abs() >= FAR
}

/// A sign-magnitude byte: bit 7 is the sign (set = negative), bits 0..6 the magnitude 0..127.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct SignMagnitude(pub u8);

impl SignMagnitude {
    pub const ZERO: SignMagnitude = SignMagnitude(0);
    /// Magnitude 127 means "turn forever"; it never decays.
    pub const FOREVER: u8 = 127;

    pub const fn new(negative: bool, magnitude: u8) -> Self {
        SignMagnitude(((negative as u8) << 7) | (magnitude & 0x7F))
    }

    pub const fn magnitude(self) -> u8 {
        self.0 & 0x7F
    }

    pub const fn is_negative(self) -> bool {
        self.0 & 0x80 != 0
    }

    /// −1.0 when the sign bit is set, otherwise +1.0.
    pub fn sign(self) -> f64 {
        if self.is_negative() {
            -1.0
        } else {
            1.0
        }
    }

    /// Decays the magnitude by 1, keeping the sign, unless it is 0 or 127 (RULES B.7.3).
    pub fn decay(&mut self) {
        let m = self.magnitude();
        if m != 0 && m != Self::FOREVER {
            *self = SignMagnitude::new(self.is_negative(), m - 1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn coarse_fine_and_far() {
        assert_eq!(coarse(57_599.9), 224);
        assert_eq!(coarse(57_600.0), 225);
        assert_eq!(coarse(-300.0), 1);
        assert_eq!(fine(-300.0), 44);
        assert_eq!(coarse(65_536.0), 0, "coarse wraps");
        assert!(far(-65_536.0));
        assert!(!far(65_535.9));
    }

    #[test]
    fn sign_magnitude_decay() {
        let mut c = SignMagnitude::new(true, 3);
        c.decay();
        assert_eq!(c, SignMagnitude::new(true, 2));
        let mut forever = SignMagnitude::new(false, 127);
        forever.decay();
        assert_eq!(forever.magnitude(), 127);
        let mut zero = SignMagnitude::ZERO;
        zero.decay();
        assert_eq!(zero, SignMagnitude::ZERO);
        assert_eq!(SignMagnitude::new(true, 5).sign(), -1.0);
    }

    #[test]
    fn cross_is_right_handed_and_zero_stays_zero() {
        let x = Vec3::new(1.0, 0.0, 0.0);
        let y = Vec3::new(0.0, 1.0, 0.0);
        assert_eq!(x.cross(y), Vec3::new(0.0, 0.0, 1.0));
        assert_eq!(Vec3::ZERO.normalised(), Vec3::ZERO);
    }
}
