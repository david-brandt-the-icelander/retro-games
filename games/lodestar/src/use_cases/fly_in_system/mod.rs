//! Fly in a system: the pilot's goal while launched, and the owner of the 12 Hz tick and of the
//! modes around flight: the title, docked, the tunnels, death and the escape pod (RULES D.1–D.3).
//!
//! The document beside this file, `fly_in_system.md`, says what the use case does and what is
//! built yet. RULES B.3 and D.3.6 give the order of everything a tick does; `tick.rs` follows
//! it step by step.

mod tick;

use crate::capabilities::bubble::Bubble;
use crate::capabilities::cockpit::Cockpit;
use crate::capabilities::combat::{Damage, MissileFired};
use crate::capabilities::equipment::{self, Bought, Item, Refused};
use crate::capabilities::market;
use crate::capabilities::pilot::{Mount, Pilot, GOODS};
use crate::capabilities::random::MainGenerator;
use crate::capabilities::universe::{ChartCursor, Point, Selection};
use crate::features::death::{self, Cause, Dying};
use crate::features::docking;
use crate::features::escape_pod::{self, Aftermath, Escape};
use crate::features::hyperspace::{
    self, arrive, press_galaxy_drive, press_hyperspace, Countdown, GalaxyDriveKey, HyperspaceKey, Navigation,
};
use crate::features::in_system_jump::InSystemJump;
use crate::features::saving::{LoadError, PilotStore, Pilots, SaveOutcome};
use crate::features::spawning::SpawnDelay;
use crate::features::station;
use crate::features::trading::{self, BuyRefused, SellRefused, Trade};

/// Logic ticks per second (RULES B: the logic runs at 12 Hz).
pub const TICKS_PER_SECOND: u32 = 12;

/// The longest frame the clock accepts, in seconds. A longer gap (a stall, a breakpoint) is
/// cut to this, so the sim never runs a burst of catch-up ticks.
pub const MAX_FRAME_SECONDS: f64 = 0.25;

/// Steps a tunnel lasts, one per tick (RULES D.3.4).
pub const TUNNEL_STEPS: u8 = 16;

/// Turns frame times into whole logic ticks, and says how far the picture is between the last
/// two ticks.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct TickClock {
    accumulated: f64,
}

impl TickClock {
    pub const fn new() -> Self {
        Self { accumulated: 0.0 }
    }

    /// Adds one frame's time and returns how many ticks to run now.
    pub fn advance(&mut self, frame_seconds: f64) -> u32 {
        let step = 1.0 / f64::from(TICKS_PER_SECOND);
        let frame = if frame_seconds.is_finite() { frame_seconds.clamp(0.0, MAX_FRAME_SECONDS) } else { 0.0 };
        self.accumulated += frame;
        let mut ticks = 0;
        while self.accumulated >= step {
            self.accumulated -= step;
            ticks += 1;
        }
        ticks
    }

    /// How far the present moment is from the last tick toward the next, 0.0..1.0. The picture
    /// interpolates between the previous and the current state by this much.
    pub fn alpha(&self) -> f64 {
        (self.accumulated * f64::from(TICKS_PER_SECOND)).clamp(0.0, 1.0)
    }
}

/// What the pilot did since the last tick: held actions sampled at the tick, and presses
/// queued so that a tap between two ticks is never lost (DESIGN § Keyboard controls).
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct InputRecord {
    pub held: HeldActions,
    pub presses: Vec<Press>,
}

/// Actions that count while held (RULES D.4.1).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct HeldActions {
    pub dive: bool,
    pub climb: bool,
    pub roll_left: bool,
    pub roll_right: bool,
    pub speed_up: bool,
    pub slow_down: bool,
    pub fire: bool,
}

/// What the panels and the picture show (RULES D.6). Lasers fire, hit and lock only while the
/// space view shows (deliberate difference 9).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Screen {
    #[default]
    Space,
    GalaxyChart,
    LocalChart,
    SystemData,
    Status,
    Market,
    Inventory,
    Equipment,
}

/// Actions that happen once per press (RULES D.4.2–D.4.4, D.3.12).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Press {
    /// Choose the active laser mount: 0 front, 1 rear, 2 left, 3 right.
    Mount(u8),
    /// Show a screen.
    Screen(Screen),
    /// Put the chart cursor on a point and select the system nearest it (RULES A.5.1).
    Cursor(Point),
    /// On the title: start playing the last saved or loaded pilot (RULES D.3.1).
    Start,
    /// Docked: launch (RULES D.3.5).
    Launch,
    /// The hyperspace and galaxy-drive keys (RULES A.5.2, A.5.3).
    Hyperspace,
    GalaxyDrive,
    /// Flight actions, queued to the next tick logic in the order pressed (RULES B.3.3 step 2).
    UnarmMissile,
    ArmMissile,
    FireMissile,
    AreaBlast,
    EscapePod,
    InSystemJump,
    Ecm,
    AutoDock,
    /// Docked trading at the market panel (deliberate difference 12).
    Buy { item: usize, quantity: u8 },
    Sell { item: usize, quantity: u32 },
    /// Docked: buy equipment from the list (deliberate difference 12).
    Equip { item: Item, mount: Option<Mount> },
    /// Pause, and the pause handler's actions (RULES D.3.12). Sound toggles are the
    /// presentation's.
    Pause,
    Resume,
    Quit,
    ToggleAutoCentre,
    ToggleDamping,
}

impl Press {
    /// The flight actions queued to the tick logic.
    fn is_queued(self) -> bool {
        matches!(
            self,
            Press::UnarmMissile
                | Press::ArmMissile
                | Press::FireMissile
                | Press::AreaBlast
                | Press::EscapePod
                | Press::InSystemJump
                | Press::Ecm
                | Press::AutoDock
        )
    }
}

/// The kind of tunnel and what its completion does (RULES D.3.4).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TunnelKind {
    Launch,
    Docking,
    Hyperspace(hyperspace::Tunnel),
}

/// The game's mode (RULES D.2). Pause is a separate flag.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Title,
    Docked,
    Tunnel { kind: TunnelKind, steps: u8 },
    Flight,
    Dying(Dying),
    Escape(Escape),
}

/// The mode without its state, for events.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModeKind {
    Title,
    Docked,
    Tunnel(TunnelKind),
    Flight,
    Dying(Cause),
    Escape,
}

impl Mode {
    pub fn kind(&self) -> ModeKind {
        match *self {
            Mode::Title => ModeKind::Title,
            Mode::Docked => ModeKind::Docked,
            Mode::Tunnel { kind, .. } => ModeKind::Tunnel(kind),
            Mode::Flight => ModeKind::Flight,
            Mode::Dying(d) => ModeKind::Dying(d.cause),
            Mode::Escape(_) => ModeKind::Escape,
        }
    }
}

/// Something that happened that the picture, the panels or the sound react to, in order.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Event {
    /// The active mount changed.
    MountSelected(u8),
    ModeChanged(ModeKind),
    Paused(bool),
    Hyperspace(HyperspaceKey),
    GalaxyDrive(GalaxyDriveKey),
    LaserFired,
    MissileArmed,
    MissileUnarmed,
    MissileLocked { slot: usize },
    MissileFired(MissileFired),
    EcmStarted,
    EcmStopped,
    AreaBlast,
    InSystemJump(InSystemJump),
    /// The player's laser hit the object in `slot`.
    LaserHit { slot: usize },
    /// The player took damage (a shield held, or the energy fell).
    Damaged(Damage),
    /// A finished explosion left the bubble; `bounty` in tenths of a credit.
    Exploded { kind: u8, bounty: u16 },
    Scooped { item: usize, gained: bool },
    Bought(Result<Trade, BuyRefused>),
    Sold(Result<Trade, SellRefused>),
    Equipped(Result<Bought, Refused>),
}

/// The game from the title to the end: the pilots, the player's ship, the bubble and the modes.
#[derive(Clone, Debug)]
pub struct FlyInSystem {
    pilots: Pilots,
    cockpit: Cockpit,
    bubble: Bubble,
    navigation: Navigation,
    countdown: Countdown,
    delay: SpawnDelay,
    random: MainGenerator,
    mode: Mode,
    screen: Screen,
    paused: bool,
    /// The substep counter (RULES D.1): even after the increase means a logic substep.
    substeps: u64,
    ticks: u64,
    /// Flight actions waiting for the next tick logic, in press order.
    queued: Vec<Press>,
    events: Vec<Event>,
}

impl Default for FlyInSystem {
    fn default() -> Self {
        Self::new()
    }
}

/// The start pilot with its start market (RULES A.9.7, GDD § 5.4: economy 5, market byte 0).
pub fn start_pilot() -> Pilot {
    let mut pilot = Pilot::start();
    market::start_market(&mut pilot, START_ECONOMY);
    pilot
}

/// The start system's economy (GDD § 5.2).
const START_ECONOMY: u8 = 5;

impl FlyInSystem {
    /// Power-on: the title, with the start pilot saved and playing.
    pub fn new() -> Self {
        let pilots = Pilots::new(start_pilot());
        let navigation = Navigation::start(&pilots.playing);
        Self {
            pilots,
            cockpit: Cockpit::new(),
            bubble: Bubble::new(),
            navigation,
            countdown: Countdown::new(),
            delay: SpawnDelay::default(),
            random: MainGenerator::new(),
            mode: Mode::Title,
            screen: Screen::Space,
            paused: false,
            substeps: 0,
            ticks: 0,
            queued: Vec::new(),
            events: Vec::new(),
        }
    }

    /// Runs one tick, two substeps (RULES D.1): the presses are dispatched in the first, so
    /// queued flight actions reach this tick's logic. Returns the tick's events in order.
    pub fn tick(&mut self, input: &InputRecord) -> Vec<Event> {
        self.substep(&input.presses, input.held);
        self.substep(&[], input.held);
        self.ticks += 1;
        std::mem::take(&mut self.events)
    }

    /// One substep (RULES D.1 steps 1–4).
    fn substep(&mut self, presses: &[Press], held: HeldActions) {
        self.substeps += 1;
        let logic = self.substeps.is_multiple_of(2);
        if self.paused {
            for &press in presses {
                self.pause_press(press);
            }
            return;
        }
        match self.mode {
            Mode::Title => {
                if let Some(&press) = presses.first() {
                    self.title_press(press);
                }
            }
            Mode::Docked => {
                for &press in presses {
                    self.docked_press(press);
                }
                if logic {
                    self.docked_chores();
                }
            }
            Mode::Tunnel { kind, steps } => {
                if logic {
                    self.tunnel_step(kind, steps);
                }
            }
            Mode::Flight => {
                for &press in presses {
                    self.flight_press(press);
                }
                self.half_move();
                if logic {
                    self.flight_logic(held, false);
                }
            }
            Mode::Dying(_) => {
                if logic {
                    self.flight_logic(HeldActions::default(), true);
                    if let Mode::Dying(mut dying) = self.mode {
                        if dying.tick() {
                            self.end_death();
                            return;
                        }
                        self.mode = Mode::Dying(dying);
                    }
                }
                self.half_move();
            }
            Mode::Escape(mut escape) => {
                if logic {
                    let over = escape.tick(&mut self.bubble);
                    self.mode = Mode::Escape(escape);
                    if over {
                        self.end_escape(escape);
                        return;
                    }
                }
                self.half_move();
            }
        }
    }

    /// Moves everything by half a tick with the angles and speed of the last tick logic
    /// (RULES B.7.2).
    fn half_move(&mut self) {
        let a = self.cockpit.attitude;
        crate::capabilities::flight::move_substep(&mut self.bubble, a.roll_angle, a.pitch_angle, self.cockpit.speed);
    }

    fn set_mode(&mut self, mode: Mode) {
        self.mode = mode;
        self.events.push(Event::ModeChanged(mode.kind()));
    }

    fn start_tunnel(&mut self, kind: TunnelKind) {
        self.screen = Screen::Space;
        self.set_mode(Mode::Tunnel { kind, steps: 0 });
    }

    // ---- Title ----

    fn title_press(&mut self, press: Press) {
        if press == Press::Start {
            self.begin();
        }
    }

    /// The title's steps 3 and 5 (RULES D.3.1): the playing pilot becomes a copy of the last
    /// saved or loaded one, the flight state is reset, and the pilot is docked at the system
    /// nearest their position.
    fn begin(&mut self) {
        self.pilots.restore();
        self.cockpit.reset(&mut self.random);
        self.bubble.clear();
        self.navigation = Navigation::start(&self.pilots.playing);
        self.delay.reset();
        docking::enter_docked(&self.pilots.playing, &mut self.navigation, &mut self.countdown);
        self.screen = Screen::Status;
        self.set_mode(Mode::Docked);
    }

    /// Loads the pilot named `name` from `store` (RULES A.8.3); only on the title.
    pub fn load(&mut self, name: &str, store: &dyn PilotStore) -> Option<Result<(), LoadError>> {
        (self.mode == Mode::Title).then(|| self.pilots.load(name, store))
    }

    /// Saves the playing pilot under `name` (RULES A.8.2); only while docked.
    pub fn save(&mut self, name: &str, store: &mut dyn PilotStore) -> SaveOutcome {
        self.pilots.save(name, self.mode == Mode::Docked, store)
    }

    // ---- Docked ----

    fn docked_press(&mut self, press: Press) {
        let pilot = &mut self.pilots.playing;
        match press {
            Press::Launch => self.start_tunnel(TunnelKind::Launch),
            Press::Pause => self.pause(),
            Press::Mount(m) => self.select_mount(m),
            Press::Screen(s) => self.show(s),
            Press::Cursor(p) => self.move_cursor(p),
            Press::Hyperspace => {
                let key = press_hyperspace(&mut self.navigation, &mut self.countdown, pilot, true);
                self.events.push(Event::Hyperspace(key));
            }
            Press::GalaxyDrive => {
                let key = press_galaxy_drive(&mut self.countdown, pilot, true);
                self.events.push(Event::GalaxyDrive(key));
            }
            Press::Buy { item, quantity } if item < GOODS => {
                let economy = self.navigation.current_system(pilot).economy;
                self.events.push(Event::Bought(trading::buy(pilot, item, quantity, economy)));
            }
            Press::Sell { item, quantity } if item < GOODS => {
                let economy = self.navigation.current_system(pilot).economy;
                self.events.push(Event::Sold(trading::sell(pilot, item, quantity, economy)));
            }
            Press::Equip { item, mount } => {
                let tech = self.navigation.current_system(pilot).tech_level;
                self.events.push(Event::Equipped(equipment::buy_offered(pilot, tech, item, mount)));
            }
            _ => {}
        }
    }

    /// The docked chores (RULES D.3.3; the chart cursor is the presentation's).
    fn docked_chores(&mut self) {
        self.cockpit.cool_laser();
        self.cockpit.count_down_counter();
        self.cockpit.count_down_message();
    }

    // ---- Tunnels ----

    fn tunnel_step(&mut self, kind: TunnelKind, steps: u8) {
        let steps = steps + 1;
        if steps < TUNNEL_STEPS {
            self.mode = Mode::Tunnel { kind, steps };
            return;
        }
        let pilot = &mut self.pilots.playing;
        match kind {
            TunnelKind::Launch => {
                station::launch(
                    pilot,
                    &mut self.cockpit,
                    &mut self.bubble,
                    &mut self.navigation,
                    &mut self.countdown,
                    &mut self.random,
                );
                self.screen = Screen::Space;
                self.set_mode(Mode::Flight);
            }
            TunnelKind::Docking => {
                docking::finish_docking(
                    pilot,
                    &mut self.cockpit,
                    &mut self.bubble,
                    &mut self.navigation,
                    &mut self.countdown,
                    &mut self.random,
                );
                self.screen = Screen::Status;
                self.set_mode(Mode::Docked);
            }
            TunnelKind::Hyperspace(tunnel) => {
                arrive(
                    tunnel,
                    pilot,
                    &mut self.cockpit,
                    &mut self.bubble,
                    &mut self.navigation,
                    &mut self.delay,
                    &mut self.random,
                );
                self.screen = Screen::Space;
                self.set_mode(Mode::Flight);
            }
        }
    }

    // ---- Flight ----

    fn flight_press(&mut self, press: Press) {
        let pilot = &mut self.pilots.playing;
        match press {
            p if p.is_queued() => self.queued.push(p),
            Press::Pause => self.pause(),
            Press::Mount(m) => self.select_mount(m),
            Press::Screen(s) => self.show(s),
            Press::Cursor(p) => self.move_cursor(p),
            Press::Hyperspace => {
                let key = press_hyperspace(&mut self.navigation, &mut self.countdown, pilot, false);
                self.events.push(Event::Hyperspace(key));
            }
            Press::GalaxyDrive => {
                let key = press_galaxy_drive(&mut self.countdown, pilot, false);
                self.events.push(Event::GalaxyDrive(key));
            }
            _ => {}
        }
    }

    /// The player dies (RULES D.3.10), unless already dying: held and queued input is dropped,
    /// the front of the space view shows, and the mode becomes Death.
    fn die(&mut self, cause: Cause) {
        if matches!(self.mode, Mode::Dying(_)) {
            return;
        }
        let dying = death::die(cause, &mut self.cockpit, &mut self.bubble, &mut self.countdown, &mut self.random);
        self.queued.clear();
        self.screen = Screen::Space;
        self.set_mode(Mode::Dying(dying));
    }

    fn end_death(&mut self) {
        death::return_to_title(&mut self.pilots, &mut self.countdown);
        self.bubble.clear();
        self.set_mode(Mode::Title);
    }

    fn end_escape(&mut self, escape: Escape) {
        let outcome = escape_pod::aftermath(
            &escape,
            &mut self.pilots.playing,
            &mut self.cockpit,
            &mut self.bubble,
            &mut self.navigation,
            &mut self.countdown,
            &mut self.random,
        );
        match outcome {
            Aftermath::Docked(_) => {
                self.screen = Screen::Status;
                self.set_mode(Mode::Docked);
            }
            Aftermath::Died(dying) => {
                self.screen = Screen::Space;
                self.set_mode(Mode::Dying(dying));
            }
        }
    }

    // ---- Shared presses ----

    fn select_mount(&mut self, mount: u8) {
        let mount = Mount::from(mount);
        if mount < 4 && mount != self.cockpit.active_mount {
            self.cockpit.active_mount = mount;
            self.events.push(Event::MountSelected(mount as u8));
        }
    }

    /// Shows a screen; the system-data and status screens select from the cursor first
    /// (RULES D.3.2, A.5.1).
    fn show(&mut self, screen: Screen) {
        if matches!(screen, Screen::SystemData | Screen::Status) {
            self.navigation.select(&self.pilots.playing, &mut self.countdown);
        }
        self.screen = screen;
    }

    fn move_cursor(&mut self, point: Point) {
        self.navigation.cursor = ChartCursor::at(point);
        self.navigation.select(&self.pilots.playing, &mut self.countdown);
    }

    // ---- Pause ----

    fn pause(&mut self) {
        self.paused = true;
        self.events.push(Event::Paused(true));
    }

    fn pause_press(&mut self, press: Press) {
        match press {
            Press::Resume => {
                self.paused = false;
                self.events.push(Event::Paused(false));
            }
            Press::ToggleAutoCentre => self.cockpit.attitude.auto_centre ^= true,
            Press::ToggleDamping => self.cockpit.attitude.damping ^= true,
            Press::Quit => {
                self.paused = false;
                self.events.push(Event::Paused(false));
                self.cockpit.reset(&mut self.random);
                self.bubble.clear();
                self.queued.clear();
                self.set_mode(Mode::Title);
            }
            _ => {}
        }
    }

    // ---- What the presentation reads ----

    /// Ticks run since power-on.
    pub fn ticks(&self) -> u64 {
        self.ticks
    }

    /// The mount whose lasers fire: 0 front, 1 rear, 2 left, 3 right.
    pub fn active_mount(&self) -> u8 {
        self.cockpit.active_mount as u8
    }

    pub fn mode(&self) -> Mode {
        self.mode
    }

    pub fn screen(&self) -> Screen {
        self.screen
    }

    pub fn paused(&self) -> bool {
        self.paused
    }

    pub fn pilot(&self) -> &Pilot {
        &self.pilots.playing
    }

    pub fn cockpit(&self) -> &Cockpit {
        &self.cockpit
    }

    pub fn bubble(&self) -> &Bubble {
        &self.bubble
    }

    pub fn navigation(&self) -> &Navigation {
        &self.navigation
    }

    pub fn countdown(&self) -> &Countdown {
        &self.countdown
    }

    /// The selected system, as the charts show it.
    pub fn selected(&self) -> Selection {
        self.navigation.selected
    }

    /// The main generator, for tests and the parity harness.
    pub fn random(&self) -> &MainGenerator {
        &self.random
    }

    /// True when the lasers may fire, hit and lock: the space view in flight or dying
    /// (deliberate difference 9).
    fn flight_view(&self) -> bool {
        self.screen == Screen::Space
    }
}

#[cfg(test)]
mod tests;
