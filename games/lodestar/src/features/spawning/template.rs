//! Placements: the hostile template (RULES B.10.3, C.16.4), the alien group (B.10.4, C.16.6),
//! launching straight ahead (B.10.5) and the placement of a ship's children (B.10.6).

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::random::{Draw, MainGenerator};
use crate::capabilities::ships::{TypeNumber, ALIEN_DRONE, ALIEN_MOTHERSHIP, STATION};
use crate::capabilities::space::{SignMagnitude, Vec3};

/// How far out on each axis the hostile template is placed: 32 K (RULES B.10.3).
pub const TEMPLATE_DISTANCE: f64 = 8192.0;
/// The hostile template's AI byte: AI on, aggression 32 (RULES C.16.4).
pub const HOSTILE_AI: u8 = 0xC0;
/// The alien group's AI byte (RULES B.10.4).
pub const ALIEN_AI: u8 = 0xFF;
/// The template's second byte from this up fits an E.C.M. (RULES C.16.4).
const TEMPLATE_ECM_FROM: u8 = 245;
/// Where a launch straight ahead starts: just below and ahead of the player (RULES B.10.5).
pub const LAUNCH_POSITION: Vec3 = Vec3::new(0.0, -28.0, 14.0);
/// How far along its nose the station puts a child (RULES B.10.6).
pub const STATION_CHILD_OFFSET: f64 = 192.0;
/// A child of the station leaves at this speed (RULES B.10.6).
pub const STATION_CHILD_SPEED: u8 = 32;

/// What a new object copies from the rule that creates it (RULES B.9.3): position, orientation,
/// AI byte, speed and both counters.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Template {
    pub position: Vec3,
    pub nose: Vec3,
    pub roof: Vec3,
    pub side: Vec3,
    pub ai: u8,
    pub speed: u8,
    pub pitch: SignMagnitude,
    pub roll: SignMagnitude,
}

impl Template {
    /// A template at `position` with the default orientation (nose toward the player), AI byte
    /// 0, speed 0 and counters 0 (RULES B.2, B.9.3).
    pub fn at(position: Vec3) -> Self {
        let blank = Object::new(0, position);
        Self {
            position,
            nose: blank.nose,
            roof: blank.roof,
            side: blank.side,
            ai: 0,
            speed: 0,
            pitch: SignMagnitude::ZERO,
            roll: SignMagnitude::ZERO,
        }
    }

    /// A fresh object of `kind` made from the template: the template's fields, and the type's
    /// own energy and missiles (RULES B.9.3, C.16.4).
    pub fn make(&self, kind: TypeNumber) -> Object {
        let mut object = Object::new(kind, self.position);
        object.nose = self.nose;
        object.roof = self.roof;
        object.side = self.side;
        object.ai = self.ai;
        object.speed = self.speed;
        object.pitch = self.pitch;
        object.roll = self.roll;
        object
    }
}

/// The hostile template procedure (RULES B.10.3, C.16.4): one ordinary draw places the template
/// at (±8192, ±8192, 8192), the signs from the top bits of its `a` and `x`, with AI byte 0xC0
/// and the E.C.M. bit when `x` ≥ 245; then a carry-cleared draw, returned for the caller to use
/// as its "(a, x)". Spawning, the alien group and the death wrecks all use it.
pub fn hostile_template(random: &mut MainGenerator) -> (Template, Draw) {
    let first = random.draw();
    let x = signed(TEMPLATE_DISTANCE, first.a);
    let y = signed(TEMPLATE_DISTANCE, first.x);
    let mut template = Template::at(Vec3::new(x, y, TEMPLATE_DISTANCE));
    template.ai = HOSTILE_AI | u8::from(first.x >= TEMPLATE_ECM_FROM);
    let returned = random.draw_carry_cleared();
    (template, returned)
}

/// The alien group (RULES B.10.4, C.16.6): a hostile template with AI byte 0xFF, then an alien
/// mothership and an alien drone made from it, in that order. Returns false when either add
/// failed because the bubble was full; the draws are spent either way.
pub fn alien_group(bubble: &mut Bubble, random: &mut MainGenerator) -> bool {
    let (mut template, _) = hostile_template(random);
    template.ai = ALIEN_AI;
    let mothership = bubble.add(template.make(ALIEN_MOTHERSHIP)).is_some();
    let drone = bubble.add(template.make(ALIEN_DRONE)).is_some();
    mothership && drone
}

/// An object launched straight ahead of the player (RULES B.10.5): at (0, −28, 14), nose
/// (0, 0, 1), roof (0, 1, 0), side (−1, 0, 0), AI byte 0x80 OR (target slot mod 32) × 2 and
/// speed (2 × player speed) mod 256, which the next own-motion update clamps. The player's
/// missiles and the escape pod's abandoned hull start this way.
pub fn launch_straight_ahead(kind: TypeNumber, target_slot: usize, player_speed: u8) -> Object {
    let mut object = Object::new(kind, LAUNCH_POSITION);
    object.nose = Vec3::new(0.0, 0.0, 1.0);
    object.roof = Vec3::new(0.0, 1.0, 0.0);
    object.side = Vec3::new(-1.0, 0.0, 0.0);
    object.ai = 0x80 | (((target_slot % 32) as u8) << 1);
    object.speed = player_speed.wrapping_mul(2);
    object
}

/// Where a ship's child starts (RULES B.10.6): a copy of the parent's position, orientation,
/// speed and counters with bit 0 of the roll counter cleared; a child of the station is moved
/// 192 sim units along the station's nose as stored and leaves at speed 32. The AI byte is 0
/// here: the rule that launches the child sets it, and draws anything else it needs (C.5.7).
pub fn child_of(parent: &Object, kind: TypeNumber) -> Object {
    let mut child = Object::new(kind, parent.position);
    child.nose = parent.nose;
    child.roof = parent.roof;
    child.side = parent.side;
    child.speed = parent.speed;
    child.pitch = parent.pitch;
    child.roll = SignMagnitude(parent.roll.0 & 0xFE);
    if parent.kind == STATION {
        child.position += parent.nose * STATION_CHILD_OFFSET;
        child.speed = STATION_CHILD_SPEED;
    }
    child
}

/// `value`, negated when bit 7 of `byte` is set.
pub(super) fn signed(value: f64, byte: u8) -> f64 {
    if byte & 0x80 != 0 {
        -value
    } else {
        value
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::bubble::CAPACITY;
    use crate::features::spawning::test_support::replay;
    use crate::capabilities::ships::{CANISTER, MISSILE, POLICE, TRADER};

    #[test]
    fn the_hostile_template_from_the_starting_state() {
        // Worked by hand from RULES C.2.1: the first draw is (0xAC, 0x34); 0xAC has bit 7 set,
        // so x = −8192; 0x34 does not, so y = +8192; 0x34 < 245, so no E.C.M. The carry-cleared
        // draw that follows is (0xE1, 0xAC).
        let mut random = MainGenerator::new();
        let (t, returned) = hostile_template(&mut random);
        assert_eq!(t.position, Vec3::new(-8192.0, 8192.0, 8192.0));
        assert_eq!(t.ai, 0xC0);
        assert_eq!(returned, Draw { a: 0xE1, x: 0xAC });
        assert_eq!(t.nose, Vec3::new(0.0, 0.0, -1.0), "nose at the player");
        assert_eq!((t.speed, t.pitch, t.roll), (0, SignMagnitude::ZERO, SignMagnitude::ZERO));
        // The second template from there: (0x8E, 0xE1) gives (−8192, −8192), and 0xE1 = 225 is
        // still below 245.
        let (t, returned) = hostile_template(&mut random);
        assert_eq!(t.position, Vec3::new(-8192.0, -8192.0, 8192.0));
        assert_eq!(t.ai, 0xC0);
        assert_eq!(returned, Draw { a: 0x6F, x: 0x8E });
    }

    #[test]
    fn the_template_fits_an_ecm_from_245() {
        // Over many seeds the E.C.M. bit is exactly "first x ≥ 245", and the draw after the
        // template follows a carry-cleared draw.
        for seed in 0..=255u8 {
            let mut random = MainGenerator::with_seed([seed, 0x34, 0x56, 0x78]);
            let mut reference = random;
            let first = reference.draw();
            let (t, _) = hostile_template(&mut random);
            assert_eq!(t.ai & 1, u8::from(first.x >= 245));
            assert_eq!(random.draw(), {
                reference.draw_carry_cleared();
                reference.draw()
            });
        }
        let mut random = MainGenerator::with_seed([0, 0xF5, 0, 0]);
        assert_eq!(hostile_template(&mut random).0.ai, 0xC1, "x = 0xF5 = 245 fits one");
        let mut random = MainGenerator::with_seed([0, 0xF4, 0, 0]);
        assert_eq!(hostile_template(&mut random).0.ai, 0xC0, "x = 244 does not");
    }

    #[test]
    fn a_template_makes_objects_with_their_type_energy() {
        let mut t = Template::at(Vec3::new(1.0, 2.0, 3.0));
        t.ai = 0x81;
        t.speed = 50;
        t.roll = SignMagnitude(0x6F);
        let police = t.make(POLICE);
        assert_eq!(police.position, Vec3::new(1.0, 2.0, 3.0));
        assert_eq!((police.ai, police.speed, police.roll), (0x81, 50, SignMagnitude(0x6F)));
        assert_eq!((police.energy, police.missiles), (120, 2));
        assert_eq!(t.make(CANISTER).energy, 24);
    }

    #[test]
    fn the_alien_group_is_a_mothership_then_a_drone_at_one_place() {
        let mut bubble = Bubble::new();
        let mut random = MainGenerator::new();
        assert!(alien_group(&mut bubble, &mut random));
        let (m, d) = (bubble.get(0).unwrap(), bubble.get(1).unwrap());
        assert_eq!((m.kind, d.kind), (ALIEN_MOTHERSHIP, ALIEN_DRONE));
        assert_eq!((m.ai, d.ai), (0xFF, 0xFF));
        assert_eq!(m.position, Vec3::new(-8192.0, 8192.0, 8192.0));
        assert_eq!(d.position, m.position);
        assert_eq!(random, replay(MainGenerator::new(), "nc"), "two draws");
    }

    #[test]
    fn the_alien_group_reports_a_full_bubble() {
        let mut bubble = Bubble::new();
        for _ in 0..CAPACITY - 1 {
            bubble.add(Object::new(CANISTER, Vec3::ZERO));
        }
        let mut random = MainGenerator::new();
        assert!(!alien_group(&mut bubble, &mut random), "the drone has no room");
        assert_eq!(bubble.count_of(ALIEN_MOTHERSHIP), 1);
        assert!(!alien_group(&mut bubble, &mut random), "nothing has room");
        let expected = replay(MainGenerator::new(), "nc nc");
        assert_eq!(random, expected, "the draws are spent even when the adds fail");
    }

    #[test]
    fn launching_straight_ahead() {
        let missile = launch_straight_ahead(MISSILE, 5, 40);
        assert_eq!(missile.position, Vec3::new(0.0, -28.0, 14.0));
        assert_eq!(missile.nose, Vec3::new(0.0, 0.0, 1.0));
        assert_eq!(missile.side, Vec3::new(-1.0, 0.0, 0.0));
        assert_eq!(missile.roof, Vec3::new(0.0, 1.0, 0.0));
        assert_eq!(missile.ai, 0x80 | 10);
        assert_eq!(missile.speed, 80, "the next own-motion update clamps it");
        // The target slot is taken mod 32 and the speed mod 256.
        let hull = launch_straight_ahead(TRADER, 33, 200);
        assert_eq!((hull.ai, hull.speed), (0x82, 144));
    }

    #[test]
    fn children_copy_the_parent_and_leave_the_station_along_its_nose() {
        let mut parent = Object::new(TRADER, Vec3::new(100.0, 0.0, 500.0));
        parent.nose = Vec3::new(0.0, 0.0, 0.5);
        parent.speed = 20;
        parent.roll = SignMagnitude(0x85);
        parent.pitch = SignMagnitude(0x03);
        let pod = child_of(&parent, 13);
        assert_eq!(pod.position, parent.position);
        assert_eq!((pod.speed, pod.pitch, pod.roll), (20, SignMagnitude(0x03), SignMagnitude(0x84)));
        assert_eq!((pod.kind, pod.ai, pod.energy), (13, 0, 16));

        let mut station = Object::new(STATION, Vec3::new(0.0, 0.0, 1000.0));
        station.nose = Vec3::new(0.0, 0.0, -0.5);
        station.roll = SignMagnitude(0xFF);
        let police = child_of(&station, POLICE);
        assert_eq!(police.position, Vec3::new(0.0, 0.0, 904.0), "192 along the nose as stored");
        assert_eq!((police.speed, police.roll), (32, SignMagnitude(0xFE)));
    }
}
