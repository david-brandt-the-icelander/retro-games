//! Spawning: where new objects are placed and when ships arrive by themselves (RULES B.10.3 to
//! B.10.8, C.16). The templates, the alien group, launches and children are placements other
//! features and the combat rules build on; the periodic spawn is the event the tick runs when
//! the main counter reaches 0. See `spawning.md`.

mod periodic;
mod template;

pub use periodic::{
    periodic_spawn, SpawnDelay, BENIGN_BELOW, BENIGN_Z, GOVERNMENT_STOP_FROM, PACK_FROM, ROCK_CAP,
};
pub use template::{
    alien_group, child_of, hostile_template, launch_straight_ahead, Template, ALIEN_AI, HOSTILE_AI,
    LAUNCH_POSITION, STATION_CHILD_OFFSET, STATION_CHILD_SPEED, TEMPLATE_DISTANCE,
};

/// Test help shared by the features that draw templates.
#[cfg(test)]
pub(crate) mod test_support {
    use crate::capabilities::random::MainGenerator;

    /// `from` after a run of draws: `n` an ordinary draw, `c` a carry-cleared one, any other
    /// character ignored. A hostile template is `nc`.
    pub(crate) fn replay(mut from: MainGenerator, pattern: &str) -> MainGenerator {
        for step in pattern.chars() {
            match step {
                'n' => {
                    from.draw();
                }
                'c' => {
                    from.draw_carry_cleared();
                }
                _ => {}
            }
        }
        from
    }
}
