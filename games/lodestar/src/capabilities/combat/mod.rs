//! Combat: the player's lasers, missiles, E.C.M. and area blast, damage to the player, contact,
//! explosions, kills, bounties and the legal status (RULES C.4, C.6 to C.13, C.15), and the
//! combat steps of the slot loop (RULES C.4) for the flight tick to call.
//!
//! The ship AI is the `ai` capability; combat applies what a think returns. Combat rank is
//! `Pilot::rank`, the recharge `Cockpit::recharge`. The player's death, the escape pod, the
//! docking test, removal for distance and spawning are the caller's: the functions here return
//! what the caller must act on. Sounds are not built; the knowledge document `combat.md` lists
//! where each plays.

mod contact;
mod countermeasures;
mod damage;
mod explosion;
mod kills;
mod lasers;
mod missiles;
mod steps;

pub use contact::{
    contact, failed_docking, Contact, COLLISION_DAMAGE, CONTACT_BOX, DOCKING_BOX, FAILED_DOCKING_DAMAGE,
    FATAL_DOCKING_SPEED,
};
pub use countermeasures::{count_down_area_blast, fire_ecm, laser_and_ecm_bookkeeping, trigger_area_blast};
pub use damage::{lose_something, take_damage, Damage, Loss, FIRST_EQUIPMENT_ROLL, LOSS_ROLL_LIMIT};
pub use explosion::{advance_explosion, start_explosion, CLOUD_START, CLOUD_STEP};
pub use kills::{
    count_kill, on_galaxy_jump, on_hyperspace_arrival, on_launch, on_police_exploded, pay_bounty, POLICE_KILLED,
};
pub use lasers::{
    cool_down, fire_lasers, in_sights, laser_hit, mount_frame, start_key_handling, LaserHit, Shot, BEAM_BIT,
    COOLDOWN_STEP, HEAT_PER_SHOT, POWER_BITS, PULSE_COOLDOWN, SIGHTS_HALF_WIDTH,
};
pub use missiles::{
    arm_missile, fire_missile, fix_up_after_removal, fix_up_lock, try_lock, unarm_missile, MissileFired,
    LAUNCH_POSITION,
};
pub use steps::{
    ai_step, area_blast_step, explosion_progress_step, explosion_start_step, removal_step, sights_step, AiStep,
    Exploded, SightsStep,
};
