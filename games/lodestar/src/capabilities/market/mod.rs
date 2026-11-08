//! The market and the hold: the goods table, prices, availability, the per-visit market byte
//! (RULES A.9) and hold space (RULES A.11). The goods data are the GDD's (§ 4.7, § 5.1, § 5.2).
//!
//! The market never looks a system up: callers pass the current system's economy (0..7,
//! RULES A.3.4) as a plain number. Nothing here draws a random number except the two operations
//! that say so ([`draw_and_arrive`] and [`scoop_canister`]).

use crate::capabilities::pilot::{Pilot, GOODS};
use crate::capabilities::random::MainGenerator;

/// The unit a goods item is shown in. A label only: there is no conversion (RULES A.11.2).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Unit {
    Tonnes,
    Kilograms,
    Grams,
}

impl Unit {
    /// The short label shown after a quantity or a price (GDD § 4.7).
    pub fn symbol(self) -> &'static str {
        match self {
            Unit::Tonnes => "t",
            Unit::Kilograms => "kg",
            Unit::Grams => "g",
        }
    }
}

/// One row of the goods table (RULES A.9.1).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Goods {
    pub name: &'static str,
    pub unit: Unit,
    /// Base price `B`, the price byte before economy and fluctuation.
    pub base_price: u8,
    /// Economy factor `F`: its sign gives the direction, its magnitude mod 32 the step.
    pub gradient: i8,
    /// Base quantity `Q`, availability before economy and fluctuation.
    pub base_quantity: u8,
    /// Fluctuation mask `M`: the bits of the market byte that move this item.
    pub mask: u8,
}

impl Goods {
    /// `E × (|F| mod 32)`.
    fn economy_step(&self, economy: u8) -> i32 {
        let magnitude = i32::from(self.gradient).abs() % 32;
        i32::from(economy) * magnitude
    }

    /// The price in tenths of a credit per unit (RULES A.9.3): `4 × ((R & M) + B ± E·|F| mod 256)`.
    pub fn price(&self, economy: u8, market_byte: u8) -> u16 {
        let mut a = i32::from(market_byte & self.mask) + i32::from(self.base_price);
        let e = self.economy_step(economy);
        if self.gradient >= 0 {
            a += e;
        } else {
            a -= e;
        }
        let byte = a.rem_euclid(256) as u16;
        byte * 4
    }

    /// The availability formula of RULES A.9.4 step 2 to 4, for an item that can be on sale:
    /// `(R & M) + Q ∓ E·|F|`, mod 256, 0 when bit 7 is set, then cut to 6 bits.
    pub fn quantity(&self, economy: u8, market_byte: u8) -> u8 {
        let mut a = i32::from(market_byte & self.mask) + i32::from(self.base_quantity);
        let e = self.economy_step(economy);
        if self.gradient >= 0 {
            a -= e;
        } else {
            a += e;
        }
        let byte = a.rem_euclid(256) as u8;
        if byte >= 128 {
            0
        } else {
            byte & 63
        }
    }
}

const fn goods(name: &'static str, unit: Unit, base_price: u8, gradient: i8, base_quantity: u8, mask: u8) -> Goods {
    Goods { name, unit, base_price, gradient, base_quantity, mask }
}

/// The 17 goods items in their fixed order (GDD § 4.7 names and units, § 5.1 values).
pub const TABLE: [Goods; GOODS] = [
    goods("Grain", Unit::Tonnes, 30, -3, 12, 0x03),
    goods("Fibre", Unit::Tonnes, 30, -2, 20, 0x06),
    goods("Fertiliser", Unit::Tonnes, 34, 3, 30, 0x03),
    goods("Bonded sleepers", Unit::Tonnes, 48, -4, 236, 0x1E),
    goods("Livestock", Unit::Tonnes, 58, -6, 6, 0x07),
    goods("Medicines", Unit::Tonnes, 120, 6, 44, 0x0C),
    goods("Lotus resin", Unit::Tonnes, 180, -14, 188, 0x1C),
    goods("Robotics", Unit::Tonnes, 132, 10, 46, 0x0F),
    goods("Drive parts", Unit::Tonnes, 88, 7, 34, 0x0F),
    goods("Hull plating", Unit::Tonnes, 64, 2, 28, 0x0F),
    goods("Jammer kits", Unit::Tonnes, 100, 11, 40, 0x0E),
    goods("Hardwood", Unit::Tonnes, 150, -7, 216, 0x0F),
    goods("Salvage", Unit::Tonnes, 36, 1, 50, 0x05),
    goods("Iridium", Unit::Kilograms, 108, 1, 30, 0x0F),
    goods("Isotope vials", Unit::Grams, 164, 3, 24, 0x0F),
    goods("Black pearls", Unit::Grams, 66, -2, 16, 0x1F),
    goods("Hush glass", Unit::Kilograms, 140, -9, 0, 0x0F),
];

/// The two seriously illegal items, which count double in the contraband value (RULES A.9.6).
pub const SERIOUS_CONTRABAND: [usize; 2] = [3, 6];
/// The mildly illegal item, which counts once (RULES A.9.6).
pub const MILD_CONTRABAND: usize = 10;
/// What a scooped escape pod gives (RULES A.9.6, A.11.3).
pub const ESCAPE_POD_ITEM: usize = 3;
/// The special goods item: never on sale, given by scooping the alien drone (RULES A.9.6).
pub const SPECIAL_ITEM: usize = 16;
/// A scooped canister gives item `(random byte) & CANISTER_MASK`, so one of items 0..7.
pub const CANISTER_MASK: u8 = 7;
/// Items from this number up take no hold space (RULES A.11.1).
pub const FIRST_HOLD_FREE: usize = 13;

/// The price of `item` in tenths of a credit per unit (RULES A.9.3).
pub fn price(item: usize, economy: u8, market_byte: u8) -> u16 {
    TABLE[item].price(economy, market_byte)
}

/// The availability of `item` on arrival (RULES A.9.4): 0 for the special item, else the formula.
pub fn availability(item: usize, economy: u8, market_byte: u8) -> u8 {
    if item == SPECIAL_ITEM {
        0
    } else {
        TABLE[item].quantity(economy, market_byte)
    }
}

/// All 17 availabilities for an economy and a market byte.
pub fn availabilities(economy: u8, market_byte: u8) -> [u8; GOODS] {
    std::array::from_fn(|item| availability(item, economy, market_byte))
}

/// Arrival in a system with this market byte (RULES A.5.6 steps 1 and 2): stores the byte and
/// rebuilds all 17 availabilities from the system's economy.
pub fn arrive(pilot: &mut Pilot, economy: u8, market_byte: u8) {
    pilot.market_byte = market_byte;
    pilot.availability = availabilities(economy, market_byte);
}

/// Draws the new market byte (one draw) and then arrives with it, as RULES A.5.6 orders it.
/// Returns the byte drawn.
pub fn draw_and_arrive(pilot: &mut Pilot, economy: u8, random: &mut MainGenerator) -> u8 {
    let byte = random.byte();
    arrive(pilot, economy, byte);
    byte
}

/// The new game's market (RULES A.9.7, GDD § 5.2): market byte 0 and the availability the
/// formula gives for the starting system's economy.
pub fn start_market(pilot: &mut Pilot, economy: u8) {
    arrive(pilot, economy, 0);
}

/// True for items 0..12, which take hold space (RULES A.11.1).
pub fn takes_hold_space(item: usize) -> bool {
    item < FIRST_HOLD_FREE
}

/// Tonnes in use: `cargo[0] + … + cargo[12]`.
pub fn hold_used(pilot: &Pilot) -> u32 {
    pilot.cargo[..FIRST_HOLD_FREE].iter().sum()
}

/// RULES A.11.1 exactly: is there room for `n` more of `item`?
pub fn has_room(pilot: &Pilot, item: usize, n: u32) -> bool {
    !takes_hold_space(item) || hold_used(pilot) + n <= u32::from(pilot.hold)
}

/// The most of `item` the hold has room for (RULES A.11.1), or `None` for an item that takes no
/// hold space.
pub fn room_for(pilot: &Pilot, item: usize) -> Option<u32> {
    if takes_hold_space(item) {
        Some(u32::from(pilot.hold).saturating_sub(hold_used(pilot)))
    } else {
        None
    }
}

/// The most of `item` that can be added: the hold room for items that take space, and no limit
/// (short of the counter's own size) for items 13..16, which take none (RULES A.11.1).
pub fn addable(pilot: &Pilot, item: usize) -> u32 {
    room_for(pilot, item).unwrap_or(u32::MAX - pilot.cargo[item])
}

/// Adds one unit of `item` gained in flight (scooped), if there is room (RULES A.11.3).
/// Returns false when nothing was added, so the caller plays the no-room sound; the object is
/// destroyed either way.
pub fn gain_one(pilot: &mut Pilot, item: usize) -> bool {
    if addable(pilot, item) >= 1 {
        pilot.cargo[item] += 1;
        true
    } else {
        false
    }
}

/// What scooping a canister gave.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Scooped {
    /// The goods item, 0..7.
    pub item: usize,
    /// False when the hold had no room and nothing was added.
    pub gained: bool,
}

/// Scoops a cargo canister (RULES A.11.3): draws one byte, the item is that byte `& 7`, and only
/// then checks the room. The draw happens even when the hold is full.
pub fn scoop_canister(pilot: &mut Pilot, random: &mut MainGenerator) -> Scooped {
    let item = usize::from(random.byte() & CANISTER_MASK);
    let gained = gain_one(pilot, item);
    Scooped { item, gained }
}

/// Damage destroys a whole stack (RULES A.11.3, C.10.3): `item`'s cargo becomes 0. Returns true
/// when there was any to lose, which is when the loss notice shows.
pub fn lose_stack(pilot: &mut Pilot, item: usize) -> bool {
    let had = pilot.cargo[item] > 0;
    pilot.cargo[item] = 0;
    had
}

/// Empties the hold (the escape pod, RULES A.12.4).
pub fn empty_hold(pilot: &mut Pilot) {
    pilot.cargo = [0; GOODS];
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The starting system's economy (GDD § 5.2).
    const START_ECONOMY: u8 = 5;

    fn test_goods(base_price: u8, gradient: i8, base_quantity: u8, mask: u8) -> Goods {
        goods("Test", Unit::Tonnes, base_price, gradient, base_quantity, mask)
    }

    #[test]
    fn starting_market_matches_the_gdd_list() {
        let mut pilot = Pilot::start();
        pilot.market_byte = 99;
        start_market(&mut pilot, START_ECONOMY);
        assert_eq!(pilot.market_byte, 0);
        assert_eq!(pilot.availability, [27, 30, 15, 0, 36, 14, 2, 0, 0, 18, 0, 0, 45, 25, 9, 26, 0]);
        let prices: Vec<u16> = (0..GOODS).map(|i| price(i, START_ECONOMY, 0)).collect();
        assert_eq!(
            prices,
            [60, 80, 196, 112, 112, 600, 440, 728, 492, 296, 620, 460, 164, 452, 716, 224, 380]
        );
    }

    #[test]
    fn price_worked_examples() {
        // Grain, E 5, R 0: 30 − 15 = 15 → 60 tenths.
        assert_eq!(price(0, 5, 0), 60);
        // Robotics, E 0, R 0xFF: (0xFF & 0x0F) + 132 = 147 → 588.
        assert_eq!(price(7, 0, 0xFF), 588);
        // Lotus resin, E 7, R 0xFF: 28 + 180 − 98 = 110 → 440.
        assert_eq!(price(6, 7, 0xFF), 440);
        // Only the masked bits count: Fertiliser's mask is 0x03.
        assert_eq!(price(2, 3, 0xFC), price(2, 3, 0x00));
        assert_eq!(price(2, 3, 0x03), price(2, 3, 0x00) + 12);
    }

    #[test]
    fn price_wraps_both_ways() {
        // Upward: 0x10 + 250 + 7 = 273 → 17 → 68.
        assert_eq!(test_goods(250, 1, 0, 0xFF).price(7, 0x10), 68);
        // Downward: 5 − 7·20 = −135 → 121 → 484.
        assert_eq!(test_goods(5, -20, 0, 0).price(7, 0), 484);
        // Exactly 256 → 0.
        assert_eq!(test_goods(249, 1, 0, 0).price(7, 0), 0);
    }

    #[test]
    fn gradient_magnitude_is_taken_mod_32_and_keeps_its_sign() {
        // |33| mod 32 = 1, positive: dearer with E.
        assert_eq!(test_goods(100, 33, 0, 0).price(4, 0), 4 * 104);
        // |−40| mod 32 = 8, negative: cheaper with E.
        assert_eq!(test_goods(100, -40, 0, 0).price(2, 0), 4 * 84);
        // |−128| mod 32 = 0 and |32| mod 32 = 0: the economy has no effect.
        assert_eq!(test_goods(100, -128, 50, 0).price(7, 0), 400);
        assert_eq!(test_goods(100, 32, 50, 0).quantity(7, 0), 50);
    }

    #[test]
    fn availability_rules() {
        // Negative factor adds: 40 + 7·5 = 75 → 75 & 63 = 11 (the 64..127 band folds).
        assert_eq!(test_goods(0, -5, 40, 0).quantity(7, 0), 11);
        // 128..255 counts as negative: 100 + 35 = 135 → 0.
        assert_eq!(test_goods(0, -5, 100, 0).quantity(7, 0), 0);
        // Large positive sums wrap: 250 + 12 = 262 → 6.
        assert_eq!(test_goods(0, -3, 250, 0).quantity(4, 0), 6);
        // Positive factor subtracts, and below zero wraps into the negative band: 10 − 15 → 0.
        assert_eq!(test_goods(0, 5, 10, 0).quantity(3, 0), 0);
        // The masked bits add to availability as they do to price.
        assert_eq!(test_goods(0, 0, 10, 0x0F).quantity(0, 0xF3), 13);
        // Bonded sleepers at E 0, R 0x1E: 30 + 236 = 266 → 10.
        assert_eq!(availability(3, 0, 0x1E), 10);
    }

    #[test]
    fn the_special_item_is_never_on_sale() {
        for economy in 0..8 {
            for byte in 0..=255 {
                assert_eq!(availability(SPECIAL_ITEM, economy, byte), 0);
            }
        }
        // Its price still exists, so it can be sold: E 0, R 0: 140 → 560.
        assert_eq!(price(SPECIAL_ITEM, 0, 0), 560);
    }

    /// The GDD's table of ranges (§ 5.1), for every market byte at economies 0 and 7.
    #[test]
    fn gdd_price_and_availability_ranges() {
        // (price E0 min, max, price E7 min, max) in tenths; (avail E0 min, max, E7 min, max).
        type Ranges = ((u16, u16, u16, u16), (u8, u8, u8, u8));
        let expected: [Ranges; GOODS] = [
            ((120, 132, 36, 48), (12, 15, 33, 36)),
            ((120, 144, 64, 88), (20, 26, 34, 40)),
            ((136, 148, 220, 232), (30, 33, 9, 12)),
            ((192, 312, 80, 200), (0, 10, 8, 38)),
            ((232, 260, 64, 92), (6, 13, 48, 55)),
            ((480, 528, 648, 696), (44, 56, 2, 14)),
            ((720, 832, 328, 440), (0, 0, 30, 58)),
            ((528, 588, 808, 868), (46, 61, 0, 0)),
            ((352, 412, 548, 608), (34, 49, 0, 0)),
            ((256, 316, 312, 372), (28, 43, 14, 29)),
            ((400, 456, 708, 764), (40, 54, 0, 0)),
            ((600, 660, 404, 464), (0, 0, 9, 24)),
            ((144, 164, 172, 192), (50, 55, 43, 48)),
            ((432, 492, 460, 520), (30, 45, 23, 38)),
            ((656, 716, 740, 800), (24, 39, 3, 18)),
            ((264, 388, 208, 332), (16, 47, 30, 61)),
            ((560, 620, 308, 368), (0, 0, 0, 0)),
        ];
        for (item, (prices, quantities)) in expected.iter().enumerate() {
            let range = |f: &dyn Fn(u8) -> u16| {
                let values: Vec<u16> = (0..=255u8).map(f).collect();
                (*values.iter().min().unwrap(), *values.iter().max().unwrap())
            };
            let p0 = range(&|r| price(item, 0, r));
            let p7 = range(&|r| price(item, 7, r));
            let a0 = range(&|r| u16::from(availability(item, 0, r)));
            let a7 = range(&|r| u16::from(availability(item, 7, r)));
            assert_eq!((p0.0, p0.1, p7.0, p7.1), *prices, "prices of item {item}");
            let q = quantities;
            assert_eq!(
                (a0.0, a0.1, a7.0, a7.1),
                (u16::from(q.0), u16::from(q.1), u16::from(q.2), u16::from(q.3)),
                "availability of item {item}"
            );
        }
        // "None until E 3" for lotus resin, "none until E 4" for hardwood.
        assert!((0..=255).all(|r| availability(6, 2, r) == 0));
        assert!((0..=255).any(|r| availability(6, 3, r) > 0));
        assert!((0..=255).all(|r| availability(11, 3, r) == 0));
        assert!((0..=255).any(|r| availability(11, 4, r) > 0));
    }

    #[test]
    fn units_and_names_follow_the_gdd() {
        assert_eq!(TABLE[0].name, "Grain");
        assert_eq!(TABLE[3].name, "Bonded sleepers");
        assert_eq!(TABLE[16].name, "Hush glass");
        assert!(TABLE[..13].iter().all(|g| g.unit == Unit::Tonnes));
        let small: Vec<&str> = TABLE[13..].iter().map(|g| g.unit.symbol()).collect();
        assert_eq!(small, ["kg", "g", "g", "kg"]);
    }

    #[test]
    fn arrival_stores_the_byte_and_rebuilds_availability() {
        let mut pilot = Pilot::start();
        pilot.availability = [63; GOODS];
        arrive(&mut pilot, 2, 0xA7);
        assert_eq!(pilot.market_byte, 0xA7);
        assert_eq!(pilot.availability, availabilities(2, 0xA7));
        assert_eq!(pilot.availability[SPECIAL_ITEM], 0);
    }

    #[test]
    fn arrival_draws_exactly_one_byte() {
        let mut pilot = Pilot::start();
        let mut random = MainGenerator::new();
        let byte = draw_and_arrive(&mut pilot, 6, &mut random);
        // The first draw from the starting state is 0xAC (RULES C.2.1, worked in the random tests).
        assert_eq!(byte, 0xAC);
        assert_eq!(pilot.market_byte, 0xAC);
        assert_eq!(pilot.availability, availabilities(6, 0xAC));
        let mut reference = MainGenerator::new();
        reference.draw();
        assert_eq!(random, reference);
    }

    #[test]
    fn hold_space_counts_items_0_to_12_only() {
        let mut pilot = Pilot::start();
        pilot.cargo[0] = 10;
        pilot.cargo[12] = 5;
        pilot.cargo[13] = 200;
        pilot.cargo[16] = 9;
        assert_eq!(hold_used(&pilot), 15);
        assert!(has_room(&pilot, 4, 7));
        assert!(!has_room(&pilot, 4, 8));
        assert_eq!(room_for(&pilot, 4), Some(7));
        for item in 13..GOODS {
            assert!(has_room(&pilot, item, 1_000));
            assert_eq!(room_for(&pilot, item), None);
        }
        pilot.hold = 37;
        assert_eq!(room_for(&pilot, 0), Some(22));
    }

    #[test]
    fn room_never_goes_negative() {
        let mut pilot = Pilot::start();
        pilot.cargo[1] = 30;
        assert_eq!(room_for(&pilot, 1), Some(0));
        assert!(!has_room(&pilot, 1, 0), "30 + 0 is more than 22");
    }

    #[test]
    fn hold_free_items_have_no_ceiling() {
        // RULES sets no limit on items 13..16, which take no hold space.
        let mut pilot = Pilot::start();
        pilot.cargo[13] = 255;
        assert!(gain_one(&mut pilot, 13));
        assert_eq!(pilot.cargo[13], 256);
        assert_eq!(addable(&pilot, 13), u32::MAX - 256);
    }

    #[test]
    fn gaining_in_flight_honours_hold_space() {
        let mut pilot = Pilot::start();
        pilot.cargo[0] = 21;
        assert!(gain_one(&mut pilot, ESCAPE_POD_ITEM));
        assert_eq!(pilot.cargo[ESCAPE_POD_ITEM], 1);
        assert!(!gain_one(&mut pilot, 5), "the hold is full at 22");
        assert_eq!(pilot.cargo[5], 0);
        assert!(gain_one(&mut pilot, SPECIAL_ITEM), "item 16 takes no space");
        assert_eq!(pilot.cargo[SPECIAL_ITEM], 1);
    }

    #[test]
    fn a_canister_draws_before_the_room_check() {
        let mut pilot = Pilot::start();
        pilot.cargo[0] = 22;
        let mut random = MainGenerator::new();
        let scooped = scoop_canister(&mut pilot, &mut random);
        // First byte 0xAC & 7 = 4.
        assert_eq!(scooped, Scooped { item: 4, gained: false });
        assert_eq!(pilot.cargo[4], 0);
        let mut reference = MainGenerator::new();
        reference.draw();
        assert_eq!(random, reference, "the byte is drawn even with a full hold");

        pilot.cargo[0] = 0;
        // Second byte 0xE1 & 7 = 1.
        let scooped = scoop_canister(&mut pilot, &mut random);
        assert_eq!(scooped, Scooped { item: 1, gained: true });
        assert_eq!(pilot.cargo[1], 1);
    }

    #[test]
    fn a_canister_gives_items_0_to_7() {
        let mut random = MainGenerator::new();
        let mut pilot = Pilot::start();
        pilot.hold = 255;
        for _ in 0..200 {
            assert!(scoop_canister(&mut pilot, &mut random).item < 8);
        }
    }

    #[test]
    fn losing_a_stack_and_emptying_the_hold() {
        let mut pilot = Pilot::start();
        pilot.cargo[7] = 4;
        assert!(lose_stack(&mut pilot, 7));
        assert_eq!(pilot.cargo[7], 0);
        assert!(!lose_stack(&mut pilot, 7), "nothing to lose, no notice");
        pilot.cargo[2] = 3;
        pilot.cargo[15] = 40;
        empty_hold(&mut pilot);
        assert_eq!(pilot.cargo, [0; GOODS]);
    }

    #[test]
    fn contraband_items_match_the_pilot_rule() {
        let mut pilot = Pilot::start();
        pilot.cargo[SERIOUS_CONTRABAND[0]] = 1;
        pilot.cargo[SERIOUS_CONTRABAND[1]] = 1;
        pilot.cargo[MILD_CONTRABAND] = 1;
        assert_eq!(pilot.contraband(), 5);
    }
}
