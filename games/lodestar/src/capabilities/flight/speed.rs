//! The player's speed S: sim units moved forward per tick (RULES B.6).

use super::HeldControls;

/// The fastest the speed keys take the player.
pub const MAX_SPEED: u8 = 40;
/// The slowest the speed keys take the player.
pub const MIN_KEY_SPEED: u8 = 1;
/// The speed every flight-state reset sets, so a hyperspace arrival starts at it.
pub const RESET_SPEED: u8 = 3;
/// The speed a launch from the station sets.
pub const LAUNCH_SPEED: u8 = 12;
/// The speed a failed slow docking sets (RULES B.12.2).
pub const FAILED_DOCKING_SPEED: u8 = 1;
/// The speed during death.
pub const DEATH_SPEED: u8 = 0;

/// Applies the held speed keys for one tick: speed-up adds 1 below 40, then slow-down takes 1
/// above 1.
pub fn apply_speed_keys(speed: u8, held: HeldControls) -> u8 {
    let mut s = speed;
    if held.speed_up && s < MAX_SPEED {
        s += 1;
    }
    if held.slow_down && s > MIN_KEY_SPEED {
        s -= 1;
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    const UP: HeldControls = HeldControls { speed_up: true, ..HeldControls::NONE };
    const DOWN: HeldControls = HeldControls { slow_down: true, ..HeldControls::NONE };
    const BOTH: HeldControls = HeldControls { speed_up: true, slow_down: true, ..HeldControls::NONE };

    #[test]
    fn keys_change_speed_by_one_within_one_to_forty() {
        assert_eq!(apply_speed_keys(3, UP), 4);
        assert_eq!(apply_speed_keys(40, UP), 40);
        assert_eq!(apply_speed_keys(3, DOWN), 2);
        assert_eq!(apply_speed_keys(1, DOWN), 1);
        assert_eq!(apply_speed_keys(12, HeldControls::NONE), 12);
        let mut s = RESET_SPEED;
        for _ in 0..100 {
            s = apply_speed_keys(s, UP);
        }
        assert_eq!(s, MAX_SPEED);
    }

    #[test]
    fn both_keys_cancel_except_at_the_limits() {
        assert_eq!(apply_speed_keys(20, BOTH), 20);
        assert_eq!(apply_speed_keys(40, BOTH), 39, "no rise at 40, then down");
        assert_eq!(apply_speed_keys(1, BOTH), 1, "up to 2, then back to 1");
    }
}
