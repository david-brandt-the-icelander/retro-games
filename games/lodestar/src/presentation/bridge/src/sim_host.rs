use godot::classes::{Input, ProjectSettings};
use godot::prelude::*;
use lodestar_core::capabilities::equipment::{Item, MOUNT_NAMES};
use lodestar_core::capabilities::space::Vec3;
use lodestar_core::capabilities::universe::{local_chart, local_cursor_point, reach_name, Point, Selection};
use lodestar_core::features::hyperspace::{GalaxyDriveKey, HyperspaceKey};
use lodestar_core::features::in_system_jump::InSystemJump;
use lodestar_core::features::saving::{LoadError, SaveOutcome};
use lodestar_core::features::trading::{BuyRefused, SellRefused};
use lodestar_core::capabilities::combat::{Damage, MissileFired};
use lodestar_core::capabilities::equipment::Refused;
use lodestar_core::capabilities::ships::TypeNumber;
use lodestar_core::use_cases::fly_in_system::{
    Event, FlyInSystem, HeldActions, InputRecord, ModeKind, Press, TickClock, TunnelKind,
};
use lodestar_core::features::hyperspace::Tunnel;
use lodestar_infrastructure::PilotFiles;

use crate::views::{self, SystemView, UNIT_M};

/// Where pilot records are kept (docs/DESIGN.md § In-game UI, Saving).
const PILOT_FOLDER: &str = "user://pilots";

/// The held flight actions, by their input-map names (docs/DESIGN.md § Keyboard controls).
const HELD: [&str; 7] = ["dive", "climb", "roll_left", "roll_right", "speed_up", "slow_down", "fire"];

/// One object's pose before the last tick, for interpolation.
#[derive(Clone, Copy)]
struct Pose {
    kind: TypeNumber,
    position: Vec3,
    nose: Vec3,
    roof: Vec3,
}

/// Runs the sim at 12 Hz under Godot's frame loop and is the scenes' only door into it.
///
/// Each frame it samples the held flight actions from Godot's input map, runs as many logic
/// ticks as the elapsed time allows with the presses the scenes queued since the last tick, and
/// emits `ticked` after each tick and `sim_event` for each of the tick's events. The scenes read
/// snapshots (`cockpit`, `objects`, `market_rows` …), interpolating with `alpha()`.
#[derive(GodotClass)]
#[class(base = Node)]
pub struct SimHost {
    base: Base<Node>,
    clock: TickClock,
    sim: FlyInSystem,
    queued: Vec<Press>,
    store: PilotFiles,
    previous: Vec<Pose>,
    /// The last tick changed the mode, so the picture jumps instead of interpolating.
    mode_changed: bool,
    /// When false the clock does not run; a script drives the sim with `advance`.
    running: bool,
}

#[godot_api]
impl INode for SimHost {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            clock: TickClock::new(),
            sim: FlyInSystem::new(),
            queued: Vec::new(),
            store: PilotFiles::new(""),
            previous: Vec::new(),
            mode_changed: true,
            running: true,
        }
    }

    fn ready(&mut self) {
        let folder = ProjectSettings::singleton().globalize_path(PILOT_FOLDER);
        self.store = PilotFiles::new(folder.to_string());
    }

    fn process(&mut self, delta: f64) {
        if !self.running {
            return;
        }
        let ticks = self.clock.advance(delta);
        for _ in 0..ticks {
            self.run_tick();
        }
    }
}

#[godot_api]
impl SimHost {
    /// Emitted after every logic tick, with the number of ticks run so far.
    #[signal]
    fn ticked(tick: i64);

    /// Emitted when the active laser mount changes: 0 fore, 1 aft, 2 port, 3 starboard.
    #[signal]
    fn mount_selected(mount: i64);

    /// Emitted for each event of a tick, in order: `kind` names it and `data` holds its fields.
    #[signal]
    fn sim_event(kind: GString, data: VarDictionary);

    // ---- Commands ----

    /// Queues an action that takes no argument (`start`, `launch`, `hyperspace`, `ecm` …) for
    /// the next tick. Returns false for an unknown name.
    #[func]
    fn press(&mut self, action: GString) -> bool {
        match views::press_from_name(&action.to_string()) {
            Some(press) => {
                self.queued.push(press);
                true
            }
            None => false,
        }
    }

    /// Queues a mount choice: 0 fore, 1 aft, 2 port, 3 starboard.
    #[func]
    fn press_mount(&mut self, mount: i64) {
        if (0..4).contains(&mount) {
            self.queued.push(Press::Mount(mount as u8));
        }
    }

    /// Queues showing a screen: `space`, `galaxy`, `local`, `system`, `status`, `market`,
    /// `inventory` or `equipment`.
    #[func]
    fn show_screen(&mut self, screen: GString) -> bool {
        match views::screen_from_name(&screen.to_string()) {
            Some(s) => {
                self.queued.push(Press::Screen(s));
                true
            }
            None => false,
        }
    }

    /// Queues putting the chart cursor on a galactic point, which selects the nearest system.
    #[func]
    fn move_cursor(&mut self, x: i64, y: i64) {
        self.queued.push(Press::Cursor((x.clamp(0, 255) as u8, y.clamp(0, 255) as u8)));
    }

    /// Queues buying `quantity` of goods `item` at the market panel.
    #[func]
    fn buy(&mut self, item: i64, quantity: i64) {
        if (0..17).contains(&item) {
            self.queued.push(Press::Buy { item: item as usize, quantity: quantity.clamp(0, 255) as u8 });
        }
    }

    /// Queues selling `quantity` of goods `item` at the market panel.
    #[func]
    fn sell(&mut self, item: i64, quantity: i64) {
        if (0..17).contains(&item) {
            self.queued.push(Press::Sell { item: item as usize, quantity: quantity.clamp(0, u32::MAX as i64) as u32 });
        }
    }

    /// Queues buying equipment `item` (0..11); `mount` is 0..3 for a laser, else -1.
    #[func]
    fn equip(&mut self, item: i64, mount: i64) {
        if let Some(item) = Item::from_number(item.max(0) as usize).filter(|_| item >= 0) {
            let mount = (0..4).contains(&mount).then_some(mount as usize);
            self.queued.push(Press::Equip { item, mount });
        }
    }

    /// Saves the playing pilot under `name`, at once (docked only). Returns `saved`,
    /// `not_docked` or `no_name`.
    #[func]
    fn save_pilot(&mut self, name: GString) -> GString {
        let outcome = self.sim.save(&name.to_string(), &mut self.store);
        GString::from(match outcome {
            SaveOutcome::Saved => "saved",
            SaveOutcome::NotDocked => "not_docked",
            SaveOutcome::NoName => "no_name",
        })
    }

    /// Loads the pilot named `name` (empty: the last saved one), at once (title only). Returns
    /// an empty string when loaded, else `not_title`, `not_found` or `rejected`.
    #[func]
    fn load_pilot(&mut self, name: GString) -> GString {
        GString::from(match self.sim.load(&name.to_string(), &self.store) {
            None => "not_title",
            Some(Ok(())) => "",
            Some(Err(LoadError::NotFound)) => "not_found",
            Some(Err(_)) => "rejected",
        })
    }

    /// The names that have a saved record, sorted.
    #[func]
    fn pilot_names(&self) -> PackedStringArray {
        self.store.names().iter().map(|n| GString::from(n.as_str())).collect()
    }

    /// Stops or restarts the real-time clock (a script then drives the sim with `advance`).
    #[func]
    fn set_running(&mut self, running: bool) {
        self.running = running;
    }

    /// Runs `ticks` ticks now, with the held actions as they are, for scripted runs and tests.
    #[func]
    fn advance(&mut self, ticks: i64) {
        for _ in 0..ticks.max(0) {
            self.run_tick();
        }
    }

    // ---- Readouts ----

    /// How far the present frame is between the last tick and the next, 0..1.
    #[func]
    fn alpha(&self) -> f64 {
        self.clock.alpha()
    }

    #[func]
    fn tick_count(&self) -> i64 {
        self.sim.ticks() as i64
    }

    #[func]
    fn active_mount(&self) -> i64 {
        i64::from(self.sim.active_mount())
    }

    /// `title`, `docked`, `tunnel_launch`, `tunnel_dock`, `tunnel_jump`, `tunnel_misjump`,
    /// `tunnel_galactic`, `flight`, `dying` or `escape`.
    #[func]
    fn mode(&self) -> GString {
        GString::from(views::mode_name(self.sim.mode()))
    }

    /// The tunnel's step, or the ticks a death or escape has left.
    #[func]
    fn mode_count(&self) -> i64 {
        i64::from(views::mode_count(self.sim.mode()))
    }

    /// While dying: `crashed`, `burned`, `docking`, `damage` or `escape_in_the_deep`.
    #[func]
    fn death_cause(&self) -> GString {
        GString::from(views::death_cause(self.sim.mode()))
    }

    #[func]
    fn screen(&self) -> GString {
        GString::from(views::screen_name(self.sim.screen()))
    }

    #[func]
    fn paused(&self) -> bool {
        self.sim.paused()
    }

    /// The player's in-flight state, the timed message, the condition and the countdown.
    #[func]
    fn cockpit(&self) -> VarDictionary {
        let c = self.sim.cockpit();
        let a = c.attitude;
        let mut d = VarDictionary::new();
        put(&mut d, "energy", c.energy);
        put(&mut d, "fore_shield", c.fore_shield);
        put(&mut d, "aft_shield", c.aft_shield);
        put(&mut d, "cabin_temperature", c.cabin_temperature);
        put(&mut d, "laser_temperature", c.laser_temperature);
        put(&mut d, "altitude", c.altitude);
        put(&mut d, "speed", c.speed);
        put(&mut d, "roll_angle", a.roll_angle);
        put(&mut d, "pitch_angle", a.pitch_angle);
        put(&mut d, "roll_rate", a.roll_rate);
        put(&mut d, "pitch_rate", a.pitch_rate);
        put(&mut d, "auto_centre", a.auto_centre);
        put(&mut d, "damping", a.damping);
        put(&mut d, "active_mount", c.active_mount as i64);
        put(&mut d, "missile_armed", c.missile.armed);
        put(&mut d, "missile_target", c.missile.target.map_or(-1, |t| t as i64));
        put(&mut d, "ecm_timer", c.ecm_timer);
        put(&mut d, "ecm_own", c.ecm_own);
        put(&mut d, "area_blast", c.area_blast);
        put(&mut d, "station_present", c.station_present);
        put(&mut d, "misjump", c.misjump);
        put(&mut d, "shot", c.shot_damage > 0);
        put(&mut d, "message_timer", c.message_timer);
        let (id, detail) = c.message.map_or(("", String::new()), views::message_parts);
        put(&mut d, "message", id);
        put(&mut d, "message_detail", detail.as_str());
        put(&mut d, "condition", views::condition(&self.sim));
        put(&mut d, "countdown", self.sim.countdown().shown());
        let target = views::countdown_target(&self.sim);
        put(&mut d, "countdown_galactic", target.as_deref() == Some(""));
        put(&mut d, "countdown_target", target.unwrap_or_default().as_str());
        d
    }

    /// The playing pilot: name, cash and fuel (tenths), legal standing, rank, kills, missiles,
    /// hold, lasers per mount, fitted equipment and galaxy.
    #[func]
    fn pilot(&self) -> VarDictionary {
        let p = self.sim.pilot();
        let mut d = VarDictionary::new();
        put(&mut d, "name", p.name.as_str());
        put(&mut d, "cash", p.cash as i64);
        put(&mut d, "fuel", p.fuel);
        put(&mut d, "legal", p.legal);
        put(&mut d, "legal_index", views::legal_index(p));
        put(&mut d, "rank", p.rank());
        put(&mut d, "kills", p.kills);
        put(&mut d, "missiles", p.missiles);
        put(&mut d, "hold", p.hold);
        put(&mut d, "hold_used", lodestar_core::capabilities::market::hold_used(p) as i64);
        let lasers: PackedInt32Array = p.lasers.iter().map(|&l| i32::from(l)).collect();
        put(&mut d, "lasers", lasers);
        let f = &p.fitted;
        let mut fitted = VarDictionary::new();
        put(&mut fitted, "ecm", f.ecm);
        put(&mut fitted, "fuel_scoop", f.fuel_scoop);
        put(&mut fitted, "area_blast", f.area_blast);
        put(&mut fitted, "energy_booster", f.energy_booster);
        put(&mut fitted, "auto_dock", f.auto_dock);
        put(&mut fitted, "galaxy_drive", f.galaxy_drive);
        put(&mut fitted, "escape_pod", f.escape_pod);
        put(&mut fitted, "hold_extension", p.has_hold_extension());
        put(&mut d, "fitted", fitted);
        put(&mut d, "galaxy", p.galaxy);
        put(&mut d, "reach", reach_name(p.galaxy));
        put(&mut d, "position", Vector2i::new(i32::from(p.position.0), i32::from(p.position.1)));
        let equipment: PackedStringArray =
            views::status_equipment(p).iter().map(|s| GString::from(s.as_str())).collect();
        put(&mut d, "equipment", equipment);
        let cargo: PackedInt64Array = p.cargo.iter().map(|&c| i64::from(c)).collect();
        put(&mut d, "cargo", cargo);
        d
    }

    /// The current system's name (blank in the Deep), the chart cursor, the selected system and
    /// the current system (`here`).
    #[func]
    fn navigation(&self) -> VarDictionary {
        let n = self.sim.navigation();
        let mut d = VarDictionary::new();
        put(&mut d, "current_name", views::current_name(&self.sim).as_str());
        put(&mut d, "current", n.current);
        put(&mut d, "cursor", point(n.cursor.position));
        put(&mut d, "selected", system_dict(&views::selected_system(&self.sim)));
        put(&mut d, "here", system_dict(&views::current_system(&self.sim)));
        d
    }

    /// The selected system, as the system-data panel shows it.
    #[func]
    fn system_data(&self) -> VarDictionary {
        system_dict(&views::selected_system(&self.sim))
    }

    /// The system nearest a galactic point, with its distance from the pilot; selects nothing.
    #[func]
    fn nearest_system(&self, x: i64, y: i64) -> VarDictionary {
        system_dict(&views::nearest_system(&self.sim, (x.clamp(0, 255) as u8, y.clamp(0, 255) as u8)))
    }

    /// All 256 systems of the pilot's galaxy: index, name, position, dot width and economy.
    #[func]
    fn galaxy_systems(&self) -> VarArray {
        let galaxy = views::pilot_galaxy(&self.sim);
        let mut out = VarArray::new();
        for system in galaxy.systems() {
            let mut d = VarDictionary::new();
            put(&mut d, "index", system.index);
            put(&mut d, "name", system.name.as_str());
            put(&mut d, "position", point(system.position()));
            put(&mut d, "dot", system.chart_dot_width());
            put(&mut d, "economy", system.economy);
            out.push(&d.to_variant());
        }
        out
    }

    /// The local chart's systems with RULES A.6.2's layout: chart point (on a 256 × 192 grid),
    /// disc radius and label row (-1 for no label).
    #[func]
    fn local_chart(&self) -> VarArray {
        let galaxy = views::pilot_galaxy(&self.sim);
        let pilot = self.sim.pilot().position;
        let mut out = VarArray::new();
        for entry in local_chart(galaxy, pilot) {
            let system = galaxy.system(entry.system);
            let mut d = VarDictionary::new();
            put(&mut d, "index", entry.system);
            put(&mut d, "name", system.name.as_str());
            put(&mut d, "point", Vector2i::new(i32::from(entry.point.0), i32::from(entry.point.1)));
            put(&mut d, "radius", entry.radius);
            put(&mut d, "label_row", entry.label_row.map_or(-1, i64::from));
            out.push(&d.to_variant());
        }
        out
    }

    /// Where the local chart draws a galactic point's cursor cross, or (-1, -1) when hidden.
    #[func]
    fn local_cursor(&self, x: i64, y: i64) -> Vector2i {
        let cursor = (x.clamp(0, 255) as u8, y.clamp(0, 255) as u8);
        local_cursor_point(self.sim.pilot().position, cursor)
            .map_or(Vector2i::new(-1, -1), |(px, py)| Vector2i::new(i32::from(px), i32::from(py)))
    }

    /// The market panel's 17 rows at the current system.
    #[func]
    fn market_rows(&self) -> VarArray {
        let mut out = VarArray::new();
        for row in views::market_rows(&self.sim) {
            let mut d = VarDictionary::new();
            put(&mut d, "item", row.item as i64);
            put(&mut d, "name", row.name);
            put(&mut d, "unit", row.unit);
            put(&mut d, "price", row.price);
            put(&mut d, "available", row.available);
            put(&mut d, "held", i64::from(row.held));
            put(&mut d, "max_buy", row.max_buy);
            put(&mut d, "max_sell", i64::from(row.max_sell));
            put(&mut d, "bulky", row.bulky);
            put(&mut d, "dear_here", row.dear_here);
            out.push(&d.to_variant());
        }
        out
    }

    /// The equipment panel's rows: the items offered here with their prices now.
    #[func]
    fn equipment_rows(&self) -> VarArray {
        let mut out = VarArray::new();
        for row in views::equipment_rows(&self.sim) {
            let mut d = VarDictionary::new();
            put(&mut d, "item", row.item as i64);
            put(&mut d, "name", row.name);
            put(&mut d, "price", i64::from(row.price));
            put(&mut d, "laser", row.laser);
            put(&mut d, "fitted", row.fitted.as_str());
            out.push(&d.to_variant());
        }
        out
    }

    /// The bubble's objects, interpolated `alpha` of the way from the previous tick to the
    /// last: slot, kind, position (metres, Godot axes), basis, and the flags the picture uses.
    #[func]
    fn objects(&self) -> VarArray {
        let alpha = self.clock.alpha();
        let mut out = VarArray::new();
        for o in views::objects(&self.sim) {
            let before = self.previous.get(o.slot).filter(|p| p.kind == o.kind && !self.mode_changed);
            let (position, basis) = match before {
                Some(p) => {
                    let position = p.position + (o.position - p.position) * alpha;
                    let from = basis_of(p.nose, p.roof).get_quaternion();
                    let to = basis_of(o.nose, o.roof).get_quaternion();
                    (position, Basis::from_quaternion(from.slerp(to, alpha as f32)))
                }
                None => (o.position, basis_of(o.nose, o.roof)),
            };
            let mut d = VarDictionary::new();
            put(&mut d, "slot", o.slot as i64);
            put(&mut d, "kind", o.kind);
            put(&mut d, "position", metres(position));
            put(&mut d, "basis", basis);
            put(&mut d, "exploding", o.exploding);
            put(&mut d, "killed", o.killed);
            put(&mut d, "firing", o.firing);
            put(&mut d, "cloud", o.cloud);
            put(&mut d, "in_sights", o.in_sights);
            put(&mut d, "locked", o.locked);
            put(&mut d, "hostile_missile", o.hostile_missile);
            out.push(&d.to_variant());
        }
        out
    }

    /// The mount names in order (GDD § 4.8).
    #[func]
    fn mount_names(&self) -> PackedStringArray {
        MOUNT_NAMES.iter().map(|n| GString::from(*n)).collect()
    }
}

impl SimHost {
    /// One tick: keep the poses, sample the held actions, run the tick with the queued presses,
    /// then tell the scenes.
    fn run_tick(&mut self) {
        self.previous = self
            .sim
            .bubble()
            .iter()
            .map(|o| Pose { kind: o.kind, position: o.position, nose: o.nose, roof: o.roof })
            .collect();
        let input = InputRecord { held: held_actions(), presses: std::mem::take(&mut self.queued) };
        let events = self.sim.tick(&input);
        self.mode_changed = events.iter().any(|e| matches!(e, Event::ModeChanged(_)));
        let tick = self.sim.ticks() as i64;
        let signals: Vec<(&'static str, VarDictionary)> = events.iter().map(|e| self.describe(*e)).collect();
        for event in &events {
            if let Event::MountSelected(mount) = event {
                self.base_mut().emit_signal("mount_selected", &[i64::from(*mount).to_variant()]);
            }
        }
        for (kind, data) in signals {
            self.base_mut().emit_signal("sim_event", &[GString::from(kind).to_variant(), data.to_variant()]);
        }
        self.base_mut().emit_signal("ticked", &[tick.to_variant()]);
    }

    /// An event as a kind and its fields.
    fn describe(&self, event: Event) -> (&'static str, VarDictionary) {
        let mut d = VarDictionary::new();
        let kind = match event {
            Event::MountSelected(m) => {
                put(&mut d, "mount", m);
                "mount"
            }
            Event::ModeChanged(kind) => {
                put(&mut d, "mode", mode_kind_name(kind));
                "mode"
            }
            Event::Paused(on) => {
                put(&mut d, "on", on);
                "paused"
            }
            Event::Hyperspace(key) => {
                let (result, selection) = match key {
                    HyperspaceKey::NotWhileDocked => ("docked", None),
                    HyperspaceKey::CountingDown => ("counting", None),
                    HyperspaceKey::AlreadyHere(s) => ("here", Some(s)),
                    HyperspaceKey::OutOfRange(s) => ("out_of_range", Some(s)),
                    HyperspaceKey::Started(s) => ("started", Some(s)),
                };
                put(&mut d, "result", result);
                if let Some(s) = selection {
                    self.put_selection(&mut d, s);
                }
                "hyperspace"
            }
            Event::GalaxyDrive(key) => {
                put(
                    &mut d,
                    "result",
                    match key {
                        GalaxyDriveKey::NotWhileDocked => "docked",
                        GalaxyDriveKey::CountingDown => "counting",
                        GalaxyDriveKey::NotFitted => "not_fitted",
                        GalaxyDriveKey::Started => "started",
                    },
                );
                "galaxy_drive"
            }
            Event::LaserFired => "laser_fired",
            Event::MissileArmed => "missile_armed",
            Event::MissileUnarmed => "missile_unarmed",
            Event::MissileLocked { slot } => {
                put(&mut d, "slot", slot as i64);
                "missile_locked"
            }
            Event::MissileFired(fired) => {
                match fired {
                    MissileFired::NoLock => put(&mut d, "result", "no_lock"),
                    MissileFired::Jammed => put(&mut d, "result", "jammed"),
                    MissileFired::Launched(slot) => {
                        put(&mut d, "result", "launched");
                        put(&mut d, "slot", slot as i64);
                    }
                }
                "missile_fired"
            }
            Event::EcmStarted => "ecm_started",
            Event::EcmStopped => "ecm_stopped",
            Event::AreaBlast => "area_blast",
            Event::InSystemJump(jump) => {
                put(&mut d, "ok", jump == InSystemJump::Jumped);
                "in_system_jump"
            }
            Event::LaserHit { slot } => {
                put(&mut d, "slot", slot as i64);
                "laser_hit"
            }
            Event::Damaged(damage) => {
                put(
                    &mut d,
                    "result",
                    match damage {
                        Damage::Shielded => "shielded",
                        Damage::Hurt => "hurt",
                        Damage::Died => "died",
                    },
                );
                "damaged"
            }
            Event::Exploded { kind, bounty } => {
                put(&mut d, "kind", kind);
                put(&mut d, "bounty", bounty);
                "exploded"
            }
            Event::Scooped { item, gained } => {
                put(&mut d, "item", item as i64);
                put(&mut d, "gained", gained);
                "scooped"
            }
            Event::Bought(result) => {
                match result {
                    Ok(t) => {
                        put(&mut d, "ok", true);
                        put(&mut d, "item", t.item as i64);
                        put(&mut d, "quantity", i64::from(t.quantity));
                        put(&mut d, "total", t.total as i64);
                    }
                    Err(refused) => {
                        put(&mut d, "ok", false);
                        put(
                            &mut d,
                            "refused",
                            match refused {
                                BuyRefused::MoreThanAvailable => "too_many",
                                BuyRefused::NoRoom => "no_room",
                                BuyRefused::NotEnoughCash => "no_cash",
                            },
                        );
                    }
                }
                "bought"
            }
            Event::Sold(result) => {
                match result {
                    Ok(t) => {
                        put(&mut d, "ok", true);
                        put(&mut d, "item", t.item as i64);
                        put(&mut d, "quantity", i64::from(t.quantity));
                        put(&mut d, "total", t.total as i64);
                    }
                    Err(SellRefused::MoreThanHeld) => {
                        put(&mut d, "ok", false);
                        put(&mut d, "refused", "too_many");
                    }
                }
                "sold"
            }
            Event::Equipped(result) => {
                match result {
                    Ok(bought) => {
                        put(&mut d, "ok", true);
                        put(&mut d, "item", bought.item.number() as i64);
                        put(&mut d, "name", bought.item.name());
                        put(&mut d, "paid", i64::from(bought.paid));
                        put(&mut d, "refund", i64::from(bought.refund));
                        put(&mut d, "mount", bought.mount.map_or(-1, |m| m as i64));
                    }
                    Err(refused) => {
                        put(&mut d, "ok", false);
                        put(
                            &mut d,
                            "refused",
                            match refused {
                                Refused::NotOffered => "not_offered",
                                Refused::NotEnoughCash => "no_cash",
                                Refused::NoMount => "no_mount",
                                Refused::AtLimit => "at_limit",
                            },
                        );
                    }
                }
                "equipped"
            }
        };
        (kind, d)
    }

    fn put_selection(&self, d: &mut VarDictionary, selection: Selection) {
        let galaxy = views::pilot_galaxy(&self.sim);
        put(d, "system", galaxy.system(selection.system).name.as_str());
        put(d, "distance", selection.distance);
    }
}

fn mode_kind_name(kind: ModeKind) -> &'static str {
    match kind {
        ModeKind::Title => "title",
        ModeKind::Docked => "docked",
        ModeKind::Tunnel(TunnelKind::Launch) => "tunnel_launch",
        ModeKind::Tunnel(TunnelKind::Docking) => "tunnel_dock",
        ModeKind::Tunnel(TunnelKind::Hyperspace(Tunnel::Misjump)) => "tunnel_misjump",
        ModeKind::Tunnel(TunnelKind::Hyperspace(Tunnel::Galactic)) => "tunnel_galactic",
        ModeKind::Tunnel(TunnelKind::Hyperspace(Tunnel::Arrival(_))) => "tunnel_jump",
        ModeKind::Flight => "flight",
        ModeKind::Dying(_) => "dying",
        ModeKind::Escape => "escape",
    }
}

/// The held flight actions as Godot's input map has them now.
fn held_actions() -> HeldActions {
    let input = Input::singleton();
    let held = HELD.map(|action| input.is_action_pressed(action));
    HeldActions {
        dive: held[0],
        climb: held[1],
        roll_left: held[2],
        roll_right: held[3],
        speed_up: held[4],
        slow_down: held[5],
        fire: held[6],
    }
}

fn put(d: &mut VarDictionary, key: &str, value: impl ToGodot) {
    d.set(&GString::from(key).to_variant(), &value.to_variant());
}

fn point(p: Point) -> Vector2i {
    Vector2i::new(i32::from(p.0), i32::from(p.1))
}

/// A sim position in Godot metres: x right, y up, and the sim's forward z becomes −Z.
fn metres(v: Vec3) -> Vector3 {
    Vector3::new((v.x * UNIT_M) as f32, (v.y * UNIT_M) as f32, (-v.z * UNIT_M) as f32)
}

/// The Godot basis of an object whose nose and roof are given in sim axes: its −Z looks along
/// the nose and its +Y along the roof (the model contract, docs/DESIGN.md § Rig contract).
fn basis_of(nose: Vec3, roof: Vec3) -> Basis {
    let forward = Vector3::new(nose.x as f32, nose.y as f32, -nose.z as f32);
    let up = Vector3::new(roof.x as f32, roof.y as f32, -roof.z as f32);
    let z = -forward.try_normalized().unwrap_or(Vector3::FORWARD);
    let x = up.cross(z).try_normalized().unwrap_or(Vector3::RIGHT);
    let y = z.cross(x);
    Basis::from_cols(x, y, z)
}

fn system_dict(s: &SystemView) -> VarDictionary {
    let mut d = VarDictionary::new();
    put(&mut d, "index", s.index);
    put(&mut d, "name", s.name.as_str());
    put(&mut d, "position", point(s.position));
    put(&mut d, "distance", s.distance);
    put(&mut d, "economy", s.economy);
    put(&mut d, "economy_label", lodestar_core::capabilities::universe::economy_label(s.economy));
    put(&mut d, "government", s.government);
    put(&mut d, "government_label", lodestar_core::capabilities::universe::government_label(s.government));
    put(&mut d, "tech_level", s.tech_level);
    put(&mut d, "population", s.population);
    put(&mut d, "productivity", s.productivity);
    put(&mut d, "radius", s.radius);
    put(&mut d, "inhabitants", s.inhabitants.as_str());
    put(&mut d, "dot", s.dot_width);
    d
}
