//! The player's missiles: arming, unarming, the lock and firing (RULES C.7.1, C.7.2), and how
//! the lock and the missiles in flight follow removals (RULES C.7.4).

use crate::capabilities::ai::{anger, player_missile, retarget_missiles};
use crate::capabilities::bubble::{Bubble, Object};
use crate::capabilities::cockpit::{Cockpit, Message};
use crate::capabilities::combat::lasers::in_sights;
use crate::capabilities::pilot::Pilot;
use crate::capabilities::ships::MISSILE;
use crate::capabilities::space::Vec3;

/// Where the player's missile starts: just below and ahead of the player (RULES B.10.5).
pub const LAUNCH_POSITION: Vec3 = Vec3::new(0.0, -28.0, 14.0);

/// What the fire-missile action did.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MissileFired {
    /// No target was locked: nothing happens.
    NoLock,
    /// The bubble is full: the jammed message shows and the lock is kept.
    Jammed,
    /// The missile flies, in this slot.
    Launched(usize),
}

/// The target action (RULES C.7.1): with no lock held and a missile carried, the missile is
/// armed and searches. Returns whether it armed.
pub fn arm_missile(pilot: &Pilot, cockpit: &mut Cockpit) -> bool {
    let arm = cockpit.missile.target.is_none() && pilot.missiles > 0;
    if arm {
        cockpit.missile.armed = true;
    }
    arm
}

/// The unarm action (RULES C.7.1): with a missile carried, the lock and the arming are cleared
/// (even if neither was set). Returns whether it acted (the long beep plays).
pub fn unarm_missile(pilot: &Pilot, cockpit: &mut Cockpit) -> bool {
    let act = pilot.missiles > 0;
    if act {
        cockpit.missile.clear();
    }
    act
}

/// The lock during the slot loop (RULES C.7.1, C.4 step 7): while armed, the object in `slot`
/// is locked when it is in the active mount's sights (deliberate difference 8); arming clears.
/// Returns whether it locked (the beep plays).
pub fn try_lock(cockpit: &mut Cockpit, bubble: &Bubble, slot: usize) -> bool {
    let lock = cockpit.missile.armed && bubble.get(slot).is_some_and(|o| in_sights(o, cockpit.active_mount));
    if lock {
        cockpit.missile.target = Some(slot);
        cockpit.missile.armed = false;
    }
    lock
}

/// The fire action (RULES C.7.2): with a target locked, a missile is added at (0, −28, 14), nose
/// (0, 0, 1), side (−1, 0, 0), roof (0, 1, 0), speed (2 × the player's speed) AND 255, AI byte
/// 0x80 OR (target × 2). If the bubble is full the jammed message shows and nothing else
/// changes; otherwise the target becomes angry, the lock clears and one missile is used.
pub fn fire_missile(pilot: &mut Pilot, cockpit: &mut Cockpit, bubble: &mut Bubble) -> MissileFired {
    let Some(target) = cockpit.missile.target else {
        return MissileFired::NoLock;
    };
    let mut missile = Object::new(MISSILE, LAUNCH_POSITION);
    missile.nose = Vec3::new(0.0, 0.0, 1.0);
    missile.side = Vec3::new(-1.0, 0.0, 0.0);
    missile.roof = Vec3::new(0.0, 1.0, 0.0);
    missile.speed = cockpit.speed.wrapping_mul(2);
    missile.ai = player_missile(target);
    let Some(slot) = bubble.add(missile) else {
        cockpit.show(Message::MissileJammed);
        return MissileFired::Jammed;
    };
    anger(bubble, target);
    cockpit.missile.clear();
    pilot.missiles = pilot.missiles.saturating_sub(1);
    MissileFired::Launched(slot)
}

/// After the object in `slot` left the bubble by a shifting removal (RULES C.4 step 8, C.7.4,
/// B.9.4): the player's missiles in flight are retargeted, then the lock follows. Returns true
/// when the lock was on it, which is when the target-lost message shows.
pub fn fix_up_after_removal(cockpit: &mut Cockpit, bubble: &mut Bubble, slot: usize) -> bool {
    retarget_missiles(bubble, slot);
    fix_up_lock(cockpit, slot)
}

/// The lock's part of a removal (RULES C.7.4): a lock on `slot` is dropped with the
/// target-lost message, a lock on a later slot moves down one. The station's replacement by the
/// sun calls only this, with no missile retargeting (RULES B.9.4, Q-B5).
pub fn fix_up_lock(cockpit: &mut Cockpit, slot: usize) -> bool {
    let lost = cockpit.missile.on_removed(slot);
    if lost {
        cockpit.show(Message::TargetLost);
    }
    lost
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::ai::ACTIVE;
    use crate::capabilities::cockpit::MissileLock;
    use crate::capabilities::ships::{PLANET_A, SMALL_PIRATE_A, STATION, SUN, TRADER};
    use crate::capabilities::space::SignMagnitude;

    #[test]
    fn arming_needs_a_missile_and_no_lock() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        assert!(arm_missile(&pilot, &mut cockpit));
        assert!(cockpit.missile.armed);
        cockpit.missile = MissileLock { armed: false, target: Some(3) };
        assert!(!arm_missile(&pilot, &mut cockpit));
        assert!(!cockpit.missile.armed);
        cockpit.missile.clear();
        pilot.missiles = 0;
        assert!(!arm_missile(&pilot, &mut cockpit));
    }

    #[test]
    fn unarming_needs_a_missile() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        cockpit.missile = MissileLock { armed: true, target: Some(3) };
        pilot.missiles = 0;
        assert!(!unarm_missile(&pilot, &mut cockpit));
        assert_eq!(cockpit.missile.target, Some(3));
        pilot.missiles = 1;
        assert!(unarm_missile(&pilot, &mut cockpit));
        assert_eq!(cockpit.missile, MissileLock::default());
    }

    #[test]
    fn an_armed_missile_locks_the_first_ship_in_the_active_mounts_sights() {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 50_000.0)));
        b.add(Object::new(SUN, Vec3::new(0.0, 0.0, 300.0)));
        let ahead = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(10.0, 0.0, 900.0))).unwrap();
        let behind = b.add(Object::new(SMALL_PIRATE_A, Vec3::new(0.0, 0.0, -900.0))).unwrap();
        let mut cockpit = Cockpit::new();
        assert!(!try_lock(&mut cockpit, &b, ahead), "not armed");
        cockpit.missile.armed = true;
        cockpit.active_mount = 1;
        assert!(!try_lock(&mut cockpit, &b, 0) && !try_lock(&mut cockpit, &b, 1), "bodies never lock");
        assert!(!try_lock(&mut cockpit, &b, ahead), "the rear mount looks the other way");
        assert!(try_lock(&mut cockpit, &b, behind));
        assert_eq!(cockpit.missile, MissileLock { armed: false, target: Some(behind) });
        assert!(!try_lock(&mut cockpit, &b, behind), "once locked, no longer armed");
    }

    fn locked_on_trader() -> (Pilot, Cockpit, Bubble, usize) {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::new(0.0, 0.0, 50_000.0)));
        let mut station = Object::new(STATION, Vec3::new(0.0, 0.0, 20_000.0));
        station.ai = 1;
        b.add(station);
        let mut trader = Object::new(TRADER, Vec3::new(0.0, 0.0, 900.0));
        trader.ai = 0x20;
        let target = b.add(trader).unwrap();
        let mut cockpit = Cockpit::new();
        cockpit.speed = 200;
        cockpit.missile.target = Some(target);
        (Pilot::start(), cockpit, b, target)
    }

    #[test]
    fn firing_launches_ahead_and_angers_the_target() {
        let (mut pilot, mut cockpit, mut b, target) = locked_on_trader();
        let fired = fire_missile(&mut pilot, &mut cockpit, &mut b);
        assert_eq!(fired, MissileFired::Launched(3));
        let m = b.get(3).unwrap();
        assert_eq!((m.kind, m.position, m.ai), (MISSILE, LAUNCH_POSITION, 0x84));
        assert_eq!((m.nose, m.side, m.roof), (Vec3::new(0.0, 0.0, 1.0), Vec3::new(-1.0, 0.0, 0.0), Vec3::new(0.0, 1.0, 0.0)));
        assert_eq!(m.speed, 144, "(2 × 200) AND 255");
        assert_eq!((m.pitch, m.roll), (SignMagnitude::ZERO, SignMagnitude::ZERO));
        assert_eq!(b.get(target).unwrap().ai, 0xA0, "the trader wakes");
        assert_eq!(b.get(1).unwrap().ai, 1 | ACTIVE, "and the station turns hostile");
        assert_eq!(cockpit.missile, MissileLock::default());
        assert_eq!(pilot.missiles, 2);
    }

    #[test]
    fn firing_without_a_lock_does_nothing() {
        let mut pilot = Pilot::start();
        let mut cockpit = Cockpit::new();
        cockpit.missile.armed = true;
        let mut b = Bubble::new();
        assert_eq!(fire_missile(&mut pilot, &mut cockpit, &mut b), MissileFired::NoLock);
        assert!(b.is_empty());
        assert_eq!(pilot.missiles, 3);
    }

    #[test]
    fn a_full_bubble_jams_and_keeps_everything() {
        let (mut pilot, mut cockpit, mut b, target) = locked_on_trader();
        while b.add(Object::new(SUN, Vec3::ZERO)).is_some() {}
        assert_eq!(fire_missile(&mut pilot, &mut cockpit, &mut b), MissileFired::Jammed);
        assert_eq!(cockpit.message, Some(Message::MissileJammed));
        assert_eq!(cockpit.missile.target, Some(target));
        assert_eq!(pilot.missiles, 3);
        assert_eq!(b.get(target).unwrap().ai, 0x20, "no anger");
        assert_eq!(b.get(1).unwrap().ai, 1);
    }

    #[test]
    fn a_removal_retargets_missiles_and_drops_or_moves_the_lock() {
        let mut b = Bubble::new();
        b.add(Object::new(PLANET_A, Vec3::ZERO));
        b.add(Object::new(SUN, Vec3::ZERO));
        b.add(Object::new(SMALL_PIRATE_A, Vec3::ZERO));
        let mut m = Object::new(MISSILE, Vec3::ZERO);
        m.ai = player_missile(4);
        let missile = b.add(m).unwrap();
        b.add(Object::new(TRADER, Vec3::ZERO));
        let mut cockpit = Cockpit::new();
        cockpit.missile.target = Some(4);
        b.remove(2);
        assert!(!fix_up_after_removal(&mut cockpit, &mut b, 2));
        assert_eq!(cockpit.missile.target, Some(3));
        assert_eq!(b.get(missile - 1).unwrap().ai, player_missile(3));
        b.remove(3);
        assert!(fix_up_after_removal(&mut cockpit, &mut b, 3));
        assert_eq!(cockpit.missile, MissileLock::default());
        assert_eq!(cockpit.message, Some(Message::TargetLost));
        assert_eq!(b.get(2).unwrap().ai, 0, "its missile goes unguided");
    }

    #[test]
    fn the_station_replacement_moves_only_the_lock() {
        let mut cockpit = Cockpit::new();
        cockpit.missile.target = Some(5);
        assert!(!fix_up_lock(&mut cockpit, 1));
        assert_eq!(cockpit.missile.target, Some(4));
        assert_eq!(cockpit.message, None);
    }
}
