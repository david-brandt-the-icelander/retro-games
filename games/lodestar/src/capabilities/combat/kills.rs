//! Kills, bounties and the legal status (RULES C.13, C.15). Combat rank is `Pilot::rank`
//! (RULES C.14).

use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::pilot::Pilot;
use crate::capabilities::ships::{self, TypeNumber};

/// The legal-status bit a finished police explosion sets (RULES C.15.2).
pub const POLICE_KILLED: u8 = 64;

/// Counts a kill (RULES C.13): the 16-bit tally rises by 1, wrapping at 65536, and every 256th
/// kill (the low byte becoming 0) shows the praise message. Returns true when it showed.
pub fn count_kill(pilot: &mut Pilot, cockpit: &mut Cockpit) -> bool {
    pilot.kills = pilot.kills.wrapping_add(1);
    let praise = pilot.kills & 0xFF == 0;
    if praise {
        cockpit.show(Message::KillPraise);
    }
    praise
}

/// Pays the bounty of a ship of `kind` whose explosion has finished (RULES C.13): only when no
/// message is showing and the player is not in mis-jump space. A non-zero bounty goes to cash and
/// shows the cash message, which holds back any other bounty due while it shows (that bounty is
/// lost, not deferred). Returns the tenths of a credit paid.
pub fn pay_bounty(pilot: &mut Pilot, cockpit: &mut Cockpit, kind: TypeNumber) -> u16 {
    if cockpit.message_showing() || cockpit.misjump {
        return 0;
    }
    let bounty = ships::stats(kind).map_or(0, |s| s.bounty);
    if bounty != 0 {
        pilot.cash += u64::from(bounty);
        cockpit.show(Message::Bounty { cash: pilot.cash });
    }
    bounty
}

/// Launching from the station: L ← L OR the contraband value (RULES C.15.2).
pub fn on_launch(pilot: &mut Pilot) {
    pilot.legal |= pilot.contraband();
}

/// A police interceptor's explosion has finished, however it was killed: L ← L OR 64
/// (RULES C.15.2).
pub fn on_police_exploded(pilot: &mut Pilot) {
    pilot.legal |= POLICE_KILLED;
}

/// Arriving by a normal hyperspace jump: L ← ⌊L / 2⌋. Returns the bit shifted out (L AND 1
/// before halving), which the arrival layout adds to the planet's placement value (RULES
/// C.15.2, B.10.1). A mis-jump arrival changes nothing and does not call this.
pub fn on_hyperspace_arrival(pilot: &mut Pilot) -> u8 {
    let shifted_out = pilot.legal & 1;
    pilot.legal >>= 1;
    shifted_out
}

/// Starting a galaxy-drive jump: L ← 0 (RULES C.15.2). The arrival then halves 0. A successful
/// escape pod clears it too, in `equipment::escape_pod_rescue`.
pub fn on_galaxy_jump(pilot: &mut Pilot) {
    pilot.legal = 0;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{ALIEN_MOTHERSHIP, ASTEROID, SMALL_PIRATE_A, TRADER};

    #[test]
    fn kills_wrap_and_every_256th_is_praised() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        pilot.kills = 254;
        assert!(!count_kill(&mut pilot, &mut cockpit));
        assert_eq!(cockpit.message, None);
        assert!(count_kill(&mut pilot, &mut cockpit));
        assert_eq!((pilot.kills, cockpit.message), (256, Some(Message::KillPraise)));
        pilot.kills = 65_535;
        cockpit = Cockpit::new();
        assert!(count_kill(&mut pilot, &mut cockpit));
        assert_eq!(pilot.kills, 0);
        assert_eq!(pilot.rank(), 0, "the tally wraps back to rank 0");
    }

    #[test]
    fn a_bounty_shows_the_new_cash() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        assert_eq!(pay_bounty(&mut pilot, &mut cockpit, SMALL_PIRATE_A), 60);
        assert_eq!(pilot.cash, 1_060);
        assert_eq!(cockpit.message, Some(Message::Bounty { cash: 1_060 }));
        assert_eq!(cockpit.message_timer, 22);
    }

    #[test]
    fn a_bounty_due_while_a_message_shows_is_lost() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        pay_bounty(&mut pilot, &mut cockpit, SMALL_PIRATE_A);
        assert_eq!(pay_bounty(&mut pilot, &mut cockpit, ALIEN_MOTHERSHIP), 0);
        assert_eq!(pilot.cash, 1_060, "the second bounty in the same tick is lost");
    }

    #[test]
    fn a_zero_bounty_shows_nothing_and_blocks_nothing() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        assert_eq!(pay_bounty(&mut pilot, &mut cockpit, TRADER), 0);
        assert_eq!(cockpit.message, None);
        assert_eq!(pay_bounty(&mut pilot, &mut cockpit, ASTEROID), 8);
        assert_eq!(pilot.cash, 1_008);
    }

    #[test]
    fn no_bounty_in_misjump_space() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        cockpit.misjump = true;
        assert_eq!(pay_bounty(&mut pilot, &mut cockpit, ALIEN_MOTHERSHIP), 0);
        assert_eq!((pilot.cash, cockpit.message), (1_000, None));
    }

    #[test]
    fn legal_status_changes() {
        let mut pilot = Pilot::start();
        pilot.cargo[3] = 2;
        pilot.cargo[10] = 1;
        pilot.legal = 0x10;
        on_launch(&mut pilot);
        assert_eq!(pilot.legal, 0x10 | 5);
        on_police_exploded(&mut pilot);
        assert_eq!(pilot.legal, 0x55);
        assert_eq!(on_hyperspace_arrival(&mut pilot), 1);
        assert_eq!(pilot.legal, 0x2A);
        assert_eq!(on_hyperspace_arrival(&mut pilot), 0);
        assert_eq!(pilot.legal, 0x15);
        on_galaxy_jump(&mut pilot);
        assert_eq!(pilot.legal, 0);
    }
}
