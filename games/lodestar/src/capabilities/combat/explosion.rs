//! Explosions: how a killed ship starts to explode and how its cloud runs out (RULES C.12).

use crate::capabilities::bubble::Object;
use crate::capabilities::random::MainGenerator;
use crate::capabilities::space::SignMagnitude;

/// The cloud counter an explosion starts at.
pub const CLOUD_START: u8 = 18;
/// What the cloud counter gains each tick; past 255 the cloud is spent.
pub const CLOUD_STEP: u8 = 4;

/// Starts the explosion of a killed ship (RULES C.12 item 1): the killed and firing flags are
/// cleared and exploding set (the on-screen and on-scanner flags stay), acceleration 0, pitch
/// counter 0, cloud counter 18, and four bytes drawn as the cloud's seeds.
pub fn start_explosion(object: &mut Object, random: &mut MainGenerator) {
    object.flags.killed = false;
    object.flags.firing = false;
    object.flags.exploding = true;
    object.acceleration = 0;
    object.pitch = SignMagnitude::ZERO;
    object.explosion.counter = CLOUD_START;
    for seed in object.explosion.seeds.iter_mut() {
        *seed = random.byte();
    }
}

/// Advances an exploding object's cloud by one tick (RULES C.12 item 3): counter + 4; when that
/// passes 255 the object is marked killed (it is then removed with its bounty) and true is
/// returned. Does nothing to an object that is not exploding.
pub fn advance_explosion(object: &mut Object) -> bool {
    if !object.flags.exploding {
        return false;
    }
    match object.explosion.counter.checked_add(CLOUD_STEP) {
        Some(counter) => {
            object.explosion.counter = counter;
            false
        }
        None => {
            object.explosion.counter = object.explosion.counter.wrapping_add(CLOUD_STEP);
            object.flags.killed = true;
            true
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::SMALL_PIRATE_A;
    use crate::capabilities::space::Vec3;

    #[test]
    fn the_start_clears_killed_and_firing_and_draws_four_seeds() {
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.flags.killed = true;
        o.flags.firing = true;
        o.flags.on_screen = true;
        o.acceleration = 3;
        o.pitch = SignMagnitude::new(true, 3);
        o.roll = SignMagnitude::new(false, 9);
        o.speed = 20;
        let mut random = MainGenerator::new();
        start_explosion(&mut o, &mut random);
        assert!(o.flags.exploding && !o.flags.killed && !o.flags.firing && o.flags.on_screen);
        assert_eq!((o.acceleration, o.pitch, o.explosion.counter), (0, SignMagnitude::ZERO, 18));
        assert_eq!((o.roll, o.speed), (SignMagnitude::new(false, 9), 20), "it keeps moving and rolling");
        // The starting stream's first four bytes (RULES C.2.1, worked in the random tests).
        let mut expected = MainGenerator::new();
        let seeds = [expected.byte(), expected.byte(), expected.byte(), expected.byte()];
        assert_eq!(seeds[..2], [0xAC, 0xE1]);
        assert_eq!(o.explosion.seeds, seeds);
        assert_eq!(random, expected);
    }

    #[test]
    fn an_explosion_lasts_sixty_ticks_counting_the_start() {
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        o.flags.killed = true;
        start_explosion(&mut o, &mut MainGenerator::new());
        let mut ticks = 0;
        let mut counters = Vec::new();
        loop {
            ticks += 1;
            if advance_explosion(&mut o) {
                break;
            }
            counters.push(o.explosion.counter);
        }
        assert_eq!(ticks, 60);
        assert_eq!(counters.first(), Some(&22));
        assert_eq!(counters.last(), Some(&254));
        assert!(o.flags.killed && o.flags.exploding);
    }

    #[test]
    fn nothing_happens_to_an_object_not_exploding() {
        let mut o = Object::new(SMALL_PIRATE_A, Vec3::ZERO);
        assert!(!advance_explosion(&mut o));
        assert_eq!(o.explosion.counter, 0);
    }
}
