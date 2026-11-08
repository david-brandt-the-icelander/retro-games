//! The bubble: the ordered list of at most 13 objects near the player (RULES B.9, C.1, C.3.3).
//!
//! Slot 0 is the planet and slot 1 the sun or the station, outside the mis-jump zone; ships
//! follow in the order added. Adding to a full bubble silently fails; removing shifts later
//! objects down one slot. Placement rules and the station's replacement by the sun belong to the
//! features that use them; this capability only keeps the list and the per-type counts.

use crate::capabilities::ships::{self, TypeNumber};
use crate::capabilities::space::{SignMagnitude, Vec3};

/// The most objects the bubble holds.
pub const CAPACITY: usize = 13;

/// One object in the bubble: a ship, a missile, a rock, a canister, a pod, the station, a planet
/// or the sun.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Object {
    pub kind: TypeNumber,
    /// Position relative to the player, in sim units.
    pub position: Vec3,
    /// The direction it points and travels.
    pub nose: Vec3,
    /// Its up.
    pub roof: Vec3,
    /// Its side (left-handed when the roof is up; RULES C.1).
    pub side: Vec3,
    /// Own speed, 0..top speed.
    pub speed: u8,
    /// A one-tick acceleration, read as a signed byte.
    pub acceleration: u8,
    pub pitch: SignMagnitude,
    pub roll: SignMagnitude,
    /// The AI byte (RULES C.3.3): bit 7 active, bits 1..6 aggression, bit 0 E.C.M.; for a
    /// missile, bit 6 hostile and bits 1..5 the target slot.
    pub ai: u8,
    pub energy: u8,
    pub missiles: u8,
    pub flags: Flags,
    pub explosion: Explosion,
}

/// Status flags (RULES C.3.3). `firing`, `on_screen` and `on_scanner` serve the picture.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Flags {
    pub killed: bool,
    pub exploding: bool,
    pub firing: bool,
    pub on_screen: bool,
    pub on_scanner: bool,
}

/// The explosion cloud's counter and the four seed bytes drawn when it starts (RULES C.12).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Explosion {
    pub counter: u8,
    pub seeds: [u8; 4],
}

impl Object {
    /// A new object of `kind` with the type's energy and missile load, the default orientation
    /// (nose toward the player), speed 0 and counters 0 (RULES B.2, B.9.3).
    pub fn new(kind: TypeNumber, position: Vec3) -> Self {
        let (energy, missiles) = ships::stats(kind).map_or((0, 0), |s| (s.energy, s.missiles & 7));
        Self {
            kind,
            position,
            nose: Vec3::new(0.0, 0.0, -1.0),
            roof: Vec3::new(0.0, 1.0, 0.0),
            side: Vec3::new(1.0, 0.0, 0.0),
            speed: 0,
            acceleration: 0,
            pitch: SignMagnitude::ZERO,
            roll: SignMagnitude::ZERO,
            ai: 0,
            energy,
            missiles,
            flags: Flags::default(),
            explosion: Explosion::default(),
        }
    }

    /// True for planets and the sun.
    pub fn is_body(&self) -> bool {
        ships::is_body(self.kind)
    }
}

/// What removing an object did, for the rules that react to it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Removed {
    pub slot: usize,
    pub kind: TypeNumber,
}

/// The ordered list of objects near the player, with a count per type.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Bubble {
    slots: Vec<Object>,
    counts: [u8; ships::LAST_SHIP as usize + 1],
}

impl Bubble {
    pub fn new() -> Self {
        Self::default()
    }

    /// Appends an object after the last occupied slot. Returns its slot, or `None` when the
    /// bubble is full, in which case nothing changes (RULES B.9.1).
    pub fn add(&mut self, object: Object) -> Option<usize> {
        if self.slots.len() >= CAPACITY {
            return None;
        }
        self.count(object.kind, true);
        self.slots.push(object);
        Some(self.slots.len() - 1)
    }

    /// Removes the object in `slot`; later objects shift down one slot.
    pub fn remove(&mut self, slot: usize) -> Option<Removed> {
        if slot >= self.slots.len() {
            return None;
        }
        let object = self.slots.remove(slot);
        self.count(object.kind, false);
        Some(Removed { slot, kind: object.kind })
    }

    /// Replaces the object in `slot` without shifting anything (the station and the sun swap
    /// this way, RULES B.9.4 and B.11.1). Counts follow the change.
    pub fn replace(&mut self, slot: usize, object: Object) -> Option<Object> {
        let old = *self.slots.get(slot)?;
        self.count(old.kind, false);
        self.count(object.kind, true);
        self.slots[slot] = object;
        Some(old)
    }

    /// Empties the bubble.
    pub fn clear(&mut self) {
        self.slots.clear();
        self.counts = Default::default();
    }

    /// How many ships of `kind` are present (always 0 for bodies, which are not counted).
    pub fn count_of(&self, kind: TypeNumber) -> u8 {
        self.counts.get(usize::from(kind)).copied().unwrap_or(0)
    }

    /// The first slot holding an object of `kind`.
    pub fn find(&self, kind: TypeNumber) -> Option<usize> {
        self.slots.iter().position(|o| o.kind == kind)
    }

    pub fn len(&self) -> usize {
        self.slots.len()
    }

    pub fn is_empty(&self) -> bool {
        self.slots.is_empty()
    }

    pub fn is_full(&self) -> bool {
        self.slots.len() >= CAPACITY
    }

    pub fn get(&self, slot: usize) -> Option<&Object> {
        self.slots.get(slot)
    }

    pub fn get_mut(&mut self, slot: usize) -> Option<&mut Object> {
        self.slots.get_mut(slot)
    }

    pub fn iter(&self) -> impl Iterator<Item = &Object> {
        self.slots.iter()
    }

    pub fn iter_mut(&mut self) -> impl Iterator<Item = &mut Object> {
        self.slots.iter_mut()
    }

    fn count(&mut self, kind: TypeNumber, up: bool) {
        if let Some(c) = self.counts.get_mut(usize::from(kind)) {
            *c = if up { c.saturating_add(1) } else { c.saturating_sub(1) };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ships::{CANISTER, PLANET_A, POLICE, STATION, SUN};

    #[test]
    fn new_objects_take_their_type_and_the_default_orientation() {
        let o = Object::new(POLICE, Vec3::new(1.0, 2.0, 3.0));
        assert_eq!(o.energy, 120);
        assert_eq!(o.missiles, 2);
        assert_eq!(o.nose, Vec3::new(0.0, 0.0, -1.0));
        assert_eq!(o.speed, 0);
        let p = Object::new(PLANET_A, Vec3::ZERO);
        assert!(p.is_body() && p.energy == 0);
    }

    #[test]
    fn adding_stops_at_thirteen_and_removing_shifts_down() {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::ZERO));
        b.add(Object::new(SUN, Vec3::ZERO));
        for _ in 0..11 {
            assert!(b.add(Object::new(CANISTER, Vec3::ZERO)).is_some());
        }
        assert!(b.add(Object::new(POLICE, Vec3::ZERO)).is_none(), "full bubble refuses silently");
        assert_eq!(b.count_of(CANISTER), 11);
        assert_eq!(b.count_of(POLICE), 0);
        b.get_mut(3).unwrap().speed = 9;
        b.remove(2);
        assert_eq!(b.get(2).unwrap().speed, 9, "later objects shift down");
        assert_eq!(b.count_of(CANISTER), 10);
    }

    #[test]
    fn replacing_keeps_slots_and_fixes_counts() {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::ZERO));
        b.add(Object::new(STATION, Vec3::ZERO));
        b.replace(1, Object::new(SUN, Vec3::ZERO));
        assert_eq!(b.count_of(STATION), 0);
        assert_eq!(b.get(1).unwrap().kind, SUN);
        assert_eq!(b.find(SUN), Some(1));
    }
}
