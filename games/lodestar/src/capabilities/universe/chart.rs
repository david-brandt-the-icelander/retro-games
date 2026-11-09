//! The charts' behaviour as pure functions (RULES A.6, D.6.6, D.6.7): the cursor and its keys,
//! the fuel-range circles, and which systems the local chart shows, where, and with which labels.

use super::galaxy::Galaxy;
use super::navigation::{select, Selection};
use super::system::Point;

/// The screen point the local chart centres the pilot's system on (RULES D.6.7).
pub const LOCAL_CHART_CENTRE: (i16, i16) = (104, 90);
/// The first text row a local-chart label may use; rows above it hold the title (RULES A.6.2).
pub const FIRST_LABEL_ROW: u8 = 3;

/// One arrow key on a chart.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Arrow {
    Left,
    Right,
    Up,
    Down,
}

/// The arrow keys held this tick.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct HeldArrows {
    pub left: bool,
    pub right: bool,
    pub up: bool,
    pub down: bool,
}

/// The chart cursor: a point in galactic coordinates (RULES A.5.1, A.6.3).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ChartCursor {
    pub position: Point,
}

impl ChartCursor {
    pub const fn at(position: Point) -> Self {
        Self { position }
    }

    /// One arrow tap: 1 galactic unit, up being −1 in y. Returns whether the cursor moved
    /// (RULES A.6.3).
    pub fn tap(&mut self, arrow: Arrow) -> bool {
        let (dx, dy) = match arrow {
            Arrow::Left => (-1, 0),
            Arrow::Right => (1, 0),
            Arrow::Up => (0, -1),
            Arrow::Down => (0, 1),
        };
        self.step(dx, dy)
    }

    /// The held-arrow repeat for one logic tick: only docked, only on even ticks, at most one
    /// unit per axis, opposite arrows cancelling. In flight held arrows do nothing. Returns
    /// whether the cursor moved (RULES A.6.3, D.3.3).
    pub fn hold(&mut self, held: HeldArrows, docked: bool, tick: u32) -> bool {
        if !docked || !tick.is_multiple_of(2) {
            return false;
        }
        let dx = i16::from(held.right) - i16::from(held.left);
        let dy = i16::from(held.down) - i16::from(held.up);
        self.step(dx, dy)
    }

    /// The home key: the cursor onto the pilot's position, without selecting (RULES A.6.3).
    pub fn home(&mut self, pilot: Point) {
        self.position = pilot;
    }

    /// Selects from the cursor and snaps the cursor onto the selected system (RULES A.5.1).
    pub fn select(&mut self, galaxy: Galaxy, pilot: Point) -> Selection {
        let selection = select(galaxy, self.position, pilot);
        self.position = selection.position;
        selection
    }

    /// Moves each axis by its delta unless the new value would leave 0..255.
    fn step(&mut self, dx: i16, dy: i16) -> bool {
        let before = self.position;
        if let Ok(x) = u8::try_from(i16::from(self.position.0) + dx) {
            self.position.0 = x;
        }
        if let Ok(y) = u8::try_from(i16::from(self.position.1) + dy) {
            self.position.1 = y;
        }
        self.position != before
    }
}

/// Where a system sits on the galaxy chart: `(x, y / 2)` (RULES A.6.1).
pub const fn galaxy_chart_point(position: Point) -> (u8, u8) {
    (position.0, position.1 >> 1)
}

/// The galaxy chart's fuel-range circle radius: `fuel >> 2` chart units (RULES A.6.1).
pub const fn galaxy_chart_range_radius(fuel: u8) -> u8 {
    fuel >> 2
}

/// The local chart's fuel-range circle radius: `fuel` pixels (RULES A.6.2).
pub const fn local_chart_range_radius(fuel: u8) -> u8 {
    fuel
}

/// Signed galactic offsets from the pilot, with no wrap at the galaxy's edge.
fn offset(pilot: Point, point: Point) -> (i16, i16) {
    (i16::from(point.0) - i16::from(pilot.0), i16::from(point.1) - i16::from(pilot.1))
}

/// Where a system appears on the local chart, or `None` outside its window: shown when
/// `|dx| < 20` and `|dy| < 38`, at `(104 + 4dx, 90 + 2dy)` (RULES A.6.2, D.6.7).
pub fn local_chart_point(pilot: Point, system: Point) -> Option<(i16, i16)> {
    let (dx, dy) = offset(pilot, system);
    (dx.abs() < 20 && dy.abs() < 38)
        .then_some((LOCAL_CHART_CENTRE.0 + 4 * dx, LOCAL_CHART_CENTRE.1 + 2 * dy))
}

/// True when the local chart draws the cursor's cross: `−26 ≤ dx < 38` and `−36 ≤ dy < 38`
/// from the pilot (RULES A.6.2).
pub fn local_cursor_visible(pilot: Point, cursor: Point) -> bool {
    let (dx, dy) = offset(pilot, cursor);
    (-26..38).contains(&dx) && (-36..38).contains(&dy)
}

/// Where the local chart draws the cursor's cross, when it does.
pub fn local_cursor_point(pilot: Point, cursor: Point) -> Option<(i16, i16)> {
    let (dx, dy) = offset(pilot, cursor);
    local_cursor_visible(pilot, cursor)
        .then_some((LOCAL_CHART_CENTRE.0 + 4 * dx, LOCAL_CHART_CENTRE.1 + 2 * dy))
}

/// One system the local chart draws.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LocalChartEntry {
    pub system: u8,
    /// The disc's centre in screen pixels.
    pub point: (i16, i16),
    /// The disc's radius, 2 or 3 pixels.
    pub radius: u8,
    /// The 8-pixel text row of the name, or `None` when the disc has no label.
    pub label_row: Option<u8>,
}

/// The systems the local chart draws, in system order, with their label rows (RULES A.6.2):
/// each label tries its own row, the row below, then the row above, taking the first one no
/// label holds yet. A free row above row 3 hides the system, disc and label; no free row leaves
/// the disc without a label.
pub fn local_chart(galaxy: Galaxy, pilot: Point) -> Vec<LocalChartEntry> {
    let systems = galaxy.systems().map(|s| (s.index, s.position(), s.local_disc_radius()));
    local_chart_entries(systems, pilot)
}

/// The local chart's layout over `(system, position, disc radius)` given in system order.
pub(crate) fn local_chart_entries(
    systems: impl Iterator<Item = (u8, Point, u8)>,
    pilot: Point,
) -> Vec<LocalChartEntry> {
    let mut used = [false; 32];
    let mut entries = Vec::new();
    for (system, position, radius) in systems {
        let Some(point) = local_chart_point(pilot, position) else { continue };
        let row = (point.1 >> 3) as u8;
        let free = [Some(row), row.checked_add(1), row.checked_sub(1)]
            .into_iter()
            .flatten()
            .find(|&r| !used[usize::from(r)]);
        let label_row = match free {
            Some(r) if r < FIRST_LABEL_ROW => continue,
            Some(r) => {
                used[usize::from(r)] = true;
                Some(r)
            }
            None => None,
        };
        entries.push(LocalChartEntry { system, point, radius, label_row });
    }
    entries
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn taps_move_one_unit_with_up_negative() {
        let mut c = ChartCursor::at((10, 10));
        assert!(c.tap(Arrow::Left));
        assert!(c.tap(Arrow::Up));
        assert_eq!(c.position, (9, 9));
        c.tap(Arrow::Right);
        c.tap(Arrow::Right);
        c.tap(Arrow::Down);
        assert_eq!(c.position, (11, 10));
    }

    #[test]
    fn taps_stop_at_the_galaxy_edges() {
        let mut c = ChartCursor::at((0, 255));
        assert!(!c.tap(Arrow::Left));
        assert!(!c.tap(Arrow::Down));
        assert_eq!(c.position, (0, 255));
        let mut c = ChartCursor::at((255, 0));
        assert!(!c.tap(Arrow::Right));
        assert!(!c.tap(Arrow::Up));
        assert_eq!(c.position, (255, 0));
    }

    #[test]
    fn held_arrows_repeat_only_docked_on_even_ticks() {
        let held = HeldArrows { right: true, down: true, ..HeldArrows::default() };
        let mut c = ChartCursor::at((10, 10));
        assert!(!c.hold(held, false, 0), "no repeat in flight");
        assert!(!c.hold(held, true, 1), "odd tick");
        assert!(c.hold(held, true, 2));
        assert_eq!(c.position, (11, 11));
        // Twelve docked ticks move six units: six a second.
        let mut c = ChartCursor::at((10, 10));
        for tick in 0..12 {
            c.hold(HeldArrows { left: true, ..HeldArrows::default() }, true, tick);
        }
        assert_eq!(c.position, (4, 10));
    }

    #[test]
    fn opposite_held_arrows_cancel_and_edges_hold_each_axis_alone() {
        let all = HeldArrows { left: true, right: true, up: true, down: true };
        let mut c = ChartCursor::at((10, 10));
        assert!(!c.hold(all, true, 0));
        // At x = 255 the right arrow is refused but the y axis still moves.
        let mut c = ChartCursor::at((255, 10));
        let held = HeldArrows { right: true, up: true, ..HeldArrows::default() };
        assert!(c.hold(held, true, 0));
        assert_eq!(c.position, (255, 9));
    }

    #[test]
    fn home_puts_the_cursor_on_the_pilot_and_select_snaps_it() {
        let g = Galaxy::FIRST;
        let mut c = ChartCursor::at((168, 241));
        let s = c.select(g, (60, 93));
        assert_eq!((s.system, s.distance), (1, 524));
        assert_eq!(c.position, (169, 242));
        c.home((60, 93));
        assert_eq!(c.position, (60, 93));
    }

    #[test]
    fn galaxy_chart_halves_y_and_quarters_the_fuel() {
        assert_eq!(galaxy_chart_point((60, 93)), (60, 46));
        assert_eq!(galaxy_chart_range_radius(70), 17);
        assert_eq!(galaxy_chart_range_radius(3), 0);
        assert_eq!(local_chart_range_radius(70), 70);
    }

    #[test]
    fn local_chart_window_and_scale() {
        let home = (60, 93);
        assert_eq!(local_chart_point(home, home), Some((104, 90)));
        assert_eq!(local_chart_point(home, (79, 130)), Some((104 + 76, 90 + 74)));
        assert_eq!(local_chart_point(home, (41, 56)), Some((104 - 76, 90 - 74)));
        assert_eq!(local_chart_point(home, (80, 93)), None);
        assert_eq!(local_chart_point(home, (60, 131)), None);
        // Signed differences, no wrap at the galaxy's edge.
        assert_eq!(local_chart_point((2, 2), (255, 2)), None);
        assert_eq!(local_chart_point((2, 2), (0, 0)), Some((96, 86)));
    }

    #[test]
    fn local_cursor_cross_window_is_lopsided() {
        let home = (100, 100);
        assert!(local_cursor_visible(home, (74, 64)));
        assert!(!local_cursor_visible(home, (73, 100)));
        assert!(!local_cursor_visible(home, (100, 63)));
        assert!(local_cursor_visible(home, (137, 137)));
        assert!(!local_cursor_visible(home, (138, 100)));
        assert!(!local_cursor_visible(home, (100, 138)));
        assert_eq!(local_cursor_point(home, (101, 99)), Some((108, 88)));
        assert_eq!(local_cursor_point(home, (138, 100)), None);
    }

    #[test]
    fn labels_take_their_row_then_below_then_above() {
        let pilot = (100, 100);
        // Screen y 90 + 2dy; row = y >> 3. dy = 0 → y 90 → row 11.
        let systems = [
            (0, (100, 100), 2),
            (1, (101, 100), 2),
            (2, (102, 100), 3),
            (3, (103, 100), 2),
        ];
        let entries = local_chart_entries(systems.into_iter(), pilot);
        let rows: Vec<Option<u8>> = entries.iter().map(|e| e.label_row).collect();
        assert_eq!(rows, [Some(11), Some(12), Some(10), None]);
        assert_eq!(entries[2].radius, 3);
        assert_eq!(entries[3].point, (116, 90));
    }

    #[test]
    fn a_free_row_above_row_3_hides_the_system() {
        let pilot = (100, 100);
        // dy = −37 → y 16 → row 2: free, but above row 3, so neither disc nor label.
        let hidden = local_chart_entries([(0, (100, 63), 2)].into_iter(), pilot);
        assert!(hidden.is_empty());
        // dy = −33 → y 24 → row 3: allowed.
        let shown = local_chart_entries([(0, (100, 67), 2)].into_iter(), pilot);
        assert_eq!(shown[0].label_row, Some(3));
        // Two systems on row 3: the second takes row 4. A third on row 3 finds rows 3 and 4
        // used and row 2 free, so it is hidden. A fourth on row 4 finds it used and takes row 5.
        let entries = local_chart_entries(
            [(0, (100, 67), 2), (1, (101, 67), 2), (2, (102, 67), 2), (3, (103, 71), 2)]
                .into_iter(),
            pilot,
        );
        let shown: Vec<(u8, Option<u8>)> =
            entries.iter().map(|e| (e.system, e.label_row)).collect();
        assert_eq!(shown, [(0, Some(3)), (1, Some(4)), (3, Some(5))]);
    }

    #[test]
    fn home_galaxy_local_chart_shows_home_with_a_label() {
        let entries = local_chart(Galaxy::FIRST, (60, 93));
        let home = entries.iter().find(|e| e.system == 0).expect("home is on its own chart");
        assert_eq!((home.point, home.radius, home.label_row), ((104, 90), 2, Some(11)));
        // Fifteen systems fall inside the window around home; system 78's own row is row 2,
        // which is free but above row 3, so the chart hides it (RULES A.14 item 16).
        let shown: Vec<u8> = entries.iter().map(|e| e.system).collect();
        assert_eq!(shown, [0, 22, 36, 40, 50, 53, 54, 113, 160, 186, 195, 213, 240, 246]);
        assert!(local_chart_point((60, 93), Galaxy::FIRST.system(78).position()).is_some());
    }
}
