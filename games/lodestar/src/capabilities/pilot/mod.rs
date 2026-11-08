//! The pilot: everything about the player that is saved (RULES A.7), and the values derived from
//! it. Start values are the GDD's (§ 5.4).

/// Number of goods items (RULES A.9).
pub const GOODS: usize = 17;

/// A laser mount: 0 front, 1 rear, 2 left, 3 right (LodeStar labels them 1..4).
pub type Mount = usize;

/// Laser values (RULES A.7.1): bits 0..6 the power, bit 7 set for the beam laser.
pub const NO_LASER: u8 = 0;
pub const PULSE_LASER: u8 = 15;
pub const BEAM_LASER: u8 = 143;

/// The most missiles the pilot can carry.
pub const MAX_MISSILES: u8 = 4;
/// A full tank, in tenths of a light year.
pub const FULL_TANK: u8 = 70;
/// The hold without and with the hold extension, in tonnes (RULES A.11, decision 10).
pub const HOLD: u8 = 22;
pub const HOLD_EXTENDED: u8 = 37;

/// Galaxy 0's generator state for the start pilot (GDD § 5.4): three 16-bit words.
pub const START_GALAXY: [u16; 3] = [0x5D38, 0x3CAC, 0x0E31];
/// The start pilot's position: system 0 of the first galaxy (GDD § 5.4).
pub const START_POSITION: (u8, u8) = (60, 93);
/// The start pilot's default name (GDD § 5.4).
pub const START_NAME: &str = "DRIFTER";

/// Fitted equipment that is either there or not.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Fitted {
    pub ecm: bool,
    pub fuel_scoop: bool,
    pub area_blast: bool,
    pub energy_booster: bool,
    pub auto_dock: bool,
    pub galaxy_drive: bool,
    pub escape_pod: bool,
}

/// Legal standing derived from the legal status byte (RULES A.7.2).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LegalLabel {
    Clean,
    Offender,
    Fugitive,
}

/// The pilot's saved state (RULES A.7.1).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pilot {
    /// 1..7 characters, A–Z and 0–9.
    pub name: String,
    /// The current system's chart position.
    pub position: (u8, u8),
    /// The current galaxy's system-0 generator state.
    pub galaxy_state: [u16; 3],
    /// Galaxy number 0..7.
    pub galaxy: u8,
    /// Cash in tenths of a credit.
    pub cash: u64,
    /// Fuel in tenths of a light year, 0..70.
    pub fuel: u8,
    /// The laser on each mount.
    pub lasers: [u8; 4],
    /// Hold capacity in tonnes.
    pub hold: u8,
    /// Cargo per goods item. RULES sets no ceiling, so the count is wider than a byte.
    pub cargo: [u32; GOODS],
    pub fitted: Fitted,
    /// Missiles carried, 0..4.
    pub missiles: u8,
    /// 0 clean, 1..49 offender, 50+ fugitive.
    pub legal: u8,
    /// Goods availability at the current system's market, 0..63 each.
    pub availability: [u8; GOODS],
    /// The current market's per-visit byte.
    pub market_byte: u8,
    /// Kills; wraps at 65536.
    pub kills: u16,
}

impl Pilot {
    /// The start pilot. Its market (availability and market byte) is set by whoever starts a new
    /// game, from the formula (RULES A.9.7; decided 8 November 2026).
    pub fn start() -> Self {
        Self {
            name: START_NAME.to_string(),
            position: START_POSITION,
            galaxy_state: START_GALAXY,
            galaxy: 0,
            cash: 1_000,
            fuel: FULL_TANK,
            lasers: [PULSE_LASER, NO_LASER, NO_LASER, NO_LASER],
            hold: HOLD,
            cargo: [0; GOODS],
            fitted: Fitted::default(),
            missiles: 3,
            legal: 0,
            availability: [0; GOODS],
            market_byte: 0,
            kills: 0,
        }
    }

    /// Combat rank 0..8 from kills (RULES A.7.2, C.14).
    pub fn rank(&self) -> u8 {
        let n = self.kills;
        if n < 256 {
            let a = (n & 0xFF) >> 2;
            if a == 0 {
                0
            } else {
                (u16::BITS - a.leading_zeros() - 1) as u8
            }
        } else {
            match n >> 8 {
                1 => 5,
                2..=9 => 6,
                10..=24 => 7,
                _ => 8,
            }
        }
    }

    /// Clean, offender or fugitive (RULES A.7.2).
    pub fn legal_label(&self) -> LegalLabel {
        match self.legal {
            0 => LegalLabel::Clean,
            1..=49 => LegalLabel::Offender,
            _ => LegalLabel::Fugitive,
        }
    }

    /// ((cargo 3 + cargo 6) × 2 + cargo 10) mod 256 (RULES A.7.2).
    pub fn contraband(&self) -> u8 {
        let serious = u64::from(self.cargo[3]) + u64::from(self.cargo[6]);
        ((serious * 2 + u64::from(self.cargo[10])) % 256) as u8
    }

    /// True when the hold extension is fitted (capacity ≥ 26, RULES A.7.2).
    pub fn has_hold_extension(&self) -> bool {
        self.hold >= 26
    }
}

impl Default for Pilot {
    fn default() -> Self {
        Self::start()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rank_bands() {
        let mut p = Pilot::start();
        for (kills, rank) in [(0, 0), (7, 0), (8, 1), (15, 1), (16, 2), (63, 3), (64, 4), (255, 5), (256, 5),
            (511, 5), (512, 6), (2559, 6), (2560, 7), (6399, 7), (6400, 8), (65535, 8)] {
            p.kills = kills;
            assert_eq!(p.rank(), rank, "kills {kills}");
        }
    }

    #[test]
    fn legal_and_contraband() {
        let mut p = Pilot::start();
        assert_eq!(p.legal_label(), LegalLabel::Clean);
        p.legal = 49;
        assert_eq!(p.legal_label(), LegalLabel::Offender);
        p.legal = 50;
        assert_eq!(p.legal_label(), LegalLabel::Fugitive);
        p.cargo[3] = 100;
        p.cargo[6] = 30;
        p.cargo[10] = 7;
        assert_eq!(p.contraband(), ((130 * 2 + 7) % 256) as u8);
    }

    #[test]
    fn start_pilot() {
        let p = Pilot::start();
        assert_eq!((p.cash, p.fuel, p.missiles, p.hold), (1_000, 70, 3, 22));
        assert_eq!(p.lasers, [PULSE_LASER, 0, 0, 0]);
        assert!(!p.has_hold_extension());
    }
}
