use super::*;
use crate::capabilities::ships::{PLANET_A, PLANET_B, STATION};
use crate::capabilities::universe::{distance, in_range};
use crate::features::hyperspace::COUNTDOWN_TICKS;

fn press(sim: &mut FlyInSystem, p: Press) -> Vec<Event> {
    sim.tick(&InputRecord { presses: vec![p], ..Default::default() })
}

fn idle(sim: &mut FlyInSystem, ticks: u32) -> Vec<Event> {
    (0..ticks).flat_map(|_| sim.tick(&InputRecord::default())).collect()
}

fn docked() -> FlyInSystem {
    let mut sim = FlyInSystem::new();
    press(&mut sim, Press::Start);
    sim
}

fn launched() -> FlyInSystem {
    let mut sim = docked();
    press(&mut sim, Press::Launch);
    idle(&mut sim, u32::from(TUNNEL_STEPS) - 1);
    assert_eq!(sim.mode(), Mode::Flight);
    sim
}

#[test]
fn twelve_ticks_a_second_whatever_the_frame_rate() {
    for fps in [30.0, 60.0, 144.0, 240.0] {
        let mut clock = TickClock::new();
        let frames = fps as usize * 10;
        let ticks: u32 = (0..frames).map(|_| clock.advance(1.0 / fps)).sum();
        assert!((119..=120).contains(&ticks), "{fps} fps gave {ticks} ticks in 10 s");
    }
}

#[test]
fn alpha_tracks_the_time_since_the_last_tick() {
    let mut clock = TickClock::new();
    assert_eq!(clock.advance(1.0 / 24.0), 0);
    assert!((clock.alpha() - 0.5).abs() < 1e-9);
    assert_eq!(clock.advance(1.0 / 24.0), 1);
    assert!(clock.alpha() < 1e-9);
}

#[test]
fn a_stall_is_cut_to_the_longest_frame() {
    let mut clock = TickClock::new();
    assert_eq!(clock.advance(10.0), 3);
    assert_eq!(clock.advance(f64::NAN), 0);
    assert_eq!(clock.advance(-1.0), 0);
}

#[test]
fn power_on_is_the_title_and_start_docks_the_start_pilot() {
    let mut sim = FlyInSystem::new();
    assert_eq!(sim.mode(), Mode::Title);
    let events = press(&mut sim, Press::Start);
    assert_eq!(events, vec![Event::ModeChanged(ModeKind::Docked)]);
    assert_eq!((sim.mode(), sim.screen()), (Mode::Docked, Screen::Status));
    let mut expected = MainGenerator::new();
    expected.discard(108);
    assert_eq!(sim.random(), &expected, "54 draws at power-on, 54 for the title's reset (RULES A.2.1, D.13)");
    assert_eq!(sim.pilot().availability[0], 27, "the start market (RULES A.9.7)");
}

#[test]
fn only_the_first_press_in_a_substep_answers_the_title() {
    let mut sim = FlyInSystem::new();
    sim.tick(&InputRecord { presses: vec![Press::Launch, Press::Start], ..Default::default() });
    assert_eq!(sim.mode(), Mode::Title);
}

#[test]
fn a_mount_press_changes_the_active_mount_once() {
    let mut sim = launched();
    let input = InputRecord { presses: vec![Press::Mount(2), Press::Mount(2), Press::Mount(9)], ..Default::default() };
    let events = sim.tick(&input);
    assert_eq!(events.iter().filter(|e| matches!(e, Event::MountSelected(_))).count(), 1);
    assert_eq!(sim.active_mount(), 2);
}

#[test]
fn the_launch_tunnel_takes_sixteen_ticks_and_leaves_the_station_behind() {
    let mut sim = docked();
    press(&mut sim, Press::Launch);
    assert!(matches!(sim.mode(), Mode::Tunnel { kind: TunnelKind::Launch, steps: 1 }), "first step in the same tick");
    idle(&mut sim, 14);
    assert!(matches!(sim.mode(), Mode::Tunnel { steps: 15, .. }));
    let events = idle(&mut sim, 1);
    assert_eq!(events, vec![Event::ModeChanged(ModeKind::Flight)]);
    let kinds: Vec<u8> = sim.bubble().iter().map(|o| o.kind).collect();
    assert!(matches!(kinds[0], PLANET_A | PLANET_B));
    assert_eq!(kinds[1], STATION);
    assert!(sim.cockpit().station_present);
    assert_eq!(sim.cockpit().speed, 12);
}

#[test]
fn speed_keys_act_once_per_tick() {
    let mut sim = launched();
    let held = HeldActions { speed_up: true, ..Default::default() };
    for _ in 0..5 {
        sim.tick(&InputRecord { held, presses: Vec::new() });
    }
    assert_eq!(sim.cockpit().speed, 17);
}

#[test]
fn the_world_moves_by_the_speed_each_tick() {
    let mut sim = launched();
    let z = sim.bubble().get(1).unwrap().position.z;
    idle(&mut sim, 1);
    let moved = z - sim.bubble().get(1).unwrap().position.z;
    assert!((moved - 12.0).abs() < 0.5, "moved {moved}");
}

#[test]
fn lasers_fire_only_from_the_space_view() {
    let mut sim = launched();
    let fire = InputRecord { held: HeldActions { fire: true, ..Default::default() }, presses: Vec::new() };
    assert!(sim.tick(&fire).contains(&Event::LaserFired));
    press(&mut sim, Press::Screen(Screen::GalaxyChart));
    idle(&mut sim, 2);
    assert!(!sim.tick(&fire).contains(&Event::LaserFired));
}

#[test]
fn queued_actions_wait_for_the_tick_logic_and_keep_their_order() {
    let mut sim = launched();
    let events = sim.tick(&InputRecord {
        presses: vec![Press::ArmMissile, Press::UnarmMissile, Press::ArmMissile],
        ..Default::default()
    });
    let missile: Vec<&Event> =
        events.iter().filter(|e| matches!(e, Event::MissileArmed | Event::MissileUnarmed)).collect();
    assert_eq!(missile, vec![&Event::MissileArmed, &Event::MissileUnarmed, &Event::MissileArmed]);
    assert!(sim.cockpit().missile.armed);
}

#[test]
fn the_auto_dock_docks_through_the_tunnel() {
    let mut sim = launched();
    sim.pilots.playing.fitted.auto_dock = true;
    press(&mut sim, Press::AutoDock);
    assert!(matches!(sim.mode(), Mode::Tunnel { kind: TunnelKind::Docking, .. }));
    idle(&mut sim, u32::from(TUNNEL_STEPS));
    assert_eq!((sim.mode(), sim.screen()), (Mode::Docked, Screen::Status));
    assert!(sim.bubble().is_empty());
}

#[test]
fn a_hyperspace_jump_counts_down_then_arrives() {
    let mut sim = launched();
    let here = sim.pilot().position;
    let target = hyperspace::galaxy(sim.pilot())
        .systems()
        .map(|s| (s.x, s.y))
        .find(|&p| in_range(distance(here, p), 70))
        .expect("a neighbour in range");
    press(&mut sim, Press::Cursor(target));
    let events = press(&mut sim, Press::Hyperspace);
    let Some(Event::Hyperspace(HyperspaceKey::Started(selection))) = events.first().copied() else {
        panic!("no countdown: {events:?}");
    };
    // The press's own tick is the first of the countdown (RULES D.3.7).
    idle(&mut sim, COUNTDOWN_TICKS - 1);
    assert!(matches!(sim.mode(), Mode::Tunnel { kind: TunnelKind::Hyperspace(_), .. }));
    idle(&mut sim, u32::from(TUNNEL_STEPS));
    assert_eq!(sim.mode(), Mode::Flight);
    assert_eq!(sim.pilot().fuel, 70 - selection.distance as u8);
    assert!(sim.pilot().position == selection.position || sim.cockpit().misjump);
}

#[test]
fn death_runs_sixty_one_ticks_then_the_title_restores_the_saved_pilot() {
    let mut sim = launched();
    sim.pilots.playing.cash = 99_999;
    sim.die(Cause::Damage);
    assert!(matches!(sim.mode(), Mode::Dying(_)));
    assert_eq!(sim.bubble().len(), 4, "four wreck canisters");
    idle(&mut sim, 60);
    assert!(matches!(sim.mode(), Mode::Dying(_)));
    idle(&mut sim, 1);
    assert_eq!(sim.mode(), Mode::Title);
    press(&mut sim, Press::Start);
    assert_eq!(sim.pilot().cash, 1_000);
}

#[test]
fn the_escape_pod_drifts_ninety_seven_ticks_then_docks() {
    let mut sim = launched();
    sim.pilots.playing.fitted.escape_pod = true;
    sim.pilots.playing.cargo[0] = 5;
    press(&mut sim, Press::EscapePod);
    assert!(matches!(sim.mode(), Mode::Escape(_)));
    idle(&mut sim, 96);
    assert!(matches!(sim.mode(), Mode::Escape(_)));
    idle(&mut sim, 1);
    assert_eq!(sim.mode(), Mode::Docked);
    let p = sim.pilot();
    assert_eq!((p.cargo[0], p.fuel, p.fitted.escape_pod), (0, 70, false));
}

#[test]
fn pause_stops_everything_until_resumed() {
    let mut sim = launched();
    press(&mut sim, Press::Pause);
    let before = (sim.bubble().clone(), sim.cockpit().counter);
    idle(&mut sim, 10);
    assert_eq!((sim.bubble().clone(), sim.cockpit().counter), before);
    press(&mut sim, Press::Resume);
    idle(&mut sim, 1);
    assert_ne!(sim.cockpit().counter, before.1);
}

#[test]
fn quit_from_pause_returns_to_the_title() {
    let mut sim = launched();
    press(&mut sim, Press::Pause);
    press(&mut sim, Press::Quit);
    assert_eq!(sim.mode(), Mode::Title);
    assert!(!sim.paused());
}

#[test]
fn buying_fuel_sets_the_main_counter_to_zero() {
    let mut sim = docked();
    idle(&mut sim, 5);
    assert_eq!(sim.cockpit().counter, 250, "the start tick and five more each count C down");
    sim.pilots.playing.fuel = 40;
    let events = press(&mut sim, Press::Equip { item: Item::Fuel, mount: None });
    assert!(matches!(events.as_slice(), [Event::Equipped(Ok(_))]));
    // The press is dispatched before this tick's chores, which then count C down once.
    assert_eq!(sim.cockpit().counter, 255, "RULES A.12.4, D.14");
}

#[test]
fn trading_happens_only_while_docked() {
    let mut sim = docked();
    let events = press(&mut sim, Press::Buy { item: 0, quantity: 16 });
    assert!(matches!(events.as_slice(), [Event::Bought(Ok(_))]));
    assert_eq!(sim.pilot().cargo[0], 16);
    let mut flying = launched();
    assert!(press(&mut flying, Press::Buy { item: 0, quantity: 1 }).iter().all(|e| !matches!(e, Event::Bought(_))));
}

#[test]
fn the_same_input_gives_the_same_game() {
    let run = || {
        let mut sim = launched();
        for t in 0..3_000u32 {
            let held = HeldActions {
                fire: t % 7 < 3,
                roll_left: t % 50 < 20,
                climb: t % 90 < 30,
                speed_up: t % 300 < 40,
                ..Default::default()
            };
            sim.tick(&InputRecord { held, presses: Vec::new() });
        }
        (*sim.random(), sim.bubble().len(), sim.cockpit().clone(), sim.pilot().clone(), sim.mode())
    };
    assert_eq!(run(), run());
}

/// A long game with every kind of press, in every mode: nothing panics (debug builds check every
/// overflow) and the game keeps cycling through its modes.
#[test]
fn a_long_restless_game_never_panics() {
    let presses = [
        Press::Start,
        Press::Launch,
        Press::ArmMissile,
        Press::FireMissile,
        Press::Ecm,
        Press::Mount(1),
        Press::Mount(0),
        Press::InSystemJump,
        Press::Hyperspace,
        Press::GalaxyDrive,
        Press::AreaBlast,
        Press::Screen(Screen::Space),
        Press::Cursor((90, 120)),
        Press::Cursor((30, 60)),
        Press::AutoDock,
        Press::Buy { item: 4, quantity: 3 },
        Press::Sell { item: 4, quantity: 1 },
        Press::Equip { item: Item::Missile, mount: None },
        Press::EscapePod,
    ];
    let mut sim = FlyInSystem::new();
    let mut seen = std::collections::HashSet::new();
    let mut tally = std::collections::BTreeMap::new();
    let mut max_bubble = 0;
    let mut x: u32 = 12345;
    for t in 0..40_000u32 {
        x = x.wrapping_mul(1_103_515_245).wrapping_add(12_345);
        let r = x >> 16;
        let held = HeldActions {
            fire: r & 1 == 1,
            roll_left: r & 6 == 2,
            roll_right: r & 6 == 4,
            climb: r & 24 == 8,
            dive: r & 24 == 16,
            speed_up: r & 96 == 32,
            slow_down: r & 96 == 64,
        };
        let mut input = InputRecord { held, presses: Vec::new() };
        if t % 23 == 0 {
            input.presses.push(presses[(r as usize / 7) % presses.len()]);
        }
        if t % 997 == 0 {
            sim.pilots.playing.fitted = crate::capabilities::pilot::Fitted {
                ecm: true,
                fuel_scoop: true,
                area_blast: true,
                energy_booster: true,
                auto_dock: r & 1 == 0,
                galaxy_drive: true,
                escape_pod: r & 2 == 0,
            };
            sim.pilots.playing.missiles = 4;
        }
        for e in sim.tick(&input) {
            if let Event::ModeChanged(kind) = e {
                let name = format!("{kind:?}");
                *tally.entry(name.split('(').next().unwrap_or_default().to_string()).or_insert(0) += 1;
            }
        }
        max_bubble = max_bubble.max(sim.bubble().len());
        seen.insert(std::mem::discriminant(&sim.mode()));
    }
    for mode in ["Flight", "Tunnel", "Docked", "Escape", "Dying"] {
        assert!(tally.contains_key(mode), "never entered {mode}: {tally:?}");
    }
    assert!(seen.len() >= 5 && max_bubble > 2 && sim.pilot().kills > 0);
}
