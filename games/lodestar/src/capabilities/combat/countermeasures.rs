//! The player's E.C.M. (RULES C.8) and the area blast (RULES C.9), and the end-of-tick laser and
//! E.C.M. bookkeeping (RULES D.3.6 step 7).

use crate::capabilities::cockpit::{Cockpit, AREA_BLAST_TICKS};
use crate::capabilities::combat::lasers::cool_down;
use crate::capabilities::pilot::Pilot;

/// The E.C.M. action (RULES C.8, D.4.2): with the unit fitted and no pulse running (ours or a
/// ship's), the player's own E.C.M. starts a 32-tick pulse. Returns whether it started.
pub fn fire_ecm(pilot: &Pilot, cockpit: &mut Cockpit) -> bool {
    let start = pilot.fitted.ecm && !cockpit.ecm_active();
    if start {
        cockpit.start_ecm(true);
    }
    start
}

/// The area-blast action (RULES C.9): if fitted, it is used up and the blast is active for this
/// tick and the next three. Returns whether it fired.
pub fn trigger_area_blast(pilot: &mut Pilot, cockpit: &mut Cockpit) -> bool {
    let fire = pilot.fitted.area_blast;
    if fire {
        pilot.fitted.area_blast = false;
        cockpit.area_blast = AREA_BLAST_TICKS;
    }
    fire
}

/// After the slot loop (RULES C.9, D.3.6 step 4): the area blast's counter falls by 1 if above 0.
pub fn count_down_area_blast(cockpit: &mut Cockpit) {
    cockpit.area_blast = cockpit.area_blast.saturating_sub(1);
}

/// The end-of-tick laser and E.C.M. bookkeeping (RULES C.6.2, C.8, D.3.6 step 7): the laser
/// cooldown falls by 5; with the player's own E.C.M. on, 1 energy is drained and, if the energy
/// was already at its floor of 1, the pulse stops at once; then a running pulse counts down and
/// stops at 0. Returns true when the pulse stopped this tick (the E.C.M.-off sound).
pub fn laser_and_ecm_bookkeeping(cockpit: &mut Cockpit) -> bool {
    cool_down(cockpit);
    if cockpit.ecm_own && !cockpit.drain_energy() {
        cockpit.stop_ecm();
        return true;
    }
    if cockpit.ecm_timer > 0 {
        cockpit.ecm_timer -= 1;
        if cockpit.ecm_timer == 0 {
            cockpit.stop_ecm();
            return true;
        }
    }
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_players_ecm_needs_the_unit_and_a_quiet_bubble() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        assert!(!fire_ecm(&pilot, &mut cockpit));
        pilot.fitted.ecm = true;
        cockpit.start_ecm(false);
        assert!(!fire_ecm(&pilot, &mut cockpit), "a ship's pulse is running");
        assert!(!cockpit.ecm_own);
        cockpit.stop_ecm();
        assert!(fire_ecm(&pilot, &mut cockpit));
        assert!(cockpit.ecm_own && cockpit.ecm_timer == 32);
    }

    #[test]
    fn a_pulse_is_active_for_32_ticks_of_ai_and_drains_32_energy() {
        let mut pilot = Pilot::start();
        pilot.fitted.ecm = true;
        let mut cockpit = Cockpit::new();
        fire_ecm(&pilot, &mut cockpit);
        let mut active_ticks = 0;
        let mut stopped_at = None;
        for tick in 0..40 {
            if cockpit.ecm_active() {
                active_ticks += 1;
            }
            if laser_and_ecm_bookkeeping(&mut cockpit) {
                stopped_at = Some(tick);
            }
        }
        assert_eq!(active_ticks, 32);
        assert_eq!(stopped_at, Some(31));
        assert_eq!(cockpit.energy, 255 - 32);
        assert!(!cockpit.ecm_own);
    }

    #[test]
    fn the_players_ecm_stops_when_energy_is_at_its_floor() {
        let mut pilot = Pilot::start();
        pilot.fitted.ecm = true;
        let mut cockpit = Cockpit::new();
        cockpit.energy = 2;
        fire_ecm(&pilot, &mut cockpit);
        assert!(!laser_and_ecm_bookkeeping(&mut cockpit));
        assert_eq!((cockpit.energy, cockpit.ecm_timer), (1, 31));
        assert!(laser_and_ecm_bookkeeping(&mut cockpit));
        assert_eq!((cockpit.energy, cockpit.ecm_timer, cockpit.ecm_own), (1, 0, false));
    }

    #[test]
    fn a_ships_pulse_drains_nothing() {
        let mut cockpit = Cockpit::new();
        cockpit.start_ecm(false);
        laser_and_ecm_bookkeeping(&mut cockpit);
        assert_eq!((cockpit.energy, cockpit.ecm_timer), (255, 31));
    }

    #[test]
    fn the_cooldown_falls_by_five_to_zero() {
        let mut cockpit = Cockpit::new();
        cockpit.laser_cooldown = 7;
        laser_and_ecm_bookkeeping(&mut cockpit);
        assert_eq!(cockpit.laser_cooldown, 2);
        laser_and_ecm_bookkeeping(&mut cockpit);
        assert_eq!(cockpit.laser_cooldown, 0);
    }

    #[test]
    fn the_area_blast_is_used_up_and_lasts_four_ticks() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        assert!(!trigger_area_blast(&mut pilot, &mut cockpit));
        pilot.fitted.area_blast = true;
        assert!(trigger_area_blast(&mut pilot, &mut cockpit));
        assert!(!pilot.fitted.area_blast);
        let mut active = 0;
        for _ in 0..6 {
            if cockpit.area_blast > 0 {
                active += 1;
            }
            count_down_area_blast(&mut cockpit);
        }
        assert_eq!((active, cockpit.area_blast), (4, 0));
    }
}
