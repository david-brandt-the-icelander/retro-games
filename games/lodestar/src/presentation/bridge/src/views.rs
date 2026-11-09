//! What the panels and the picture read, worked out from the sim in plain Rust so it can be
//! tested without Godot. `SimHost` converts these to Godot types and does nothing else.
//!
//! Every value is read from the sim's public state; nothing here changes it or draws a random
//! number. Words are the presentation's text table's, except the GDD data the sim already holds
//! (goods, equipment, systems, economies, governments, Reaches), which is read from the sim.

use lodestar_core::capabilities::bubble::Bubble;
use lodestar_core::capabilities::cockpit::Message;
use lodestar_core::capabilities::combat::in_sights;
use lodestar_core::capabilities::equipment::{self, Item};
use lodestar_core::capabilities::market::{self, TABLE};
use lodestar_core::capabilities::pilot::{LegalLabel, Pilot, GOODS};
use lodestar_core::capabilities::ships::{self, TypeNumber};
use lodestar_core::capabilities::space::Vec3;
use lodestar_core::capabilities::universe::{distance, Galaxy, Point, System};
use lodestar_core::features::hyperspace::{galaxy, Destination};
use lodestar_core::features::trading;
use lodestar_core::use_cases::fly_in_system::{FlyInSystem, Mode, Press, Screen, TunnelKind};
use lodestar_core::features::hyperspace::Tunnel;

/// Metres per sim unit (docs/DESIGN.md § Architecture, Coordinates).
pub const UNIT_M: f64 = 0.2;

/// The mode as the scenes name it.
pub fn mode_name(mode: Mode) -> &'static str {
    match mode {
        Mode::Title => "title",
        Mode::Docked => "docked",
        Mode::Tunnel { kind: TunnelKind::Launch, .. } => "tunnel_launch",
        Mode::Tunnel { kind: TunnelKind::Docking, .. } => "tunnel_dock",
        Mode::Tunnel { kind: TunnelKind::Hyperspace(Tunnel::Misjump), .. } => "tunnel_misjump",
        Mode::Tunnel { kind: TunnelKind::Hyperspace(Tunnel::Galactic), .. } => "tunnel_galactic",
        Mode::Tunnel { kind: TunnelKind::Hyperspace(Tunnel::Arrival(_)), .. } => "tunnel_jump",
        Mode::Flight => "flight",
        Mode::Dying(_) => "dying",
        Mode::Escape(_) => "escape",
    }
}

/// The step a tunnel is on (0..15), or the ticks a death or an escape has left; 0 otherwise.
pub fn mode_count(mode: Mode) -> u8 {
    match mode {
        Mode::Tunnel { steps, .. } => steps,
        Mode::Dying(dying) => dying.ticks_left(),
        Mode::Escape(escape) => escape.ticks_left(),
        _ => 0,
    }
}

/// What killed the player, for the death panel's epitaph, while dying.
pub fn death_cause(mode: Mode) -> &'static str {
    use lodestar_core::features::death::Cause;
    match mode {
        Mode::Dying(dying) => match dying.cause {
            Cause::Crashed => "crashed",
            Cause::Burned => "burned",
            Cause::Docking => "docking",
            Cause::Damage => "damage",
            Cause::EscapeInTheDeep => "escape_in_the_deep",
        },
        _ => "",
    }
}

const SCREENS: [(Screen, &str); 8] = [
    (Screen::Space, "space"),
    (Screen::GalaxyChart, "galaxy"),
    (Screen::LocalChart, "local"),
    (Screen::SystemData, "system"),
    (Screen::Status, "status"),
    (Screen::Market, "market"),
    (Screen::Inventory, "inventory"),
    (Screen::Equipment, "equipment"),
];

pub fn screen_name(screen: Screen) -> &'static str {
    SCREENS.iter().find(|(s, _)| *s == screen).map_or("space", |(_, n)| n)
}

pub fn screen_from_name(name: &str) -> Option<Screen> {
    SCREENS.iter().find(|(_, n)| *n == name).map(|(s, _)| *s)
}

/// The presses that take no argument, by the name the scenes use.
pub fn press_from_name(name: &str) -> Option<Press> {
    Some(match name {
        "start" => Press::Start,
        "launch" => Press::Launch,
        "hyperspace" => Press::Hyperspace,
        "galaxy_drive" => Press::GalaxyDrive,
        "unarm_missile" => Press::UnarmMissile,
        "arm_missile" => Press::ArmMissile,
        "fire_missile" => Press::FireMissile,
        "area_blast" => Press::AreaBlast,
        "escape_pod" => Press::EscapePod,
        "in_system_jump" => Press::InSystemJump,
        "ecm" => Press::Ecm,
        "auto_dock" => Press::AutoDock,
        "pause" => Press::Pause,
        "resume" => Press::Resume,
        "quit" => Press::Quit,
        "toggle_auto_centre" => Press::ToggleAutoCentre,
        "toggle_damping" => Press::ToggleDamping,
        _ => return None,
    })
}

/// The condition code of RULES D.6.2: 0 docked; 1 when the bubble holds nothing but the planet,
/// the sun or station and asteroids (entries − 2 − asteroids ≤ 0); else 2 with energy ≥ 128,
/// else 3.
pub fn condition(sim: &FlyInSystem) -> u8 {
    if matches!(sim.mode(), Mode::Docked | Mode::Title) {
        return 0;
    }
    let bubble = sim.bubble();
    let others = bubble.len() as i32 - 2 - i32::from(bubble.count_of(ships::ASTEROID));
    if others <= 0 {
        1
    } else if sim.cockpit().energy >= 128 {
        2
    } else {
        3
    }
}

/// Legal standing: 0 clean, 1 offender, 2 fugitive (RULES A.7.2).
pub fn legal_index(pilot: &Pilot) -> u8 {
    match pilot.legal_label() {
        LegalLabel::Clean => 0,
        LegalLabel::Offender => 1,
        LegalLabel::Fugitive => 2,
    }
}

/// One object of the bubble as the picture draws it.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ObjectView {
    pub slot: usize,
    pub kind: TypeNumber,
    /// Sim units, relative to the player (x right, y up, z forward).
    pub position: Vec3,
    pub nose: Vec3,
    pub roof: Vec3,
    pub exploding: bool,
    pub killed: bool,
    /// The ship fired its laser at the player this tick.
    pub firing: bool,
    /// The explosion cloud's counter while exploding.
    pub cloud: u8,
    /// In the active mount's line of fire by the sim's own sights test (RULES C.6.3).
    pub in_sights: bool,
    /// The player's missile is locked on it.
    pub locked: bool,
    /// A missile flying at the player (AI bit 6).
    pub hostile_missile: bool,
}

/// The bubble's objects, in slot order.
pub fn objects(sim: &FlyInSystem) -> Vec<ObjectView> {
    let cockpit = sim.cockpit();
    let mount = cockpit.active_mount;
    bubble_views(sim.bubble(), mount, cockpit.missile.target)
}

fn bubble_views(bubble: &Bubble, mount: usize, locked: Option<usize>) -> Vec<ObjectView> {
    bubble
        .iter()
        .enumerate()
        .map(|(slot, o)| ObjectView {
            slot,
            kind: o.kind,
            position: o.position,
            nose: o.nose,
            roof: o.roof,
            exploding: o.flags.exploding,
            killed: o.flags.killed,
            firing: o.flags.firing,
            cloud: o.explosion.counter,
            in_sights: in_sights(o, mount),
            locked: locked == Some(slot),
            hostile_missile: o.kind == ships::MISSILE && o.ai & 0x40 != 0,
        })
        .collect()
}

/// One row of the market panel (RULES A.9, deliberate difference 12).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MarketRow {
    pub item: usize,
    pub name: &'static str,
    pub unit: &'static str,
    /// Tenths of a credit per unit at this visit.
    pub price: u16,
    pub available: u8,
    pub held: u32,
    /// The stepper's limits.
    pub max_buy: u8,
    pub max_sell: u32,
    /// Takes hold space (items 0..12).
    pub bulky: bool,
    /// This economy pays more than the scale's middle for it (the panel's trend arrow).
    pub dear_here: bool,
}

/// The market panel's 17 rows at the current system.
pub fn market_rows(sim: &FlyInSystem) -> Vec<MarketRow> {
    let pilot = sim.pilot();
    let economy = sim.navigation().current_system(pilot).economy;
    rows_at(pilot, economy)
}

fn rows_at(pilot: &Pilot, economy: u8) -> Vec<MarketRow> {
    (0..GOODS)
        .map(|item| {
            let goods = &TABLE[item];
            // A positive gradient prices rise with the economy code (dear at farm worlds).
            let farm = economy >= 4;
            let dear_here = (goods.gradient > 0) == farm && goods.gradient != 0;
            MarketRow {
                item,
                name: goods.name,
                unit: goods.unit.symbol(),
                price: market::price(item, economy, pilot.market_byte),
                available: pilot.availability[item],
                held: pilot.cargo[item],
                max_buy: trading::max_buy(pilot, item, economy),
                max_sell: trading::max_sell(pilot, item),
                bulky: market::takes_hold_space(item),
                dear_here,
            }
        })
        .collect()
}

/// One row of the equipment panel.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EquipmentRow {
    pub item: usize,
    pub name: &'static str,
    /// Tenths of a credit, now.
    pub price: u32,
    pub laser: bool,
    /// A short state: how many carried, or whether fitted.
    pub fitted: String,
}

/// The items the current system offers (RULES A.12.2), with their prices now.
pub fn equipment_rows(sim: &FlyInSystem) -> Vec<EquipmentRow> {
    let pilot = sim.pilot();
    let tech = sim.navigation().current_system(pilot).tech_level;
    equipment::listing(tech, pilot)
        .into_iter()
        .map(|(item, price)| EquipmentRow {
            item: item.number(),
            name: item.name(),
            price,
            laser: item.is_laser(),
            fitted: fitted_state(pilot, item),
        })
        .collect()
}

fn fitted_state(pilot: &Pilot, item: Item) -> String {
    let f = &pilot.fitted;
    let yes = |on: bool| if on { "fitted".to_string() } else { String::new() };
    match item {
        Item::Fuel => format!("{}.{} LY", pilot.fuel / 10, pilot.fuel % 10),
        Item::Missile => format!("{} of 4", pilot.missiles),
        Item::HoldExtension => yes(pilot.has_hold_extension()),
        Item::Ecm => yes(f.ecm),
        Item::PulseLaser | Item::BeamLaser => {
            let tags: Vec<&str> = (0..4)
                .filter(|&m| match item {
                    Item::BeamLaser => pilot.lasers[m] & 0x80 != 0,
                    _ => pilot.lasers[m] != 0 && pilot.lasers[m] & 0x80 == 0,
                })
                .map(|m| equipment::MOUNT_TAGS[m])
                .collect();
            tags.join(" ")
        }
        Item::FuelScoop => yes(f.fuel_scoop),
        Item::EscapePod => yes(f.escape_pod),
        Item::AreaBlast => yes(f.area_blast),
        Item::EnergyBooster => yes(f.energy_booster),
        Item::AutoDock => yes(f.auto_dock),
        Item::GalaxyDrive => yes(f.galaxy_drive),
    }
}

/// The status screen's equipment lines, in RULES D.6.2's order: the hold extension, scoop,
/// E.C.M., area blast, booster, auto-dock, galaxy drive, then each mount's laser.
pub fn status_equipment(pilot: &Pilot) -> Vec<String> {
    let f = &pilot.fitted;
    let mut lines: Vec<String> = [
        (pilot.has_hold_extension(), Item::HoldExtension),
        (f.fuel_scoop, Item::FuelScoop),
        (f.ecm, Item::Ecm),
        (f.area_blast, Item::AreaBlast),
        (f.energy_booster, Item::EnergyBooster),
        (f.auto_dock, Item::AutoDock),
        (f.galaxy_drive, Item::GalaxyDrive),
    ]
    .iter()
    .filter(|(on, _)| *on)
    .map(|(_, item)| item.name().to_string())
    .collect();
    for (mount, &laser) in pilot.lasers.iter().enumerate() {
        if let Some(kind) = equipment::laser_name(laser) {
            lines.push(format!("{} {} laser", equipment::MOUNT_NAMES[mount], kind));
        }
    }
    lines
}

/// A timed message as an id for the text table and its one data field (a goods or equipment
/// name, or the cash in tenths as digits).
pub fn message_parts(message: Message) -> (&'static str, String) {
    match message {
        Message::FuelScooping => ("scoop_fuel", String::new()),
        Message::EnergyLow => ("energy_low", String::new()),
        Message::KillPraise => ("kill_milestone", String::new()),
        Message::IncomingMissile => ("missile_in", String::new()),
        Message::MissileJammed => ("missile_jammed", String::new()),
        Message::TargetLost => ("target_lost", String::new()),
        Message::GalacticJump => ("reach_jump", String::new()),
        Message::Bounty { cash } => ("bounty", cash.to_string()),
        Message::Scooped { item } => ("scooped", goods_name(item).to_string()),
        Message::CargoLost { item } => ("cargo_lost", goods_name(item).to_string()),
        Message::EquipmentLost { roll } => ("equipment_lost", lost_equipment(roll).name().to_string()),
    }
}

fn goods_name(item: usize) -> &'static str {
    TABLE.get(item).map_or("", |g| g.name)
}

/// The equipment a loss roll of 17..21 names (RULES C.10.3).
pub fn lost_equipment(roll: u8) -> Item {
    match roll.saturating_sub(GOODS as u8) {
        0 => Item::Ecm,
        1 => Item::FuelScoop,
        2 => Item::AreaBlast,
        3 => Item::EnergyBooster,
        _ => Item::AutoDock,
    }
}

/// A system as the data panel and the charts show it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SystemView {
    pub index: u8,
    pub name: String,
    pub position: Point,
    /// Tenths of a light year from the pilot.
    pub distance: u16,
    pub economy: u8,
    pub government: u8,
    /// As shown, 1..15.
    pub tech_level: u8,
    /// Tenths of a billion.
    pub population: u8,
    pub productivity: u16,
    pub radius: u16,
    pub inhabitants: String,
    pub dot_width: u8,
}

pub fn system_view(system: &System, pilot: Point) -> SystemView {
    SystemView {
        index: system.index,
        name: system.name.clone(),
        position: system.position(),
        distance: distance(pilot, system.position()),
        economy: system.economy,
        government: system.government,
        tech_level: system.shown_tech_level(),
        population: system.population,
        productivity: system.productivity,
        radius: system.radius,
        inhabitants: system.inhabitants.clone(),
        dot_width: system.chart_dot_width(),
    }
}

/// The pilot's galaxy.
pub fn pilot_galaxy(sim: &FlyInSystem) -> Galaxy {
    galaxy(sim.pilot())
}

/// The selected system (the hyperspace destination's candidate, RULES A.5.1).
pub fn selected_system(sim: &FlyInSystem) -> SystemView {
    let pilot = sim.pilot();
    let system = pilot_galaxy(sim).system(sim.selected().system);
    system_view(&system, pilot.position)
}

/// The current system (its data and market stay as they were in the Deep, RULES D.3.8).
pub fn current_system(sim: &FlyInSystem) -> SystemView {
    let pilot = sim.pilot();
    system_view(&sim.navigation().current_system(pilot), pilot.position)
}

/// The system nearest a chart point, with its distance from the pilot; it selects nothing.
pub fn nearest_system(sim: &FlyInSystem, point: Point) -> SystemView {
    let g = pilot_galaxy(sim);
    system_view(&g.system(g.nearest(point)), sim.pilot().position)
}

/// The current system's name, blank in the Deep (RULES D.3.8).
pub fn current_name(sim: &FlyInSystem) -> String {
    if sim.cockpit().misjump {
        String::new()
    } else {
        sim.navigation().current_system(sim.pilot()).name
    }
}

/// Where a running countdown leads: the system's name, or empty for a Reach jump.
pub fn countdown_target(sim: &FlyInSystem) -> Option<String> {
    sim.countdown().destination().map(|d| match d {
        Destination::System(selection) => pilot_galaxy(sim).system(selection.system).name,
        Destination::NextGalaxy => String::new(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use lodestar_core::use_cases::fly_in_system::{start_pilot, InputRecord};

    fn press(sim: &mut FlyInSystem, p: Press) {
        sim.tick(&InputRecord { presses: vec![p], ..Default::default() });
    }

    fn docked() -> FlyInSystem {
        let mut sim = FlyInSystem::new();
        press(&mut sim, Press::Start);
        sim
    }

    #[test]
    fn the_title_and_docked_modes_are_named_and_condition_0() {
        let mut sim = FlyInSystem::new();
        assert_eq!(mode_name(sim.mode()), "title");
        assert_eq!(condition(&sim), 0);
        press(&mut sim, Press::Start);
        assert_eq!(mode_name(sim.mode()), "docked");
        assert_eq!(screen_name(sim.screen()), "status");
        assert_eq!(condition(&sim), 0);
    }

    #[test]
    fn launching_runs_the_tunnel_then_flight_near_the_station() {
        let mut sim = docked();
        press(&mut sim, Press::Launch);
        assert_eq!(mode_name(sim.mode()), "tunnel_launch");
        for _ in 0..16 {
            sim.tick(&InputRecord::default());
        }
        assert_eq!(mode_name(sim.mode()), "flight");
        // Planet and station only: entries − 2 − asteroids = 0, condition 1 (RULES D.6.2).
        assert_eq!(objects(&sim).len(), 2);
        assert_eq!(objects(&sim)[1].kind, ships::STATION);
        assert_eq!(condition(&sim), 1);
    }

    #[test]
    fn screen_and_press_names_round_trip() {
        for (screen, name) in SCREENS {
            assert_eq!(screen_from_name(name), Some(screen));
            assert_eq!(screen_name(screen), name);
        }
        assert_eq!(screen_from_name("nowhere"), None);
        assert_eq!(press_from_name("auto_dock"), Some(Press::AutoDock));
        assert_eq!(press_from_name("buy"), None);
    }

    #[test]
    fn the_start_market_rows_match_the_gdd_vectors() {
        // GDD § 5.2: the start market's availability and prices (tenths).
        let available = [27, 30, 15, 0, 36, 14, 2, 0, 0, 18, 0, 0, 45, 25, 9, 26, 0];
        let prices = [60, 80, 196, 112, 112, 600, 440, 728, 492, 296, 620, 460, 164, 452, 716, 224, 380];
        let rows = market_rows(&docked());
        assert_eq!(rows.len(), GOODS);
        for row in &rows {
            assert_eq!(row.available, available[row.item], "{}", row.name);
            assert_eq!(row.price, prices[row.item], "{}", row.name);
            assert_eq!(row.held, 0);
        }
        assert_eq!((rows[0].name, rows[0].unit), ("Grain", "t"));
        assert_eq!((rows[13].unit, rows[13].bulky), ("kg", false));
        // 100.0 scrip at 6.0 a tonne buys 16 t of grain; 27 are on sale and the hold takes 22.
        assert_eq!(rows[0].max_buy, 16);
        // Grain's gradient is negative: cheap at farm worlds, so not dear at the start (economy 5).
        assert!(!rows[0].dear_here);
        assert!(rows[5].dear_here, "medicines are dear at a farm world");
    }

    #[test]
    fn buying_shows_in_the_rows_and_the_hold() {
        let mut sim = docked();
        press(&mut sim, Press::Buy { item: 0, quantity: 10 });
        let row = &market_rows(&sim)[0];
        assert_eq!((row.held, row.available, row.max_sell), (10, 17, 10));
        assert_eq!(sim.pilot().cash, 1000 - 600);
        // 40.0 scrip left buys 6 more at 6.0.
        assert_eq!(row.max_buy, 6);
    }

    #[test]
    fn the_start_system_offers_equipment_by_tech_level() {
        let sim = docked();
        let rows = equipment_rows(&sim);
        // Tech level 6 shown is internal 5: min(5 + 3, 12) = 8 items.
        assert_eq!(rows.len(), 8);
        assert_eq!(rows[0].name, "Tank refill");
        assert_eq!(rows[0].price, 0, "a full tank costs nothing");
        assert_eq!(rows[1].fitted, "3 of 4");
        assert_eq!(rows[4].fitted, "FWD", "the repeater is on the fore mount");
        assert!(rows[4].laser && rows[5].laser && !rows[6].laser);
    }

    #[test]
    fn the_status_lists_equipment_in_rules_order_then_lasers() {
        let mut pilot = start_pilot();
        assert_eq!(status_equipment(&pilot), vec!["Fore Repeater laser".to_string()]);
        pilot.fitted.ecm = true;
        pilot.fitted.fuel_scoop = true;
        pilot.hold = 37;
        pilot.lasers[2] = 143;
        assert_eq!(
            status_equipment(&pilot),
            vec!["Cargo sponsons", "Corona scoop", "Scrambler unit", "Fore Repeater laser", "Port Lance laser"]
        );
    }

    #[test]
    fn messages_carry_their_data() {
        assert_eq!(message_parts(Message::Scooped { item: 3 }), ("scooped", "Bonded sleepers".into()));
        assert_eq!(message_parts(Message::Bounty { cash: 1234 }), ("bounty", "1234".into()));
        assert_eq!(message_parts(Message::EquipmentLost { roll: 17 }).1, "Scrambler unit");
        assert_eq!(message_parts(Message::EquipmentLost { roll: 21 }).1, "Auto-berth");
        assert_eq!(lost_equipment(19), Item::AreaBlast);
    }

    #[test]
    fn the_start_system_is_current_and_selected_at_distance_0() {
        let sim = docked();
        let selected = selected_system(&sim);
        assert_eq!(selected.position, (60, 93));
        assert_eq!(selected.distance, 0);
        assert_eq!(selected.tech_level, 6);
        assert_eq!(selected.economy, 5);
        assert_eq!(current_name(&sim), selected.name);
        assert_eq!(countdown_target(&sim), None);
    }

    #[test]
    fn the_nearest_system_to_a_point_selects_nothing() {
        let sim = docked();
        let near = nearest_system(&sim, (0, 0));
        assert_ne!(near.position, (60, 93));
        assert!(near.distance > 0);
        assert_eq!(sim.selected().position, (60, 93));
    }

    #[test]
    fn lasers_in_sights_follow_the_active_mount() {
        use lodestar_core::capabilities::bubble::Object;
        let mut bubble = Bubble::new();
        bubble.add(Object::new(ships::TRADER, Vec3::new(0.0, 0.0, 1000.0)));
        bubble.add(Object::new(ships::TRADER, Vec3::new(0.0, 0.0, -1000.0)));
        let front = bubble_views(&bubble, 0, Some(1));
        assert!(front[0].in_sights && !front[1].in_sights);
        assert!(!front[0].locked && front[1].locked);
        let rear = bubble_views(&bubble, 1, None);
        assert!(!rear[0].in_sights && rear[1].in_sights);
    }

    #[test]
    fn mode_counts_follow_the_tunnel_steps() {
        let mut sim = docked();
        // A launch pressed in substep A draws its first step in the same tick (RULES D.3.4).
        press(&mut sim, Press::Launch);
        assert_eq!(mode_count(sim.mode()), 1);
        sim.tick(&InputRecord::default());
        assert_eq!(mode_count(sim.mode()), 2);
        assert_eq!(death_cause(sim.mode()), "");
    }
}
