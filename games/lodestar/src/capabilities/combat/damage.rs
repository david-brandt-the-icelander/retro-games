//! Damage to the player: shields first, then energy (RULES C.10.2), and the equipment and cargo
//! that damage reaching the energy bank can destroy (RULES C.10.3).

use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::market;
use crate::capabilities::pilot::{Pilot, GOODS};
use crate::capabilities::random::MainGenerator;

/// The loss roll's X values 17..21 name these, in order (RULES C.10.3).
pub const FIRST_EQUIPMENT_ROLL: u8 = GOODS as u8;
/// X at or above this destroys nothing.
pub const LOSS_ROLL_LIMIT: u8 = 22;

/// What a hit did to the player.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Damage {
    /// The shield took it all.
    Shielded,
    /// It reached the energy bank; the player lives (the crunch sound plays and the loss check
    /// ran).
    Hurt,
    /// The energy bank reached 0: the player died. The caller runs the death (RULES C.10.4).
    Died,
}

/// What the loss check destroyed (RULES C.10.3).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Loss {
    /// A whole stack of this goods item.
    Cargo(usize),
    /// The fitted equipment the roll 17..21 names.
    Equipment(u8),
}

/// Applies `damage` to the player from an attacker at `from_z` (RULES C.10.2): the aft shield
/// takes it when `from_z` < 0, else the fore shield; what the shield cannot hold empties it and
/// comes off the energy bank; at 0 energy the player dies, otherwise the loss check runs.
pub fn take_damage(
    pilot: &mut Pilot,
    cockpit: &mut Cockpit,
    random: &mut MainGenerator,
    damage: u8,
    from_z: f64,
) -> Damage {
    let shield = if from_z < 0.0 { &mut cockpit.aft_shield } else { &mut cockpit.fore_shield };
    if *shield >= damage {
        *shield -= damage;
        return Damage::Shielded;
    }
    let rest = damage - *shield;
    *shield = 0;
    if cockpit.energy <= rest {
        cockpit.energy = 0;
        return Damage::Died;
    }
    cockpit.energy -= rest;
    lose_something(pilot, cockpit, random);
    Damage::Hurt
}

/// The loss check (RULES C.10.3): draws a pair (A, X); nothing happens when A's top bit is set,
/// X ≥ 22 or a message is showing. Otherwise X 0..16 empties that goods item's stack if the hold
/// has any, and X 17..21 removes the E.C.M., fuel scoop, area blast, energy booster or auto-dock
/// if fitted; either shows its loss message.
pub fn lose_something(pilot: &mut Pilot, cockpit: &mut Cockpit, random: &mut MainGenerator) -> Option<Loss> {
    let roll = random.draw();
    if roll.a & 0x80 != 0 || roll.x >= LOSS_ROLL_LIMIT || cockpit.message_showing() {
        return None;
    }
    let x = roll.x;
    if x < FIRST_EQUIPMENT_ROLL {
        let item = usize::from(x);
        if !market::lose_stack(pilot, item) {
            return None;
        }
        cockpit.show(Message::CargoLost { item });
        return Some(Loss::Cargo(item));
    }
    let fitted = &mut pilot.fitted;
    let flag = match x - FIRST_EQUIPMENT_ROLL {
        0 => &mut fitted.ecm,
        1 => &mut fitted.fuel_scoop,
        2 => &mut fitted.area_blast,
        3 => &mut fitted.energy_booster,
        _ => &mut fitted.auto_dock,
    };
    if !*flag {
        return None;
    }
    *flag = false;
    cockpit.show(Message::EquipmentLost { roll: x });
    Some(Loss::Equipment(x))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::test_support::next_draw;

    fn setup() -> (Pilot, Cockpit) {
        (Pilot::start(), Cockpit::new())
    }

    #[test]
    fn the_shield_facing_the_attacker_takes_it() {
        let (mut pilot, mut cockpit) = setup();
        let mut random = MainGenerator::new();
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 18, 500.0), Damage::Shielded);
        assert_eq!((cockpit.fore_shield, cockpit.aft_shield), (237, 255));
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 18, -0.5), Damage::Shielded);
        assert_eq!((cockpit.fore_shield, cockpit.aft_shield), (237, 237));
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 5, 0.0), Damage::Shielded, "z = 0 is fore");
        assert_eq!(cockpit.fore_shield, 232);
        assert_eq!(random, MainGenerator::new(), "no draw while the shield holds");
    }

    #[test]
    fn overflow_reaches_the_energy_bank_and_runs_the_loss_check() {
        let (mut pilot, mut cockpit) = setup();
        cockpit.fore_shield = 10;
        cockpit.energy = 100;
        let mut random = next_draw(0x80, 0);
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 50, 9.0), Damage::Hurt);
        assert_eq!((cockpit.fore_shield, cockpit.energy, cockpit.aft_shield), (0, 60, 255));
        let mut expected = next_draw(0x80, 0);
        expected.draw();
        assert_eq!(random, expected, "one pair drawn");
    }

    #[test]
    fn energy_reaching_zero_kills_without_a_draw() {
        let (mut pilot, mut cockpit) = setup();
        cockpit.aft_shield = 0;
        cockpit.energy = 80;
        let mut random = MainGenerator::new();
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 80, -1.0), Damage::Died);
        assert_eq!(cockpit.energy, 0);
        assert_eq!(random, MainGenerator::new());
        cockpit.energy = 81;
        assert_eq!(take_damage(&mut pilot, &mut cockpit, &mut random, 80, -1.0), Damage::Hurt);
        assert_eq!(cockpit.energy, 1);
    }

    #[test]
    fn a_roll_with_the_top_bit_set_or_x_of_22_or_more_destroys_nothing() {
        let (mut pilot, mut cockpit) = setup();
        pilot.cargo[4] = 9;
        assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0x80, 4)), None);
        assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0x7F, 22)), None);
        assert_eq!(pilot.cargo[4], 9);
        assert_eq!(cockpit.message, None);
    }

    #[test]
    fn a_showing_message_spares_the_cargo_but_the_pair_is_drawn() {
        let (mut pilot, mut cockpit) = setup();
        pilot.cargo[4] = 9;
        cockpit.show(Message::EnergyLow);
        let mut random = next_draw(0x10, 4);
        assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut random), None);
        assert_eq!(pilot.cargo[4], 9);
        assert_ne!(random, next_draw(0x10, 4));
    }

    #[test]
    fn x_names_a_goods_stack() {
        let (mut pilot, mut cockpit) = setup();
        pilot.cargo[4] = 9;
        assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0x10, 4)), Some(Loss::Cargo(4)));
        assert_eq!(pilot.cargo[4], 0);
        assert_eq!(cockpit.message, Some(Message::CargoLost { item: 4 }));
        let (mut pilot, mut cockpit) = setup();
        assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0x10, 16)), None, "none held");
        assert_eq!(cockpit.message, None);
    }

    #[test]
    fn x_17_to_21_names_equipment() {
        for (x, which) in (17..=21).zip(0..) {
            let (mut pilot, mut cockpit) = setup();
            pilot.fitted.ecm = true;
            pilot.fitted.fuel_scoop = true;
            pilot.fitted.area_blast = true;
            pilot.fitted.energy_booster = true;
            pilot.fitted.auto_dock = true;
            pilot.fitted.escape_pod = true;
            pilot.fitted.galaxy_drive = true;
            assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0, x)), Some(Loss::Equipment(x)));
            let f = pilot.fitted;
            let left = [f.ecm, f.fuel_scoop, f.area_blast, f.energy_booster, f.auto_dock];
            for (i, fitted) in left.iter().enumerate() {
                assert_eq!(*fitted, i != which, "roll {x}");
            }
            assert!(f.escape_pod && f.galaxy_drive, "never lost");
            assert_eq!(cockpit.message, Some(Message::EquipmentLost { roll: x }));
            assert_eq!(lose_something(&mut pilot, &mut cockpit, &mut next_draw(0, x)), None);
        }
    }
}
