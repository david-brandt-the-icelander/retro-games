use godot::classes::Input;
use godot::prelude::*;
use lodestar_core::use_cases::fly_in_system::{Event, FlyInSystem, InputRecord, Press, TickClock};

/// Runs the sim at 12 Hz under Godot's frame loop and tells the scene what happened.
///
/// Each frame it reads Godot's input actions into an input record, runs as many logic ticks as
/// the elapsed time allows, and emits `ticked` after each one. The scene interpolates with
/// `alpha()` between ticks.
#[derive(GodotClass)]
#[class(base = Node)]
pub struct SimHost {
    base: Base<Node>,
    clock: TickClock,
    sim: FlyInSystem,
    queued: Vec<Press>,
}

#[godot_api]
impl INode for SimHost {
    fn init(base: Base<Node>) -> Self {
        Self { base, clock: TickClock::new(), sim: FlyInSystem::new(), queued: Vec::new() }
    }

    fn process(&mut self, delta: f64) {
        self.queue_presses();
        let ticks = self.clock.advance(delta);
        for _ in 0..ticks {
            let input = InputRecord { presses: std::mem::take(&mut self.queued), ..Default::default() };
            let events = self.sim.tick(&input);
            let tick = self.sim.ticks() as i64;
            for event in events {
                match event {
                    Event::MountSelected(mount) => {
                        self.base_mut().emit_signal("mount_selected", &[i64::from(mount).to_variant()]);
                    }
                }
            }
            self.base_mut().emit_signal("ticked", &[tick.to_variant()]);
        }
    }
}

#[godot_api]
impl SimHost {
    /// Emitted after every logic tick, with the number of ticks run so far.
    #[signal]
    fn ticked(tick: i64);

    /// Emitted when the active laser mount changes: 0 front, 1 rear, 2 left, 3 right.
    #[signal]
    fn mount_selected(mount: i64);

    /// How far the present frame is between the last tick and the next, 0..1.
    #[func]
    fn alpha(&self) -> f64 {
        self.clock.alpha()
    }

    /// Ticks run since launch.
    #[func]
    fn tick_count(&self) -> i64 {
        self.sim.ticks() as i64
    }

    /// The active laser mount: 0 front, 1 rear, 2 left, 3 right.
    #[func]
    fn active_mount(&self) -> i64 {
        i64::from(self.sim.active_mount())
    }
}

impl SimHost {
    /// Queues one-shot presses so a tap between two ticks reaches the next tick.
    fn queue_presses(&mut self) {
        let input = Input::singleton();
        for (index, action) in ["mount_front", "mount_rear", "mount_left", "mount_right"].iter().enumerate() {
            if input.is_action_just_pressed(*action) {
                self.queued.push(Press::Mount(index as u8));
            }
        }
    }
}
