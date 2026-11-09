//! How objects move: the half-tick substep every object takes (RULES B.7.2) and the per-tick
//! update of an object's own speed and turn counters (RULES B.7.3, C.1).

use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::ships::{self, SUN};
use crate::capabilities::space::{SignMagnitude, Vec3};

/// The substep length in ticks: motion runs in two half-tick substeps per tick.
pub const H: f64 = 0.5;
/// Sim units an object moves along its nose per tick for each unit of its own speed.
pub const OWN_SPEED_FACTOR: f64 = 1.5;

/// Moves every object in the bubble by half a tick, in slot order, with the player's roll angle
/// ρ, pitch angle φ (radians per tick, RULES B.5.3) and speed S.
pub fn move_substep(bubble: &mut Bubble, roll_angle: f64, pitch_angle: f64, player_speed: u8) {
    for object in bubble.iter_mut() {
        move_object(object, roll_angle, pitch_angle, player_speed);
    }
}

/// Moves one object by half a tick (RULES B.7.2): its own translation along its nose as stored
/// (not for bodies), the player's rotation and translation of its position, then (not for the
/// sun) the player's rotation of its three orientation vectors and its own pitch and roll.
pub fn move_object(object: &mut Object, roll_angle: f64, pitch_angle: f64, player_speed: u8) {
    if !object.is_body() {
        object.position += object.nose * (OWN_SPEED_FACTOR * f64::from(object.speed) * H);
    }
    let roll = roll_angle * H;
    let pitch = pitch_angle * H;

    let p = &mut object.position;
    let k = p.y - roll * p.x;
    p.z += pitch * k;
    p.y = k - pitch * p.z;
    p.x += roll * p.y;
    p.z -= f64::from(player_speed) * H;

    if object.kind == SUN {
        return;
    }

    for v in [&mut object.nose, &mut object.roof, &mut object.side] {
        v.y -= roll * v.x;
        v.x += roll * v.y;
        v.y -= pitch * v.z;
        v.z += pitch * v.y;
    }

    if object.pitch.magnitude() != 0 {
        turn_pair(&mut object.roof, &mut object.nose, object.pitch);
    }
    if object.roll.magnitude() != 0 {
        turn_pair(&mut object.roof, &mut object.side, object.roll);
    }
}

/// The own-rotation step on a pair (a, b), both from their old values:
/// a' = a·(1 − h/512) + σ·(h/16)·b and b' = b·(1 − h/512) − σ·(h/16)·a, with σ the counter's
/// sign. It does not preserve length (RULES B.23 Q-B1).
fn turn_pair(a: &mut Vec3, b: &mut Vec3, counter: SignMagnitude) {
    let keep = 1.0 - H / 512.0;
    let swing = counter.sign() * (H / 16.0);
    let (old_a, old_b) = (*a, *b);
    *a = old_a * keep + old_b * swing;
    *b = old_b * keep - old_a * swing;
}

/// The per-tick own-motion update (RULES B.7.3): speed += acceleration read as a signed byte,
/// clamped to 0..the type's top speed, acceleration cleared; then the pitch and roll counters
/// decay (magnitudes 0 and 127 stay). Bodies are left alone.
pub fn own_motion_tick(object: &mut Object) {
    if object.is_body() {
        return;
    }
    let speed = i16::from(object.speed) + i16::from(object.acceleration as i8);
    object.speed = speed.clamp(0, i16::from(ships::top_speed(object.kind))) as u8;
    object.acceleration = 0;
    object.pitch.decay();
    object.roll.decay();
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{ASTEROID, CANISTER, MISSILE, PLANET_A, PLANET_B, SMALL_PIRATE_A, STATION};

    const RHO: f64 = 16.0 / 256.0;
    const PHI: f64 = -8.0 / 256.0;

    fn ship_at(kind: u8, position: Vec3) -> Object {
        Object::new(kind, position)
    }

    #[test]
    fn player_rotation_and_translation_of_a_position() {
        // ρ' = 1/32, φ' = −1/64, S = 10:
        // k = 64 − 32/32 = 63; z = 128 − 63/64 = 127.015625;
        // y = 63 + 127.015625/64 = 266177/4096; x = 32 + y/32 = 4460481/131072;
        // z − 5 = 122.015625 = 7809/64.
        let mut o = ship_at(CANISTER, Vec3::new(32.0, 64.0, 128.0));
        move_object(&mut o, RHO, PHI, 10);
        assert_eq!(o.position, Vec3::new(4_460_481.0 / 131_072.0, 266_177.0 / 4096.0, 7809.0 / 64.0));
    }

    #[test]
    fn player_rotation_of_the_orientation_vectors() {
        // Each vector: y −= ρ'x; x += ρ'y; y −= φ'z; z += φ'y, with ρ' = 1/32, φ' = −1/64.
        let mut o = ship_at(CANISTER, Vec3::ZERO);
        move_object(&mut o, RHO, PHI, 0);
        assert_eq!(o.side, Vec3::new(1023.0 / 1024.0, -1.0 / 32.0, 1.0 / 2048.0));
        assert_eq!(o.roof, Vec3::new(1.0 / 32.0, 1.0, -1.0 / 64.0));
        assert_eq!(o.nose, Vec3::new(0.0, -1.0 / 64.0, -4095.0 / 4096.0));
    }

    #[test]
    fn own_translation_uses_the_nose_as_stored() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 100.0));
        o.speed = 20;
        move_object(&mut o, 0.0, 0.0, 0);
        assert_eq!(o.position, Vec3::new(0.0, 0.0, 85.0), "1.5 × 20 × ½ along (0, 0, −1)");
        o.nose = Vec3::new(0.5, 0.0, 0.0);
        move_object(&mut o, 0.0, 0.0, 0);
        assert_eq!(o.position, Vec3::new(7.5, 0.0, 85.0), "a half-length nose moves half as far");
    }

    #[test]
    fn a_tick_moves_one_and_a_half_speed_along_the_nose_and_the_player_speed_back() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, 100.0));
        o.speed = 10;
        o.nose = Vec3::new(0.0, 0.0, 1.0);
        move_object(&mut o, 0.0, 0.0, 4);
        move_object(&mut o, 0.0, 0.0, 4);
        assert_eq!(o.position, Vec3::new(0.0, 0.0, 111.0), "+15 own, −4 player");
    }

    #[test]
    fn own_pitch_then_roll_on_the_default_frame() {
        // Pitch +: roof' = (0, 1023/1024, −1/32), nose' = (0, −1/32, −1023/1024).
        // Roll − on (roof', side): roof'' = roof'·1023/1024 − side/32, side' = side·1023/1024 + roof'/32.
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        o.pitch = SignMagnitude::new(false, 5);
        o.roll = SignMagnitude::new(true, 5);
        move_object(&mut o, 0.0, 0.0, 0);
        assert_eq!(o.nose, Vec3::new(0.0, -1.0 / 32.0, -1023.0 / 1024.0));
        assert_eq!(o.roof, Vec3::new(-1.0 / 32.0, 1_046_529.0 / 1_048_576.0, -1023.0 / 32768.0));
        assert_eq!(o.side, Vec3::new(1023.0 / 1024.0, 1023.0 / 32768.0, -1.0 / 1024.0));
    }

    #[test]
    fn a_negative_pitch_counter_swings_the_nose_toward_the_roof() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        o.pitch = SignMagnitude::new(true, 1);
        move_object(&mut o, 0.0, 0.0, 0);
        assert_eq!(o.nose, Vec3::new(0.0, 1.0 / 32.0, -1023.0 / 1024.0));
        assert_eq!(o.roof, Vec3::new(0.0, 1023.0 / 1024.0, 1.0 / 32.0));
        assert_eq!(o.side, Vec3::new(1.0, 0.0, 0.0), "no roll counter, no roll");
    }

    #[test]
    fn the_turn_rate_does_not_depend_on_the_magnitude() {
        let mut slow = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        let mut fast = slow;
        slow.roll = SignMagnitude::new(false, 1);
        fast.roll = SignMagnitude::new(false, 127);
        move_object(&mut slow, 0.0, 0.0, 0);
        move_object(&mut fast, 0.0, 0.0, 0);
        assert_eq!(slow.roof, fast.roof);
        assert_eq!(slow.side, fast.side);
    }

    #[test]
    fn own_rotation_shrinks_vectors() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        o.pitch = SignMagnitude::new(false, 127);
        move_object(&mut o, 0.0, 0.0, 0);
        let factor = ((1023.0f64 / 1024.0).powi(2) + (1.0f64 / 32.0).powi(2)).sqrt();
        assert_eq!(o.nose.length(), factor);
        assert!((factor - 0.99951).abs() < 0.000_01);
    }

    #[test]
    fn the_sun_moves_with_the_player_but_never_turns() {
        let mut sun = ship_at(SUN, Vec3::new(32.0, 64.0, 128.0));
        sun.speed = 30;
        sun.pitch = SignMagnitude::new(false, 127);
        sun.roll = SignMagnitude::new(false, 127);
        let before = sun;
        move_object(&mut sun, RHO, PHI, 10);
        assert_eq!(sun.position, Vec3::new(4_460_481.0 / 131_072.0, 266_177.0 / 4096.0, 7809.0 / 64.0));
        assert_eq!((sun.nose, sun.roof, sun.side), (before.nose, before.roof, before.side));
    }

    #[test]
    fn planets_spin_but_never_translate_on_their_own() {
        for kind in [PLANET_A, PLANET_B] {
            let mut planet = ship_at(kind, Vec3::new(0.0, 0.0, 1000.0));
            planet.speed = 30;
            planet.pitch = SignMagnitude::new(false, 127);
            planet.roll = SignMagnitude::new(false, 127);
            move_object(&mut planet, 0.0, 0.0, 2);
            assert_eq!(planet.position, Vec3::new(0.0, 0.0, 999.0), "only the player's speed");
            assert_eq!(planet.nose, Vec3::new(0.0, -1.0 / 32.0, -1023.0 / 1024.0), "it pitches");
            assert_ne!(planet.side, Vec3::new(1.0, 0.0, 0.0), "and rolls");
        }
    }

    #[test]
    fn a_substep_moves_every_object_in_the_bubble() {
        let mut bubble = Bubble::new();
        bubble.add(ship_at(PLANET_A, Vec3::new(0.0, 0.0, 1000.0)));
        bubble.add(ship_at(SUN, Vec3::new(0.0, 0.0, -1000.0)));
        bubble.add(ship_at(ASTEROID, Vec3::new(10.0, 0.0, 0.0)));
        move_substep(&mut bubble, 0.0, 0.0, 8);
        let zs: Vec<f64> = bubble.iter().map(|o| o.position.z).collect();
        assert_eq!(zs, vec![996.0, -1004.0, -4.0]);
    }

    #[test]
    fn acceleration_is_a_signed_byte_and_speed_clamps_to_the_type() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        o.speed = 20;
        o.acceleration = 255;
        own_motion_tick(&mut o);
        assert_eq!((o.speed, o.acceleration), (19, 0), "255 reads as −1 and is cleared");
        o.acceleration = 254;
        own_motion_tick(&mut o);
        assert_eq!(o.speed, 17);
        o.acceleration = 128;
        own_motion_tick(&mut o);
        assert_eq!(o.speed, 0, "−128 clamps at 0");
        o.acceleration = 127;
        own_motion_tick(&mut o);
        assert_eq!(o.speed, 36, "clamps at the type's top speed");
        o.acceleration = 0;
        own_motion_tick(&mut o);
        assert_eq!(o.speed, 36);
    }

    #[test]
    fn a_spawned_speed_above_the_top_lasts_one_tick() {
        let mut missile = ship_at(MISSILE, Vec3::ZERO);
        missile.speed = 60;
        own_motion_tick(&mut missile);
        assert_eq!(missile.speed, 42);
        let mut station = ship_at(STATION, Vec3::ZERO);
        station.speed = 5;
        own_motion_tick(&mut station);
        assert_eq!(station.speed, 0, "top speed 0");
        let mut unknown = ship_at(99, Vec3::ZERO);
        unknown.speed = 5;
        own_motion_tick(&mut unknown);
        assert_eq!(unknown.speed, 0, "no top speed clamps to 0");
    }

    #[test]
    fn counters_decay_keeping_their_sign_and_127_is_permanent() {
        let mut o = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        o.pitch = SignMagnitude::new(true, 2);
        o.roll = SignMagnitude::new(false, 127);
        own_motion_tick(&mut o);
        assert_eq!(o.pitch, SignMagnitude::new(true, 1));
        own_motion_tick(&mut o);
        assert_eq!(o.pitch.magnitude(), 0);
        own_motion_tick(&mut o);
        assert_eq!(o.pitch.magnitude(), 0, "0 stays 0");
        assert_eq!(o.roll, SignMagnitude::new(false, 127));
        let mut negative_forever = ship_at(SMALL_PIRATE_A, Vec3::ZERO);
        negative_forever.roll = SignMagnitude::new(true, 127);
        own_motion_tick(&mut negative_forever);
        assert_eq!(negative_forever.roll, SignMagnitude::new(true, 127));
    }

    #[test]
    fn bodies_take_no_own_motion_update() {
        for kind in [PLANET_A, SUN, PLANET_B] {
            let mut body = ship_at(kind, Vec3::ZERO);
            body.speed = 9;
            body.acceleration = 3;
            body.pitch = SignMagnitude::new(false, 5);
            let before = body;
            own_motion_tick(&mut body);
            assert_eq!(body, before, "type {kind}");
        }
    }
}
