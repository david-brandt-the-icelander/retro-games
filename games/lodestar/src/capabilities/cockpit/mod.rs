//! The cockpit: the player's in-flight state that is not saved (RULES C.1, C.6–C.10, B.3.3,
//! B.14, B.15, D.3.13, D.9.1). The pilot capability holds what is saved; this holds what a
//! flight-state reset sets again.
//!
//! The values are the rules' own bytes, so the features that read and change them can follow
//! RULES line by line. Nothing here draws a random number except [`Cockpit::reset`], which takes
//! the main generator's view-independent stardust draws and discards them (deliberate
//! difference 3).

use crate::capabilities::flight::{Attitude, RESET_SPEED};
use crate::capabilities::pilot::Mount;
use crate::capabilities::random::MainGenerator;

/// Shields and energy after a reset (RULES C.10.1).
pub const FULL: u8 = 255;
/// Cabin temperature after a reset and away from the sun (RULES B.15.1).
pub const CABIN_COOL: u8 = 30;
/// Altitude when no planet is near (RULES B.14).
pub const ALTITUDE_FAR: u8 = 255;
/// Laser heat at or above which the laser does not fire (RULES C.6.2).
pub const LASER_TOO_HOT: u8 = 242;
/// Ticks a timed message shows for (RULES C.1, D.9.1).
pub const MESSAGE_TICKS: u8 = 22;
/// Ticks an E.C.M. pulse lasts (RULES C.8).
pub const ECM_TICKS: u8 = 32;
/// Ticks the area blast stays active (RULES C.9).
pub const AREA_BLAST_TICKS: u8 = 4;
/// Energy below which the low-energy warning shows (RULES C.10.1, D.9.1 M2).
pub const LOW_ENERGY: u8 = 50;
/// Main-generator draws a flight-state reset makes for the stardust, discarded (RULES B.4.2,
/// deliberate difference 3): 18 particles × 3.
pub const RESET_DUST_DRAWS: usize = 54;

/// A timed in-flight message (RULES D.9.1). The wording is the presentation's; the sim says
/// only which message and its data.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Message {
    /// M1: scooping fuel from the sun.
    FuelScooping,
    /// M2: energy low.
    EnergyLow,
    /// M3: every 256th kill.
    KillPraise,
    /// M4: a ship launched a missile at the player.
    IncomingMissile,
    /// M5: a missile could not launch, the bubble is full.
    MissileJammed,
    /// M6: the locked target left the bubble.
    TargetLost,
    /// M7: the galactic jump started.
    GalacticJump,
    /// M8: a bounty was paid; shows the new cash.
    Bounty { cash: u64 },
    /// M9: a goods item was scooped.
    Scooped { item: usize },
    /// M10: a goods item was destroyed.
    CargoLost { item: usize },
    /// M11: fitted equipment was destroyed (RULES C.10.3: X = 17..21).
    EquipmentLost { roll: u8 },
}

/// The missile control's state (RULES C.7.1).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct MissileLock {
    /// Armed and searching for a target.
    pub armed: bool,
    /// The bubble slot the lock is on.
    pub target: Option<usize>,
}

impl MissileLock {
    /// Clears the lock and the arming.
    pub fn clear(&mut self) {
        *self = Self::default();
    }

    /// Follows the removal of the object in `slot` (RULES C.7.4): a lock on it is dropped and
    /// `true` returned (the target-lost message is the caller's); a lock on a later slot moves
    /// down one.
    pub fn on_removed(&mut self, slot: usize) -> bool {
        match self.target {
            Some(t) if t == slot => {
                self.clear();
                true
            }
            Some(t) if t > slot => {
                self.target = Some(t - 1);
                false
            }
            _ => false,
        }
    }
}

/// The player's in-flight state.
#[derive(Clone, Debug, PartialEq)]
pub struct Cockpit {
    /// Energy bank, 0..255.
    pub energy: u8,
    pub fore_shield: u8,
    pub aft_shield: u8,
    /// Cabin temperature, 30..255 (RULES B.15.1).
    pub cabin_temperature: u8,
    /// Laser heat, 0..255 (RULES C.6.2).
    pub laser_temperature: u8,
    /// Laser cooldown: 10 after a pulse shot, falling by 5 a tick (RULES C.6.2).
    pub laser_cooldown: u8,
    /// This tick's shot damage: 15 when the laser fired, else 0 (RULES C.6.2).
    pub shot_damage: u8,
    /// Altitude above the planet, 255 when far (RULES B.14).
    pub altitude: u8,
    /// The player's speed S (RULES B.6).
    pub speed: u8,
    pub attitude: Attitude,
    /// The mount the lasers and the missile lock use (deliberate difference 8).
    pub active_mount: Mount,
    pub missile: MissileLock,
    /// The bubble's single E.C.M. pulse timer (RULES C.8).
    pub ecm_timer: u8,
    /// The player's own E.C.M. is on (RULES C.8).
    pub ecm_own: bool,
    /// Ticks the area blast stays active (RULES C.9).
    pub area_blast: u8,
    /// The station is present: the safe zone (RULES B.11).
    pub station_present: bool,
    /// In mis-jump space (the ambush state; RULES B.16.5, C.16.6).
    pub misjump: bool,
    /// The main counter C (F in RULES C), read before this tick's decrement (RULES B.3.3).
    pub counter: u8,
    /// Ticks the current message has left; 0 means none showing (RULES D.9.1).
    pub message_timer: u8,
    pub message: Option<Message>,
}

impl Default for Cockpit {
    fn default() -> Self {
        Self::new()
    }
}

impl Cockpit {
    /// The state a flight-state reset leaves (RULES D.3.13), with the front mount active.
    pub fn new() -> Self {
        Self {
            energy: FULL,
            fore_shield: FULL,
            aft_shield: FULL,
            cabin_temperature: CABIN_COOL,
            laser_temperature: 0,
            laser_cooldown: 0,
            shot_damage: 0,
            altitude: ALTITUDE_FAR,
            speed: RESET_SPEED,
            attitude: Attitude::new(),
            active_mount: 0,
            missile: MissileLock::default(),
            ecm_timer: 0,
            ecm_own: false,
            area_blast: 0,
            station_present: false,
            misjump: false,
            counter: 0,
            message_timer: 0,
            message: None,
        }
    }

    /// The flight-state reset (RULES D.3.13): everything above back to its start, keeping the
    /// active mount, and the 54 stardust draws taken from the main generator and discarded. The
    /// caller empties the bubble; the hyperspace countdown is not touched.
    pub fn reset(&mut self, random: &mut MainGenerator) {
        let mount = self.active_mount;
        *self = Self::new();
        self.active_mount = mount;
        random.discard(RESET_DUST_DRAWS);
    }

    /// Takes 1 from the energy, never below 1 (RULES C.10.1). Returns false when the energy was
    /// already 1 and so did not fall (the E.C.M. stops on this, RULES C.8).
    pub fn drain_energy(&mut self) -> bool {
        if self.energy > 1 {
            self.energy -= 1;
            true
        } else {
            self.energy = self.energy.max(1);
            false
        }
    }

    /// True on the ticks shields and energy recharge: C mod 8 = 0 (RULES B.3.3 step 4).
    pub fn recharge_due(&self) -> bool {
        self.counter % 8 == 0
    }

    /// One recharge (RULES C.10.1): with energy ≥ 128, the aft then the fore shield rise by 1
    /// each, draining 1 energy each; then energy rises by 1, or 2 with the booster, up to 255.
    pub fn recharge(&mut self, energy_booster: bool) {
        if self.energy >= 128 {
            if self.aft_shield < FULL {
                self.aft_shield += 1;
                self.drain_energy();
            }
            if self.fore_shield < FULL {
                self.fore_shield += 1;
                self.drain_energy();
            }
        }
        let gain = if energy_booster { 2 } else { 1 };
        self.energy = self.energy.saturating_add(gain);
    }

    /// Shows a timed message, replacing any current one (RULES D.9.1).
    pub fn show(&mut self, message: Message) {
        self.message = Some(message);
        self.message_timer = MESSAGE_TICKS;
    }

    /// True while a timed message is showing (several rules hold back while it is).
    pub fn message_showing(&self) -> bool {
        self.message_timer > 0
    }

    /// Counts the message timer down once; the message clears when it reaches 0 (RULES D.9.1).
    pub fn count_down_message(&mut self) {
        if self.message_timer > 0 {
            self.message_timer -= 1;
            if self.message_timer == 0 {
                self.message = None;
            }
        }
    }

    /// C ← (C − 1) mod 256 (RULES B.3.3 step 8). Returns true when C is now 0 (periodic
    /// spawning is due if not dying).
    pub fn count_down_counter(&mut self) -> bool {
        self.counter = self.counter.wrapping_sub(1);
        self.counter == 0
    }

    /// Laser heat cools by 1 if above 0 (RULES B.3.3 step 8, C.6.2; flight and docked).
    pub fn cool_laser(&mut self) {
        self.laser_temperature = self.laser_temperature.saturating_sub(1);
    }

    /// Starts an E.C.M. pulse, or restarts a running one (RULES C.8). The player flag is set
    /// only by the player's own E.C.M., and only when no pulse was running.
    pub fn start_ecm(&mut self, own: bool) {
        if own && self.ecm_timer == 0 {
            self.ecm_own = true;
        }
        self.ecm_timer = ECM_TICKS;
    }

    /// Stops the E.C.M. pulse (RULES C.8).
    pub fn stop_ecm(&mut self) {
        self.ecm_timer = 0;
        self.ecm_own = false;
    }

    /// True while an E.C.M. pulse is active.
    pub fn ecm_active(&self) -> bool {
        self.ecm_timer > 0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_reset_sets_the_rules_values_and_keeps_the_mount() {
        let mut c = Cockpit::new();
        c.energy = 9;
        c.speed = 40;
        c.active_mount = 2;
        c.counter = 77;
        c.missile.target = Some(4);
        c.show(Message::EnergyLow);
        let mut random = MainGenerator::new();
        let mut expected = MainGenerator::new();
        expected.discard(54);
        c.reset(&mut random);
        assert_eq!(random, expected, "54 draws taken and discarded");
        assert_eq!((c.energy, c.fore_shield, c.aft_shield), (255, 255, 255));
        assert_eq!((c.speed, c.counter, c.altitude, c.cabin_temperature), (3, 0, 255, 30));
        assert_eq!(c.missile, MissileLock::default());
        assert_eq!((c.message, c.message_timer), (None, 0));
        assert_eq!(c.active_mount, 2);
    }

    #[test]
    fn energy_drains_to_a_floor_of_one() {
        let mut c = Cockpit::new();
        c.energy = 2;
        assert!(c.drain_energy());
        assert_eq!(c.energy, 1);
        assert!(!c.drain_energy());
        assert_eq!(c.energy, 1);
    }

    #[test]
    fn recharge_feeds_the_aft_shield_first() {
        let mut c = Cockpit::new();
        c.energy = 200;
        c.aft_shield = 10;
        c.fore_shield = 10;
        c.recharge(false);
        assert_eq!((c.aft_shield, c.fore_shield, c.energy), (11, 11, 199));
        c.recharge(true);
        assert_eq!((c.aft_shield, c.fore_shield, c.energy), (12, 12, 199));
        // Below 128 the shields get nothing.
        c.energy = 127;
        c.recharge(false);
        assert_eq!((c.aft_shield, c.energy), (12, 128));
        // Full shields cost nothing; energy caps at 255.
        c.aft_shield = 255;
        c.fore_shield = 255;
        c.energy = 254;
        c.recharge(true);
        assert_eq!(c.energy, 255);
    }

    #[test]
    fn the_counter_wraps_and_says_when_it_reaches_zero() {
        let mut c = Cockpit::new();
        assert!(c.recharge_due());
        assert!(!c.count_down_counter());
        assert_eq!(c.counter, 255);
        let mut zeros = 0;
        for _ in 0..255 {
            if c.count_down_counter() {
                zeros += 1;
            }
        }
        assert_eq!((c.counter, zeros), (0, 1), "the first spawn is on the 256th tick");
    }

    #[test]
    fn messages_last_twenty_two_ticks() {
        let mut c = Cockpit::new();
        c.show(Message::MissileJammed);
        for _ in 0..21 {
            c.count_down_message();
        }
        assert!(c.message_showing());
        c.count_down_message();
        assert!(!c.message_showing());
        assert_eq!(c.message, None);
    }

    #[test]
    fn ecm_restarts_without_changing_the_player_flag() {
        let mut c = Cockpit::new();
        c.start_ecm(false);
        c.start_ecm(true);
        assert!(!c.ecm_own, "a running pulse keeps the flag");
        assert_eq!(c.ecm_timer, 32);
        c.stop_ecm();
        c.start_ecm(true);
        assert!(c.ecm_own && c.ecm_active());
    }

    #[test]
    fn a_lock_follows_removals() {
        let mut lock = MissileLock { armed: false, target: Some(5) };
        assert!(!lock.on_removed(7));
        assert_eq!(lock.target, Some(5));
        assert!(!lock.on_removed(2));
        assert_eq!(lock.target, Some(4));
        assert!(lock.on_removed(4));
        assert_eq!(lock, MissileLock::default());
    }
}
