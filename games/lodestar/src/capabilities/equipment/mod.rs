//! The equipment shop (RULES A.12): the twelve items in their fixed order, which a system offers
//! by tech level, their prices, and what buying each one does. Names and prices are the GDD's
//! (§ 4.8, § 5.3).
//!
//! LodeStar's equipment panel picks an item from a list (RULES, deliberate difference 12), so
//! [`buy`] takes the item, and the mount for a laser, as arguments: there is no number entry and
//! no prompt flow here. Nothing in the shop draws a random number.

use crate::capabilities::pilot::{Mount, Pilot, BEAM_LASER, FULL_TANK, HOLD_EXTENDED, MAX_MISSILES, NO_LASER, PULSE_LASER};

/// The twelve equipment items, numbered 0..11 in RULES A.12.1's fixed order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Item {
    Fuel,
    Missile,
    HoldExtension,
    Ecm,
    PulseLaser,
    BeamLaser,
    FuelScoop,
    EscapePod,
    AreaBlast,
    EnergyBooster,
    AutoDock,
    GalaxyDrive,
}

/// The fuel rate: tenths of a credit per tenth of a light year (data, GDD § 5.3).
pub const FUEL_RATE: u32 = 3;

/// Bit 7 of a laser value marks the beam laser (RULES A.7.1).
const BEAM_BIT: u8 = 0x80;

/// The mounts' names and short tags, in mount order (GDD § 4.8; LodeStar keys 1..4).
pub const MOUNT_NAMES: [&str; 4] = ["Fore", "Aft", "Port", "Starboard"];
pub const MOUNT_TAGS: [&str; 4] = ["FWD", "AFT", "PORT", "STBD"];

impl Item {
    /// All twelve, in order.
    pub const ALL: [Item; 12] = [
        Item::Fuel,
        Item::Missile,
        Item::HoldExtension,
        Item::Ecm,
        Item::PulseLaser,
        Item::BeamLaser,
        Item::FuelScoop,
        Item::EscapePod,
        Item::AreaBlast,
        Item::EnergyBooster,
        Item::AutoDock,
        Item::GalaxyDrive,
    ];

    /// The item's number, 0..11.
    pub fn number(self) -> usize {
        self as usize
    }

    /// The item with this number, if there is one.
    pub fn from_number(number: usize) -> Option<Item> {
        Item::ALL.get(number).copied()
    }

    /// The LodeStar name (GDD § 4.8).
    pub fn name(self) -> &'static str {
        match self {
            Item::Fuel => "Tank refill",
            Item::Missile => "Dart missile",
            Item::HoldExtension => "Cargo sponsons",
            Item::Ecm => "Scrambler unit",
            Item::PulseLaser => "Repeater laser",
            Item::BeamLaser => "Lance laser",
            Item::FuelScoop => "Corona scoop",
            Item::EscapePod => "Lifeboat",
            Item::AreaBlast => "Nova charge",
            Item::EnergyBooster => "Booster cells",
            Item::AutoDock => "Auto-berth",
            Item::GalaxyDrive => "Reach drive",
        }
    }

    /// The HUD tag shown while fitted, for the items that have one (GDD § 4.8).
    pub fn hud_tag(self) -> Option<&'static str> {
        match self {
            Item::Ecm => Some("SCR"),
            Item::EscapePod => Some("BOAT"),
            Item::AreaBlast => Some("NOVA"),
            _ => None,
        }
    }

    /// True for the two lasers, which need a mount.
    pub fn is_laser(self) -> bool {
        matches!(self, Item::PulseLaser | Item::BeamLaser)
    }

    /// The fixed price in tenths of a credit (data, GDD § 5.3); fuel has none (see [`price`]).
    pub fn fixed_price(self) -> u32 {
        match self {
            Item::Fuel => 0,
            Item::Missile => 350,
            Item::HoldExtension => 3_600,
            Item::Ecm => 5_600,
            Item::PulseLaser => 3_200,
            Item::BeamLaser => 9_600,
            Item::FuelScoop => 4_800,
            Item::EscapePod => 8_800,
            Item::AreaBlast => 7_600,
            Item::EnergyBooster => 13_600,
            Item::AutoDock => 12_400,
            Item::GalaxyDrive => 45_000,
        }
    }
}

/// How many items a system with internal tech level `T` (0..14) offers: `min(T + 3, 12)`
/// (RULES A.12.2).
pub fn offered_count(tech_level: u8) -> usize {
    (usize::from(tech_level) + 3).min(Item::ALL.len())
}

/// The items a system with internal tech level `T` offers: the first `min(T + 3, 12)`.
pub fn offered(tech_level: u8) -> &'static [Item] {
    &Item::ALL[..offered_count(tech_level)]
}

/// True when the item is on offer at this tech level.
pub fn is_offered(item: Item, tech_level: u8) -> bool {
    item.number() < offered_count(tech_level)
}

/// The price in tenths of a credit (RULES A.12.3): fuel's is `(70 − fuel) × rate`, recomputed from
/// the pilot's fuel (0 with a full tank); every other item's is fixed.
pub fn price(item: Item, pilot: &Pilot) -> u32 {
    match item {
        Item::Fuel => u32::from(FULL_TANK.saturating_sub(pilot.fuel)) * FUEL_RATE,
        other => other.fixed_price(),
    }
}

/// The equipment panel's rows: each offered item with its current price.
pub fn listing(tech_level: u8, pilot: &Pilot) -> Vec<(Item, u32)> {
    offered(tech_level).iter().map(|&item| (item, price(item, pilot))).collect()
}

/// A purchase that went through.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Bought {
    pub item: Item,
    /// The price taken from cash.
    pub paid: u32,
    /// Given back for a pulse laser the beam laser replaced (the pulse laser's price), else 0.
    pub refund: u32,
    /// The mount a laser went on.
    pub mount: Option<Mount>,
}

/// Why a purchase was refused. A refusal leaves the pilot exactly as it was.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Refused {
    /// The item is not offered at this tech level (only from [`buy_offered`]).
    NotOffered,
    /// The price is more than the cash (RULES A.12.4 step 2).
    NotEnoughCash,
    /// A laser was chosen without one of the four mounts.
    NoMount,
    /// Already at its limit (the table of RULES A.12.4); the price was given back.
    AtLimit,
}

/// Buys `item` (RULES A.12.4 steps 2 to 5 and the table). `mount` is the chosen mount for a laser
/// and is ignored for everything else. The cash check uses the full price, even when a beam
/// laser would refund a pulse laser (RULES A.14 item 12); the price is taken, then given back if
/// the item is at its limit.
pub fn buy(pilot: &mut Pilot, item: Item, mount: Option<Mount>) -> Result<Bought, Refused> {
    let cost = price(item, pilot);
    if u64::from(cost) > pilot.cash {
        return Err(Refused::NotEnoughCash);
    }
    let mount = if item.is_laser() {
        match mount {
            Some(m) if m < pilot.lasers.len() => Some(m),
            _ => return Err(Refused::NoMount),
        }
    } else {
        None
    };

    pilot.cash -= u64::from(cost);
    let mut refund = 0;
    let fitted = match item {
        Item::Fuel => {
            pilot.fuel = FULL_TANK;
            true
        }
        Item::Missile => {
            let room = pilot.missiles < MAX_MISSILES;
            if room {
                pilot.missiles += 1;
            }
            room
        }
        Item::HoldExtension => fit(&mut pilot.hold, HOLD_EXTENDED),
        Item::Ecm => fit_flag(&mut pilot.fitted.ecm),
        Item::PulseLaser => {
            let slot = &mut pilot.lasers[mount.unwrap_or_default()];
            let empty = *slot == NO_LASER;
            if empty {
                *slot = PULSE_LASER;
            }
            empty
        }
        Item::BeamLaser => {
            let slot = &mut pilot.lasers[mount.unwrap_or_default()];
            let has_beam = *slot & BEAM_BIT != 0;
            if !has_beam {
                if *slot != NO_LASER {
                    refund = Item::PulseLaser.fixed_price();
                }
                *slot = BEAM_LASER;
            }
            !has_beam
        }
        Item::FuelScoop => fit_flag(&mut pilot.fitted.fuel_scoop),
        Item::EscapePod => fit_flag(&mut pilot.fitted.escape_pod),
        Item::AreaBlast => fit_flag(&mut pilot.fitted.area_blast),
        Item::EnergyBooster => fit_flag(&mut pilot.fitted.energy_booster),
        Item::AutoDock => fit_flag(&mut pilot.fitted.auto_dock),
        Item::GalaxyDrive => fit_flag(&mut pilot.fitted.galaxy_drive),
    };

    if fitted {
        pilot.cash += u64::from(refund);
        Ok(Bought { item, paid: cost, refund, mount })
    } else {
        pilot.cash += u64::from(cost);
        Err(Refused::AtLimit)
    }
}

/// [`buy`] from the equipment panel of a system with internal tech level `tech_level`: an item
/// the system does not offer is refused first, as leaving the panel would (deliberate
/// difference 12).
pub fn buy_offered(pilot: &mut Pilot, tech_level: u8, item: Item, mount: Option<Mount>) -> Result<Bought, Refused> {
    if !is_offered(item, tech_level) {
        return Err(Refused::NotOffered);
    }
    buy(pilot, item, mount)
}

/// Sets a value to its fitted value unless it already has it; true when it changed.
fn fit(value: &mut u8, fitted: u8) -> bool {
    let changed = *value != fitted;
    *value = fitted;
    changed
}

fn fit_flag(flag: &mut bool) -> bool {
    let changed = !*flag;
    *flag = true;
    changed
}

/// The laser type's name on the status screen (GDD § 4.8), or `None` for an empty mount.
pub fn laser_name(laser: u8) -> Option<&'static str> {
    match laser {
        NO_LASER => None,
        l if l & BEAM_BIT != 0 => Some("Lance"),
        _ => Some("Repeater"),
    }
}

/// The pilot-state part of an escape-pod rescue (RULES A.12.4, C.10.5), for when the pilot was
/// not in mis-jump space: the hold is emptied, legal status becomes 0, the pod is used up and
/// the tank is filled. Cash, kills, missiles and the other equipment are kept.
pub fn escape_pod_rescue(pilot: &mut Pilot) {
    pilot.cargo = [0; crate::capabilities::pilot::GOODS];
    pilot.legal = 0;
    pilot.fitted.escape_pod = false;
    pilot.fuel = FULL_TANK;
}

/// Fuel scooping at the sun, once the flight rules have found the scooping tick (RULES A.12.4,
/// B.15.2): with the fuel scoop fitted, fuel `← min(70, fuel + ⌊speed / 8⌋)`. Returns true when
/// the scoop is fitted, which is when the scooping message shows, even if nothing was gained.
pub fn scoop_sun_fuel(pilot: &mut Pilot, speed: u8) -> bool {
    if !pilot.fitted.fuel_scoop {
        return false;
    }
    pilot.fuel = (pilot.fuel + speed / 8).min(FULL_TANK);
    true
}

/// How much the energy bank gains at each recharge step: 2 with the energy booster, else 1
/// (RULES A.12.4, C.10.1).
pub fn energy_recharge(pilot: &Pilot) -> u8 {
    if pilot.fitted.energy_booster {
        2
    } else {
        1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rich() -> Pilot {
        let mut pilot = Pilot::start();
        pilot.cash = 1_000_000;
        pilot
    }

    #[test]
    fn the_list_is_in_fixed_order_with_gdd_names() {
        let names: Vec<&str> = Item::ALL.iter().map(|i| i.name()).collect();
        assert_eq!(
            names,
            [
                "Tank refill", "Dart missile", "Cargo sponsons", "Scrambler unit", "Repeater laser",
                "Lance laser", "Corona scoop", "Lifeboat", "Nova charge", "Booster cells",
                "Auto-berth", "Reach drive",
            ]
        );
        for (n, item) in Item::ALL.iter().enumerate() {
            assert_eq!(item.number(), n);
            assert_eq!(Item::from_number(n), Some(*item));
        }
        assert_eq!(Item::from_number(12), None);
        assert_eq!(Item::EscapePod.hud_tag(), Some("BOAT"));
        assert_eq!(Item::Fuel.hud_tag(), None);
    }

    #[test]
    fn availability_by_tech_level() {
        assert_eq!(offered(0), &Item::ALL[..3]);
        assert_eq!(offered(1).last(), Some(&Item::Ecm));
        assert_eq!(offered_count(8), 11);
        assert_eq!(offered_count(9), 12, "all twelve from T = 9 (shown 10)");
        assert_eq!(offered_count(14), 12);
        assert_eq!(offered_count(255), 12);
        // Lowest shown tech level per item (GDD § 5.3): item n from shown max(1, n − 1).
        for item in Item::ALL {
            let lowest = (0..15).find(|&t| is_offered(item, t)).unwrap();
            assert_eq!(usize::from(lowest) + 1, item.number().saturating_sub(1).max(1), "{item:?}");
        }
    }

    #[test]
    fn prices_follow_the_gdd() {
        let pilot = Pilot::start();
        let prices: Vec<u32> = Item::ALL.iter().map(|&i| price(i, &pilot)).collect();
        assert_eq!(prices, [0, 350, 3600, 5600, 3200, 9600, 4800, 8800, 7600, 13600, 12400, 45000]);
    }

    #[test]
    fn fuel_price_is_recomputed_from_the_tank() {
        let mut pilot = Pilot::start();
        pilot.fuel = 0;
        assert_eq!(price(Item::Fuel, &pilot), 210);
        pilot.fuel = 43;
        assert_eq!(price(Item::Fuel, &pilot), 81);
        pilot.fuel = 70;
        assert_eq!(price(Item::Fuel, &pilot), 0);
        assert_eq!(listing(0, &pilot), vec![(Item::Fuel, 0), (Item::Missile, 350), (Item::HoldExtension, 3600)]);
    }

    #[test]
    fn fuel_on_a_full_tank_costs_nothing_and_is_bought() {
        let mut pilot = Pilot::start();
        pilot.cash = 0;
        assert_eq!(buy(&mut pilot, Item::Fuel, None), Ok(Bought { item: Item::Fuel, paid: 0, refund: 0, mount: None }));
        pilot.fuel = 12;
        pilot.cash = 1_000;
        buy(&mut pilot, Item::Fuel, None).unwrap();
        assert_eq!((pilot.fuel, pilot.cash), (70, 1_000 - 174));
    }

    #[test]
    fn not_enough_cash_changes_nothing() {
        let mut pilot = Pilot::start();
        pilot.cash = 349;
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, Item::Missile, None), Err(Refused::NotEnoughCash));
        assert_eq!(pilot, before);
        pilot.cash = 350;
        pilot.missiles = 0;
        assert!(buy(&mut pilot, Item::Missile, None).is_ok(), "exactly enough is enough");
        assert_eq!(pilot.cash, 0);
    }

    #[test]
    fn missiles_stop_at_four() {
        let mut pilot = rich();
        assert!(buy(&mut pilot, Item::Missile, None).is_ok());
        assert_eq!(pilot.missiles, 4);
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, Item::Missile, None), Err(Refused::AtLimit));
        assert_eq!(pilot, before, "the price is given back");
    }

    #[test]
    fn hold_extension_once() {
        let mut pilot = rich();
        buy(&mut pilot, Item::HoldExtension, None).unwrap();
        assert_eq!(pilot.hold, 37);
        assert!(pilot.has_hold_extension());
        assert_eq!(pilot.cash, 1_000_000 - 3_600);
        assert_eq!(buy(&mut pilot, Item::HoldExtension, None), Err(Refused::AtLimit));
        assert_eq!(pilot.cash, 1_000_000 - 3_600);
    }

    #[test]
    fn fitted_flags_once_each() {
        type IsFitted = fn(&Pilot) -> bool;
        let cases: [(Item, IsFitted); 7] = [
            (Item::Ecm, |p| p.fitted.ecm),
            (Item::FuelScoop, |p| p.fitted.fuel_scoop),
            (Item::EscapePod, |p| p.fitted.escape_pod),
            (Item::AreaBlast, |p| p.fitted.area_blast),
            (Item::EnergyBooster, |p| p.fitted.energy_booster),
            (Item::AutoDock, |p| p.fitted.auto_dock),
            (Item::GalaxyDrive, |p| p.fitted.galaxy_drive),
        ];
        for (item, is_fitted) in cases {
            let mut pilot = rich();
            assert!(!is_fitted(&pilot));
            let bought = buy(&mut pilot, item, Some(2)).unwrap();
            assert_eq!(bought.mount, None, "the mount is ignored for {item:?}");
            assert!(is_fitted(&pilot));
            assert_eq!(pilot.cash, 1_000_000 - u64::from(item.fixed_price()));
            let before = pilot.clone();
            assert_eq!(buy(&mut pilot, item, None), Err(Refused::AtLimit));
            assert_eq!(pilot, before);
        }
    }

    #[test]
    fn pulse_laser_needs_an_empty_mount() {
        let mut pilot = rich();
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, Item::PulseLaser, Some(0)), Err(Refused::AtLimit), "mount 0 has a pulse");
        assert_eq!(pilot, before);
        let bought = buy(&mut pilot, Item::PulseLaser, Some(1)).unwrap();
        assert_eq!(bought, Bought { item: Item::PulseLaser, paid: 3_200, refund: 0, mount: Some(1) });
        assert_eq!(pilot.lasers, [PULSE_LASER, PULSE_LASER, NO_LASER, NO_LASER]);
        pilot.lasers[2] = BEAM_LASER;
        assert_eq!(buy(&mut pilot, Item::PulseLaser, Some(2)), Err(Refused::AtLimit), "any laser refuses");
    }

    #[test]
    fn beam_laser_refunds_a_pulse_and_refuses_a_beam() {
        let mut pilot = rich();
        let bought = buy(&mut pilot, Item::BeamLaser, Some(0)).unwrap();
        assert_eq!(bought.refund, 3_200);
        assert_eq!(pilot.lasers[0], BEAM_LASER);
        assert_eq!(pilot.cash, 1_000_000 - 9_600 + 3_200, "the upgrade costs 640.0 net");
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, Item::BeamLaser, Some(0)), Err(Refused::AtLimit));
        assert_eq!(pilot, before);
        let bought = buy(&mut pilot, Item::BeamLaser, Some(3)).unwrap();
        assert_eq!(bought.refund, 0, "no refund on an empty mount");
        assert_eq!(pilot.lasers, [BEAM_LASER, NO_LASER, NO_LASER, BEAM_LASER]);
    }

    #[test]
    fn the_beam_cash_check_uses_the_full_price() {
        let mut pilot = Pilot::start();
        pilot.cash = 9_599;
        // With the refund it would cost 6,400, but the check is on 9,600 (RULES A.14 item 12).
        assert_eq!(buy(&mut pilot, Item::BeamLaser, Some(0)), Err(Refused::NotEnoughCash));
        assert_eq!(pilot.lasers[0], PULSE_LASER);
    }

    #[test]
    fn a_laser_needs_one_of_the_four_mounts() {
        let mut pilot = rich();
        let before = pilot.clone();
        assert_eq!(buy(&mut pilot, Item::PulseLaser, None), Err(Refused::NoMount));
        assert_eq!(buy(&mut pilot, Item::BeamLaser, Some(4)), Err(Refused::NoMount));
        assert_eq!(pilot, before);
        pilot.cash = 0;
        assert_eq!(buy(&mut pilot, Item::BeamLaser, None), Err(Refused::NotEnoughCash), "cash is checked first");
    }

    #[test]
    fn the_panel_refuses_items_not_offered_and_stays_usable() {
        let mut pilot = rich();
        assert_eq!(buy_offered(&mut pilot, 0, Item::Ecm, None), Err(Refused::NotOffered));
        assert_eq!(buy_offered(&mut pilot, 1, Item::Ecm, None).map(|b| b.item), Ok(Item::Ecm));
        // After a refusal the next purchase goes through as normal.
        assert_eq!(buy_offered(&mut pilot, 9, Item::Ecm, None), Err(Refused::AtLimit));
        assert!(buy_offered(&mut pilot, 9, Item::GalaxyDrive, None).is_ok());
    }

    #[test]
    fn laser_names_and_mounts() {
        assert_eq!(laser_name(NO_LASER), None);
        assert_eq!(laser_name(PULSE_LASER), Some("Repeater"));
        assert_eq!(laser_name(BEAM_LASER), Some("Lance"));
        assert_eq!(MOUNT_NAMES, ["Fore", "Aft", "Port", "Starboard"]);
        assert_eq!(MOUNT_TAGS, ["FWD", "AFT", "PORT", "STBD"]);
    }

    #[test]
    fn escape_pod_rescue_keeps_cash_kills_and_other_equipment() {
        let mut pilot = rich();
        pilot.cargo[3] = 5;
        pilot.cargo[14] = 9;
        pilot.legal = 80;
        pilot.fuel = 10;
        pilot.kills = 77;
        pilot.missiles = 2;
        pilot.fitted.escape_pod = true;
        pilot.fitted.ecm = true;
        escape_pod_rescue(&mut pilot);
        assert_eq!(pilot.cargo, [0; 17]);
        assert_eq!((pilot.legal, pilot.fuel, pilot.fitted.escape_pod), (0, 70, false));
        assert_eq!((pilot.cash, pilot.kills, pilot.missiles, pilot.fitted.ecm), (1_000_000, 77, 2, true));
    }

    #[test]
    fn sun_scooping_needs_the_scoop_and_caps_at_full() {
        let mut pilot = Pilot::start();
        pilot.fuel = 30;
        assert!(!scoop_sun_fuel(&mut pilot, 40));
        assert_eq!(pilot.fuel, 30);
        pilot.fitted.fuel_scoop = true;
        assert!(scoop_sun_fuel(&mut pilot, 7), "the message shows even for no gain");
        assert_eq!(pilot.fuel, 30);
        assert!(scoop_sun_fuel(&mut pilot, 40));
        assert_eq!(pilot.fuel, 35);
        pilot.fuel = 68;
        scoop_sun_fuel(&mut pilot, 23);
        assert_eq!(pilot.fuel, 70);
    }

    #[test]
    fn booster_doubles_the_recharge() {
        let mut pilot = Pilot::start();
        assert_eq!(energy_recharge(&pilot), 1);
        pilot.fitted.energy_booster = true;
        assert_eq!(energy_recharge(&pilot), 2);
    }
}
