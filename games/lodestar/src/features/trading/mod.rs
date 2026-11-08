//! Trading at the market panel (RULES, deliberate difference 12): buy or sell any goods item, in
//! any order, a quantity the panel's stepper sets. Prices, availability, hold space and cash work
//! as RULES A.9 to A.11 say; the market capability holds those rules.
//!
//! Callers pass the current system's economy (0..7) and the pilot's stored market byte
//! (`pilot.market_byte`), since prices always use them (RULES A.9.2). Nothing here draws a
//! random number.

use crate::capabilities::market;
use crate::capabilities::pilot::{Pilot, GOODS};

/// A trade that went through.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Trade {
    pub item: usize,
    pub quantity: u8,
    /// The price per unit, in tenths of a credit.
    pub unit_price: u16,
    /// `quantity × unit_price`, taken from or added to cash.
    pub total: u64,
}

/// Why a buy was refused. A refusal changes nothing.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BuyRefused {
    /// More than the market has of the item (always so for the special item, never on sale).
    MoreThanAvailable,
    /// The hold has no room for that many (RULES A.11.1), or the pilot's record cannot count
    /// that many of a hold-free item.
    NoRoom,
    /// The total is more than the cash.
    NotEnoughCash,
}

/// Why a sell was refused. A refusal changes nothing.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SellRefused {
    /// More than the cargo held of the item.
    MoreThanHeld,
}

/// The whole units the cash pays for at this price (unlimited at a price of 0).
fn affordable(cash: u64, unit_price: u16) -> u64 {
    if unit_price == 0 {
        u64::MAX
    } else {
        cash / u64::from(unit_price)
    }
}

/// The largest quantity the stepper offers for a buy: the smallest of the item's availability,
/// the room left in the hold for it, and the whole units the cash pays for.
pub fn max_buy(pilot: &Pilot, item: usize, economy: u8, market_byte: u8) -> u8 {
    assert!(item < GOODS, "goods items are 0..16");
    let unit_price = market::price(item, economy, market_byte);
    let available = u64::from(pilot.availability[item]);
    let room = u64::from(market::addable(pilot, item));
    available.min(room).min(affordable(pilot.cash, unit_price)) as u8
}

/// Buys `quantity` of `item` (RULES A.10.2 step 6 for that quantity): cash falls by
/// quantity × price, cargo rises and availability falls by the quantity. A quantity above
/// [`max_buy`] is refused, checked in the order availability, hold room, cash. Buying 0 changes
/// nothing.
pub fn buy(pilot: &mut Pilot, item: usize, quantity: u8, economy: u8, market_byte: u8) -> Result<Trade, BuyRefused> {
    assert!(item < GOODS, "goods items are 0..16");
    let unit_price = market::price(item, economy, market_byte);
    let total = u64::from(quantity) * u64::from(unit_price);
    if quantity > pilot.availability[item] {
        return Err(BuyRefused::MoreThanAvailable);
    }
    if u32::from(quantity) > market::addable(pilot, item) {
        return Err(BuyRefused::NoRoom);
    }
    if total > pilot.cash {
        return Err(BuyRefused::NotEnoughCash);
    }
    pilot.cash -= total;
    pilot.cargo[item] += quantity;
    pilot.availability[item] -= quantity;
    Ok(Trade { item, quantity, unit_price, total })
}

/// The largest quantity the stepper offers for a sale: the cargo held of the item.
pub fn max_sell(pilot: &Pilot, item: usize) -> u8 {
    pilot.cargo[item]
}

/// Sells `quantity` of `item`: cash rises by quantity × the current price and the cargo falls.
/// Availability is not restored (RULES A.9.4, A.14 item 7). Selling 0 changes nothing.
pub fn sell(pilot: &mut Pilot, item: usize, quantity: u8, economy: u8, market_byte: u8) -> Result<Trade, SellRefused> {
    assert!(item < GOODS, "goods items are 0..16");
    if quantity > pilot.cargo[item] {
        return Err(SellRefused::MoreThanHeld);
    }
    let unit_price = market::price(item, economy, market_byte);
    let total = u64::from(quantity) * u64::from(unit_price);
    pilot.cash += total;
    pilot.cargo[item] -= quantity;
    Ok(Trade { item, quantity, unit_price, total })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The new game's pilot at the starting system (economy 5, market byte 0; GDD § 5.2).
    fn new_game() -> Pilot {
        let mut pilot = Pilot::start();
        market::start_market(&mut pilot, 5);
        pilot
    }

    const E: u8 = 5;
    const R: u8 = 0;

    #[test]
    fn a_first_hold_of_grain() {
        let mut pilot = new_game();
        // Grain costs 6.0; 100.0 buys 16 whole tonnes, fewer than the 27 on sale and 22 of room.
        assert_eq!(max_buy(&pilot, 0, E, R), 16);
        let trade = buy(&mut pilot, 0, 16, E, R).unwrap();
        assert_eq!(trade, Trade { item: 0, quantity: 16, unit_price: 60, total: 960 });
        assert_eq!((pilot.cash, pilot.cargo[0], pilot.availability[0]), (40, 16, 11));
        assert_eq!(max_buy(&pilot, 0, E, R), 0, "4.0 left buys no grain");
    }

    #[test]
    fn max_buy_is_limited_by_availability() {
        let mut pilot = new_game();
        pilot.cash = 1_000_000;
        // Livestock: 36 on sale, but 22 of room; then extended, 36.
        assert_eq!(max_buy(&pilot, 4, E, R), 22);
        pilot.hold = 37;
        assert_eq!(max_buy(&pilot, 4, E, R), 36);
        // Lotus resin: only 2 on sale.
        assert_eq!(max_buy(&pilot, 6, E, R), 2);
        // Nothing on sale.
        assert_eq!(max_buy(&pilot, 3, E, R), 0);
        assert_eq!(max_buy(&pilot, 16, E, R), 0);
    }

    #[test]
    fn max_buy_is_limited_by_the_hold() {
        let mut pilot = new_game();
        pilot.cash = 1_000_000;
        pilot.cargo[9] = 20;
        assert_eq!(max_buy(&pilot, 0, E, R), 2);
        pilot.cargo[9] = 22;
        assert_eq!(max_buy(&pilot, 0, E, R), 0);
        // Hold-free goods ignore it: Iridium, 25 on sale.
        assert_eq!(max_buy(&pilot, 13, E, R), 25);
    }

    #[test]
    fn max_buy_is_limited_by_whole_units_of_cash() {
        let mut pilot = new_game();
        // Black pearls at 22.4: 100.0 pays for 4 (89.6), not 5 (112.0).
        assert_eq!(max_buy(&pilot, 15, E, R), 4);
        pilot.cash = 224 * 5;
        assert_eq!(max_buy(&pilot, 15, E, R), 5, "exactly enough is enough");
        pilot.cash = 0;
        assert_eq!(max_buy(&pilot, 15, E, R), 0);
    }

    #[test]
    fn buy_refusals_change_nothing() {
        let mut pilot = new_game();
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, 6, 3, E, R), Err(BuyRefused::MoreThanAvailable));
        assert_eq!(buy(&mut pilot, 16, 1, E, R), Err(BuyRefused::MoreThanAvailable));
        assert_eq!(buy(&mut pilot, 4, 23, E, R), Err(BuyRefused::NoRoom));
        assert_eq!(buy(&mut pilot, 15, 5, E, R), Err(BuyRefused::NotEnoughCash));
        assert_eq!(pilot, before);
    }

    #[test]
    fn buy_refusals_come_in_rule_order() {
        let mut pilot = new_game();
        pilot.cash = 0;
        pilot.cargo[1] = 22;
        // Too many, no room and no cash: availability is checked first, then the hold.
        assert_eq!(buy(&mut pilot, 0, 28, E, R), Err(BuyRefused::MoreThanAvailable));
        assert_eq!(buy(&mut pilot, 0, 1, E, R), Err(BuyRefused::NoRoom));
        pilot.cargo[1] = 0;
        assert_eq!(buy(&mut pilot, 0, 1, E, R), Err(BuyRefused::NotEnoughCash));
    }

    #[test]
    fn buying_nothing_is_allowed_and_changes_nothing() {
        let mut pilot = new_game();
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, 3, 0, E, R).map(|t| t.total), Ok(0));
        assert_eq!(sell(&mut pilot, 3, 0, E, R).map(|t| t.total), Ok(0));
        assert_eq!(pilot, before);
    }

    #[test]
    fn hold_free_goods_need_only_availability_and_cash() {
        let mut pilot = new_game();
        pilot.cash = 1_000_000;
        pilot.cargo[0] = 22;
        buy(&mut pilot, 14, 9, E, R).unwrap();
        assert_eq!((pilot.cargo[14], pilot.availability[14]), (9, 0));
        assert_eq!(pilot.cash, 1_000_000 - 9 * 716);
    }

    #[test]
    fn hold_free_goods_stop_at_the_cargo_ceiling() {
        let mut pilot = new_game();
        pilot.cash = 1_000_000;
        pilot.cargo[13] = 240;
        assert_eq!(max_buy(&pilot, 13, E, R), 15);
        assert_eq!(buy(&mut pilot, 13, 16, E, R), Err(BuyRefused::NoRoom));
        assert!(buy(&mut pilot, 13, 15, E, R).is_ok());
        assert_eq!(pilot.cargo[13], 255);
    }

    #[test]
    fn partial_sales_at_the_current_price() {
        let mut pilot = new_game();
        pilot.cargo[7] = 10;
        assert_eq!(max_sell(&pilot, 7), 10);
        // Robotics sells at 72.8 here.
        let trade = sell(&mut pilot, 7, 3, E, R).unwrap();
        assert_eq!(trade, Trade { item: 7, quantity: 3, unit_price: 728, total: 2_184 });
        assert_eq!((pilot.cash, pilot.cargo[7]), (1_000 + 2_184, 7));
        assert_eq!(sell(&mut pilot, 7, 8, E, R), Err(SellRefused::MoreThanHeld));
        assert_eq!(pilot.cargo[7], 7);
    }

    #[test]
    fn selling_never_restores_availability() {
        let mut pilot = new_game();
        buy(&mut pilot, 1, 5, E, R).unwrap();
        assert_eq!(pilot.availability[1], 25);
        sell(&mut pilot, 1, 5, E, R).unwrap();
        assert_eq!(pilot.availability[1], 25);
        assert_eq!(pilot.cash, 1_000, "same price both ways: no spread");
        // Robotics: none on sale, but it can still be sold.
        pilot.cargo[7] = 1;
        sell(&mut pilot, 7, 1, E, R).unwrap();
        assert_eq!(pilot.availability[7], 0);
    }

    #[test]
    fn the_special_item_can_be_sold() {
        let mut pilot = new_game();
        pilot.cargo[16] = 2;
        let trade = sell(&mut pilot, 16, 2, E, R).unwrap();
        assert_eq!(trade.total, 760);
    }

    #[test]
    fn prices_use_the_market_byte_passed_in() {
        let mut pilot = new_game();
        market::arrive(&mut pilot, 0, 0xFF);
        // Robotics at a wealthy factory world with R 0xFF: 147 → 58.8.
        pilot.cargo[7] = 1;
        let byte = pilot.market_byte;
        let trade = sell(&mut pilot, 7, 1, 0, byte).unwrap();
        assert_eq!(trade.unit_price, 588);
    }

    #[test]
    fn a_price_of_zero_does_not_limit_the_quantity() {
        assert_eq!(affordable(0, 0), u64::MAX);
        assert_eq!(affordable(1_000, 60), 16);
    }
}
