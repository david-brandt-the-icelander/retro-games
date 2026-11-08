//! Generator states, galaxies and the order of their systems (RULES A.3.1 to A.3.3), and the
//! nearest-system search (RULES A.4.2).

use super::system::{Point, System};

/// The number of galaxies (Reaches).
pub const GALAXIES: u8 = 8;
/// The number of systems in a galaxy.
pub const SYSTEMS: usize = 256;

/// The cheap metric's starting bound in the nearest-system search (RULES A.4.2).
const NEAREST_BOUND: u8 = 127;

/// One system's generator state: three words `w0, w1, w2` (RULES A.3.1).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Seed(pub [u16; 3]);

impl Seed {
    /// The six bytes `b0..b5`: low then high byte of each word.
    pub const fn bytes(self) -> [u8; 6] {
        let [w0, w1, w2] = self.0;
        [w0 as u8, (w0 >> 8) as u8, w1 as u8, (w1 >> 8) as u8, w2 as u8, (w2 >> 8) as u8]
    }

    /// One advance step: `(w1, w2, w0 + w1 + w2)` with a 16-bit wrapping sum (RULES A.3.2).
    pub const fn advanced(self) -> Seed {
        let [w0, w1, w2] = self.0;
        Seed([w1, w2, w0.wrapping_add(w1).wrapping_add(w2)])
    }

    /// The next system's state: four advance steps (RULES A.3.2).
    pub const fn next_system(self) -> Seed {
        self.advanced().advanced().advanced().advanced()
    }

    /// The galactic transform: each of the six bytes rotated left by one bit on its own
    /// (RULES A.3.3).
    pub const fn rotated(self) -> Seed {
        let [w0, w1, w2] = self.0;
        Seed([rotate_bytes(w0), rotate_bytes(w1), rotate_bytes(w2)])
    }
}

/// Rotates the low and high byte of a word left by one bit each, without carrying between them.
const fn rotate_bytes(w: u16) -> u16 {
    let lo = (w as u8).rotate_left(1);
    let hi = ((w >> 8) as u8).rotate_left(1);
    ((hi as u16) << 8) | lo as u16
}

/// A galaxy: its number (0..7, shown as 1..8) and its system-0 state.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Galaxy {
    pub number: u8,
    pub seed: Seed,
}

impl Galaxy {
    /// Reach 1 (internal galaxy 0) with the GDD's starting state (GDD § 4.2).
    pub const FIRST: Galaxy = Galaxy { number: 0, seed: Seed([0x5D38, 0x3CAC, 0x0E31]) };

    /// A galaxy from a pilot's stored number and system-0 state (RULES A.7.1).
    pub const fn new(number: u8, state: [u16; 3]) -> Self {
        Self { number, seed: Seed(state) }
    }

    /// Galaxy `number` (taken mod 8) as reached from galaxy 0 by successive galactic jumps.
    pub const fn reach(number: u8) -> Self {
        let number = number % GALAXIES;
        let mut galaxy = Self::FIRST;
        while galaxy.number != number {
            galaxy = galaxy.next();
        }
        galaxy
    }

    /// The next galaxy: number `(g + 1) mod 8` and the transformed state (RULES A.3.3, A.5.7).
    pub const fn next(self) -> Self {
        Self { number: (self.number + 1) % GALAXIES, seed: self.seed.rotated() }
    }

    /// The galaxy's system-0 state as the pilot stores it.
    pub const fn state(self) -> [u16; 3] {
        self.seed.0
    }

    /// The 256 system states in system order.
    pub fn seeds(self) -> impl Iterator<Item = Seed> {
        std::iter::successors(Some(self.seed), |s| Some(s.next_system())).take(SYSTEMS)
    }

    /// The state of system `index`: system 0's state advanced `4 × index` times.
    pub fn seed_of(self, index: u8) -> Seed {
        (0..index).fold(self.seed, |s, _| s.next_system())
    }

    /// System `index` with every property worked out.
    pub fn system(self, index: u8) -> System {
        System::new(index, self.seed_of(index))
    }

    /// All 256 systems in order.
    pub fn systems(self) -> impl Iterator<Item = System> {
        self.seeds().enumerate().map(|(i, s)| System::new(i as u8, s))
    }

    /// The system nearest `point` by the search's cheap metric (RULES A.4.2): the first with the
    /// smallest `(|dx| >> 1) + (|dy| >> 1)`, or system 0 when none is under 127.
    pub fn nearest(self, point: Point) -> u8 {
        nearest_in(self.seeds().map(|s| {
            let b = s.bytes();
            (b[3], b[1])
        }), point)
    }
}

/// The nearest-system search over positions given in system order (RULES A.4.2).
pub(crate) fn nearest_in(positions: impl Iterator<Item = Point>, (x, y): Point) -> u8 {
    let mut best = NEAREST_BOUND;
    let mut answer = 0;
    for (index, (sx, sy)) in positions.enumerate() {
        let d = (sx.abs_diff(x) >> 1) + (sy.abs_diff(y) >> 1);
        if d < best {
            best = d;
            answer = index as u8;
        }
    }
    answer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bytes_are_low_then_high_of_each_word() {
        assert_eq!(Galaxy::FIRST.seed.bytes(), [0x38, 0x5D, 0xAC, 0x3C, 0x31, 0x0E]);
    }

    #[test]
    fn advance_step_shifts_and_sums_with_carry_between_bytes() {
        // 0x5D38 + 0x3CAC + 0x0E31 = 0xA815: carries cross from the low byte to the high byte.
        assert_eq!(Galaxy::FIRST.seed.advanced(), Seed([0x3CAC, 0x0E31, 0xA815]));
        // The sum wraps at 16 bits.
        assert_eq!(Seed([0xFFFF, 0x0001, 0x0002]).advanced(), Seed([0x0001, 0x0002, 0x0002]));
    }

    #[test]
    fn next_system_is_four_advance_steps() {
        // Steps: (3CAC 0E31 A815), (0E31 A815 F2F2), (A815 F2F2 A938), (F2F2 A938 443F).
        assert_eq!(Galaxy::FIRST.seed.next_system(), Seed([0xF2F2, 0xA938, 0x443F]));
        assert_eq!(Galaxy::FIRST.seed_of(1), Seed([0xF2F2, 0xA938, 0x443F]));
        assert_eq!(Galaxy::FIRST.seed_of(2), Seed([0xCDE0, 0xF288, 0xA0D1]));
    }

    #[test]
    fn seeds_iterate_256_systems_matching_seed_of() {
        let g = Galaxy::FIRST;
        let seeds: Vec<Seed> = g.seeds().collect();
        assert_eq!(seeds.len(), SYSTEMS);
        assert_eq!(seeds[255], g.seed_of(255));
        assert_eq!(g.systems().count(), SYSTEMS);
    }

    #[test]
    fn rotation_keeps_bits_inside_each_byte() {
        // 0x80 → 0x01 and 0x01 → 0x02 within one word: no bit passes to the other byte.
        assert_eq!(Seed([0x0180, 0x8001, 0xFF00]).rotated(), Seed([0x0201, 0x0102, 0xFF00]));
    }

    #[test]
    fn every_reach_start_state_matches_the_gdd_vectors() {
        let gdd: [[u16; 3]; 8] = [
            [0x5D38, 0x3CAC, 0x0E31],
            [0xBA70, 0x7859, 0x1C62],
            [0x75E0, 0xF0B2, 0x38C4],
            [0xEAC1, 0xE165, 0x7089],
            [0xD583, 0xC3CA, 0xE013],
            [0xAB07, 0x8795, 0xC126],
            [0x570E, 0x0F2B, 0x834C],
            [0xAE1C, 0x1E56, 0x0798],
        ];
        let mut g = Galaxy::FIRST;
        for (number, state) in gdd.iter().enumerate() {
            assert_eq!(g.number, number as u8);
            assert_eq!(g.state(), *state, "Reach {}", number + 1);
            assert_eq!(Galaxy::reach(number as u8), g);
            g = g.next();
        }
        // Eight transforms restore galaxy 0.
        assert_eq!(g, Galaxy::FIRST);
    }

    #[test]
    fn first_reach_is_the_pilots_start_galaxy() {
        use crate::capabilities::pilot::{START_GALAXY, START_POSITION};
        assert_eq!(Galaxy::FIRST.state(), START_GALAXY);
        assert_eq!(Galaxy::FIRST.system(0).position(), START_POSITION);
    }

    #[test]
    fn nearest_finds_a_system_exactly_and_by_the_cheap_metric() {
        let g = Galaxy::FIRST;
        assert_eq!(g.nearest((60, 93)), 0);
        // System 1 is at (169, 242); one unit off on each axis halves to 0 + 0.
        assert_eq!(g.nearest((170, 243)), 1);
    }

    #[test]
    fn nearest_ties_go_to_the_lower_number() {
        // GDD § 4.2: Reach 6 has one pair of systems sharing a point.
        let g = Galaxy::reach(5);
        let (a, b) = (g.system(6), g.system(121));
        assert_eq!(a.position(), b.position());
        assert_eq!(g.nearest(a.position()), 6);
        // In the cheap metric, halves round down before adding: 1 and 1 both count 0.
        assert_eq!(nearest_in([(11, 11), (10, 10)].into_iter(), (10, 10)), 0);
    }

    #[test]
    fn nearest_falls_back_to_system_0_when_nothing_is_under_the_bound() {
        // (0,0) to (255,255) is 127 + 127; (0,0) to (254,0) is 127: neither is below 127.
        assert_eq!(nearest_in([(200, 200), (255, 255), (254, 0)].into_iter(), (0, 0)), 0);
        // 126 is below the bound.
        assert_eq!(nearest_in([(255, 255), (252, 0)].into_iter(), (0, 0)), 1);
    }

    #[test]
    fn gdd_generator_properties_hold_in_every_reach() {
        // GDD § 4.2: every Reach has all eight governments, 32 systems each; names have 2..8
        // letters (3..8 in Reach 1, 2 only in Reaches 7 and 8); 2,047 distinct positions.
        let mut positions = 0;
        for number in 0..GALAXIES {
            let systems: Vec<System> = Galaxy::reach(number).systems().collect();
            let mut governments = [0; 8];
            for s in &systems {
                governments[s.government as usize] += 1;
                let len = s.name.len();
                assert!((2..=8).contains(&len), "{}", s.name);
                assert!(len > 2 || number >= 6, "{} in Reach {}", s.name, number + 1);
            }
            assert_eq!(governments, [32; 8]);
            let mut points: Vec<Point> = systems.iter().map(System::position).collect();
            points.sort_unstable();
            points.dedup();
            positions += points.len();
        }
        assert_eq!(positions, 2047);
    }
}
