//! Distance, fuel range and the pure parts of choosing and reaching a destination (RULES A.4,
//! A.5.1, A.5.5 and A.5.7).

use super::galaxy::Galaxy;
use super::system::Point;

/// Where the cursor goes after a galactic jump, before selecting (RULES A.5.7).
pub const REACH_JUMP_CURSOR: Point = (96, 96);

/// A mis-jump happens when the jump's random byte is at least this (chance 3/256; RULES A.5.5).
pub const MISJUMP_FROM: u8 = 253;

/// The distance between two systems in tenths of a light year (RULES A.4.1): the vertical
/// difference counts half, and the sum of squares is cut to 16 bits before the square root
/// (RULES A.14 item 1).
pub fn distance(from: Point, to: Point) -> u16 {
    let dx = u32::from(from.0.abs_diff(to.0));
    let dy = u32::from(from.1.abs_diff(to.1) >> 1);
    let q = (dx * dx + dy * dy) & 0xFFFF;
    let r = q.isqrt();
    ((4 * r) & 0xFFFF) as u16
}

/// True when a jump of `distance` is allowed on `fuel`: `0 < distance ≤ fuel` (RULES A.4.3).
pub fn in_range(distance: u16, fuel: u8) -> bool {
    distance > 0 && distance <= u16::from(fuel)
}

/// The fuel left after a jump of `distance`. LodeStar never lets fuel go below 0 (deliberate
/// difference 6), so the result stops at 0.
pub fn fuel_after_jump(fuel: u8, distance: u16) -> u8 {
    u16::from(fuel).saturating_sub(distance) as u8
}

/// The selected system and its distance from the pilot (RULES A.5.1).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Selection {
    /// The system's number in its galaxy.
    pub system: u8,
    /// The system's position; selecting moves the cursor exactly here.
    pub position: Point,
    /// Distance from the pilot's position, tenths of a light year.
    pub distance: u16,
}

/// Selects from the cursor (RULES A.5.1): the system nearest the cursor, and its distance from
/// the pilot. The caller moves the cursor onto `position`.
pub fn select(galaxy: Galaxy, cursor: Point, pilot: Point) -> Selection {
    let system = galaxy.nearest(cursor);
    let position = galaxy.system(system).position();
    Selection { system, position, distance: distance(pilot, position) }
}

/// The galactic jump's effect on the universe (RULES A.5.7 steps 1 to 4): the next galaxy, and
/// the system nearest (96, 96) in it, which becomes the current system, the selected system and
/// the cursor's position, with distance 0.
pub fn reach_jump(galaxy: Galaxy) -> (Galaxy, Selection) {
    let next = galaxy.next();
    let landing = select(next, REACH_JUMP_CURSOR, REACH_JUMP_CURSOR);
    (next, Selection { distance: 0, ..landing })
}

/// True when the normal jump's random byte means a mis-jump (RULES A.5.5 step 2).
pub fn is_misjump(byte: u8) -> bool {
    byte >= MISJUMP_FROM
}

/// Where a mis-jump leaves the pilot: the departure position with the low 5 bits of y flipped
/// (RULES A.5.5, A.14 item 6).
pub fn misjump_position(departure: Point) -> Point {
    (departure.0, departure.1 ^ 0x1F)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::pilot::FULL_TANK;

    #[test]
    fn distance_halves_the_vertical_axis_and_steps_by_4() {
        // dx = 3, dy = 8 >> 1 = 4: root 5, distance 20 (2.0 light years).
        assert_eq!(distance((10, 10), (13, 18)), 20);
        // dy = 9 >> 1 = 4 as well: the halving rounds down.
        assert_eq!(distance((10, 10), (13, 19)), 20);
        // q = 1 + 1 = 2: root 1, distance 4.
        assert_eq!(distance((0, 0), (1, 2)), 4);
        assert_eq!(distance((60, 93), (60, 93)), 0);
        // Symmetric.
        assert_eq!(distance((13, 18), (10, 10)), 20);
    }

    #[test]
    fn distance_wraps_the_sum_of_squares_at_16_bits() {
        // RULES A.14 item 1: dx = 255, dy = 23 gives 65554 → 18 → root 4 → 16.
        assert_eq!(distance((0, 0), (255, 46)), 16);
        // Just below the wrap: dx = 255, dy = 22 gives 65509, root 255, distance 1020.
        assert_eq!(distance((0, 0), (255, 44)), 1020);
    }

    #[test]
    fn range_needs_a_positive_distance_within_the_fuel() {
        assert!(!in_range(0, FULL_TANK));
        assert!(in_range(4, FULL_TANK));
        assert!(in_range(68, 70));
        assert!(in_range(70, 70));
        assert!(!in_range(72, 70));
        assert!(!in_range(4, 0));
    }

    #[test]
    fn jumps_use_the_distance_and_never_go_below_zero() {
        assert_eq!(fuel_after_jump(70, 20), 50);
        assert_eq!(fuel_after_jump(70, 70), 0);
        assert_eq!(fuel_after_jump(70, 0), 70);
        assert_eq!(fuel_after_jump(10, 1020), 0);
    }

    #[test]
    fn ten_systems_lie_within_a_full_tank_of_home() {
        // GDD § 4.2: ten in range, the nearest at 2.0 LY, seven of them factory worlds.
        let g = Galaxy::FIRST;
        let home = g.system(0).position();
        let reachable: Vec<_> = g
            .systems()
            .filter(|s| in_range(distance(home, s.position()), FULL_TANK))
            .collect();
        assert_eq!(reachable.len(), 10);
        let nearest = reachable.iter().map(|s| distance(home, s.position())).min();
        assert_eq!(nearest, Some(20));
        assert_eq!(reachable.iter().filter(|s| !s.is_farm()).count(), 7);
    }

    #[test]
    fn selecting_snaps_to_the_nearest_system_and_measures_from_the_pilot() {
        let g = Galaxy::FIRST;
        // Cursor at home: home selected, distance 0.
        assert_eq!(
            select(g, (60, 93), (60, 93)),
            Selection { system: 0, position: (60, 93), distance: 0 }
        );
        // Cursor one off system 1 at (169, 242), pilot at home: dx = 109, dy = 149 >> 1 = 74,
        // q = 11881 + 5476 = 17357, root 131, distance 524.
        assert_eq!(
            select(g, (168, 241), (60, 93)),
            Selection { system: 1, position: (169, 242), distance: 524 }
        );
    }

    #[test]
    fn reach_jump_lands_nearest_96_96_in_the_next_galaxy() {
        let (next, landing) = reach_jump(Galaxy::FIRST);
        assert_eq!(next, Galaxy::reach(1));
        // In Reach 2 the nearest to (96, 96) by the cheap metric is system 78 at (81, 97).
        assert_eq!(landing, Selection { system: 78, position: (81, 97), distance: 0 });
        assert_eq!(next.system(78).name, "YANEBOHE");
        // From Reach 8 the jump returns to Reach 1, where system 187 at (97, 85) is nearest.
        let (back, landing) = reach_jump(Galaxy::reach(7));
        assert_eq!(back, Galaxy::FIRST);
        assert_eq!(landing, Selection { system: 187, position: (97, 85), distance: 0 });
    }

    #[test]
    fn misjumps_take_253_and_above_and_flip_the_low_5_bits_of_y() {
        assert!(!is_misjump(252));
        assert!(is_misjump(253));
        assert!(is_misjump(255));
        assert_eq!(misjump_position((60, 93)), (60, 93 ^ 31));
        assert_eq!(misjump_position((60, 93)), (60, 66));
    }
}
