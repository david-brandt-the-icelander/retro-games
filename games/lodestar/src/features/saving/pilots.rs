//! The playing and the saved pilot (RULES A.7.3), and saving and loading between them and the
//! store (RULES A.8.2, A.8.3).

use std::collections::BTreeMap;

use crate::capabilities::pilot::Pilot;

use super::name::validate_name;
use super::record::{decode_over, encode, LoadError};

/// Where records are kept, by pilot name. Infrastructure implements it with files; the feature
/// never touches the filesystem itself.
pub trait PilotStore {
    /// The record stored under `name`, if there is one.
    fn read(&self, name: &str) -> Option<String>;
    /// Stores `record` under `name`, replacing any record already there (RULES A.14 item 19).
    fn write(&mut self, name: &str, record: String);
}

/// A store held in memory, for tests and for running without a disk.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MemoryStore {
    records: BTreeMap<String, String>,
}

impl MemoryStore {
    pub fn new() -> Self {
        Self::default()
    }

    /// The names that have a record, in order.
    pub fn names(&self) -> impl Iterator<Item = &str> {
        self.records.keys().map(String::as_str)
    }
}

impl PilotStore for MemoryStore {
    fn read(&self, name: &str) -> Option<String> {
        self.records.get(name).cloned()
    }

    fn write(&mut self, name: &str, record: String) {
        self.records.insert(name.to_string(), record);
    }
}

/// What a save did.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SaveOutcome {
    /// The pilot was named, copied to the saved pilot and written to the store.
    Saved,
    /// Not docked: nothing happened.
    NotDocked,
    /// The name was empty (or cancelled): nothing was saved.
    NoName,
}

/// The two copies of the pilot (RULES A.7.3). `playing` is the one the game changes; the saved
/// pilot changes only by saving or loading, and is what death returns to.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pilots {
    /// The pilot being played.
    pub playing: Pilot,
    saved: Pilot,
    start: Pilot,
}

impl Pilots {
    /// At power-on both copies are the start pilot. `start` is also where a loaded record's
    /// missing fields come from, so pass the start pilot with its start market already set
    /// (RULES A.9.7).
    pub fn new(start: Pilot) -> Self {
        Self { playing: start.clone(), saved: start.clone(), start }
    }

    /// The last pilot saved or loaded (the start pilot until then).
    pub fn saved(&self) -> &Pilot {
        &self.saved
    }

    /// Saves the playing pilot under `name` (RULES A.8.2). `name` is what the name prompt
    /// returned; its rules are applied again, so text from anywhere else is safe. Only while
    /// docked, and only with a non-empty name: then the playing pilot takes the name, the saved
    /// pilot becomes a copy of it, and the copy is written to `store` under that name.
    pub fn save(&mut self, name: &str, docked: bool, store: &mut dyn PilotStore) -> SaveOutcome {
        if !docked {
            return SaveOutcome::NotDocked;
        }
        let Some(name) = validate_name(name) else {
            return SaveOutcome::NoName;
        };
        self.playing.name = name;
        self.saved = self.playing.clone();
        store.write(&self.saved.name, encode(&self.saved));
        SaveOutcome::Saved
    }

    /// Loads on the title screen (RULES A.8.3 steps 2 to 5). An empty `name` means the saved
    /// pilot's own name. An accepted record becomes the saved pilot; a missing or rejected one
    /// changes nothing and its error is returned. Either way the playing pilot then becomes a
    /// copy of the saved pilot.
    pub fn load(&mut self, name: &str, store: &dyn PilotStore) -> Result<(), LoadError> {
        let name = validate_name(name).unwrap_or_else(|| self.saved.name.clone());
        let result = store
            .read(&name)
            .ok_or(LoadError::NotFound)
            .and_then(|record| decode_over(&record, &self.start));
        if let Ok(pilot) = &result {
            self.saved = pilot.clone();
        }
        self.restore();
        result.map(|_| ())
    }

    /// The playing pilot becomes a copy of the saved pilot: the title does this whether or not
    /// the pilot chose to load (RULES D.3.1 step 3).
    pub fn restore(&mut self) {
        self.playing = self.saved.clone();
    }

    /// Death: nothing about the dead pilot is kept, and play goes on from the saved pilot
    /// (RULES A.7.3, D.3.10).
    pub fn on_death(&mut self) {
        self.restore();
    }
}

impl Default for Pilots {
    fn default() -> Self {
        Self::new(Pilot::start())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::pilot::{BEAM_LASER, START_NAME};
    use crate::features::saving::record::decode;

    /// A pilot who has played a while.
    fn play(pilots: &mut Pilots) {
        let p = &mut pilots.playing;
        p.cash = 52_345;
        p.kills = 300;
        p.cargo[2] = 10;
        p.lasers[0] = BEAM_LASER;
        p.fitted.fuel_scoop = true;
    }

    #[test]
    fn at_power_on_both_copies_are_the_start_pilot() {
        let pilots = Pilots::default();
        assert_eq!(pilots.playing, Pilot::start());
        assert_eq!(pilots.saved(), &Pilot::start());
    }

    #[test]
    fn saving_names_the_pilot_copies_it_and_writes_it_under_the_name() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        play(&mut pilots);
        assert_eq!(pilots.save("ACE", true, &mut store), SaveOutcome::Saved);
        assert_eq!(pilots.playing.name, "ACE");
        assert_eq!(pilots.saved(), &pilots.playing);
        assert_eq!(store.names().collect::<Vec<_>>(), ["ACE"]);
        assert_eq!(decode(&store.read("ACE").unwrap()).as_ref(), Ok(&pilots.playing));
    }

    #[test]
    fn saving_applies_the_name_rules() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        assert_eq!(pilots.save("ace one!!", true, &mut store), SaveOutcome::Saved);
        assert_eq!(pilots.playing.name, "ACEONE");
        assert!(store.read("ACEONE").is_some());
    }

    #[test]
    fn saving_in_flight_does_nothing() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        play(&mut pilots);
        let before = pilots.clone();
        assert_eq!(pilots.save("ACE", false, &mut store), SaveOutcome::NotDocked);
        assert_eq!(pilots, before);
        assert_eq!(store, MemoryStore::new());
    }

    #[test]
    fn an_empty_or_cancelled_name_saves_nothing() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        play(&mut pilots);
        let before = pilots.clone();
        for name in ["", "!!!"] {
            assert_eq!(pilots.save(name, true, &mut store), SaveOutcome::NoName);
        }
        assert_eq!(pilots, before);
        assert_eq!(store, MemoryStore::new());
    }

    #[test]
    fn saving_under_an_existing_name_replaces_it() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        pilots.save("ACE", true, &mut store);
        play(&mut pilots);
        pilots.save("ACE", true, &mut store);
        assert_eq!(store.names().count(), 1);
        assert_eq!(decode(&store.read("ACE").unwrap()).unwrap().kills, 300);
    }

    #[test]
    fn death_returns_to_the_saved_copy() {
        let mut pilots = Pilots::default();
        let mut store = MemoryStore::new();
        pilots.playing.cash = 2_000;
        pilots.save("ACE", true, &mut store);
        let saved = pilots.saved().clone();
        play(&mut pilots);
        pilots.on_death();
        assert_eq!(pilots.playing, saved);
        assert_eq!(pilots.playing.cash, 2_000);
    }

    #[test]
    fn death_before_any_save_returns_to_the_start_pilot() {
        let mut pilots = Pilots::default();
        play(&mut pilots);
        pilots.on_death();
        assert_eq!(pilots.playing, Pilot::start());
    }

    #[test]
    fn loading_an_accepted_record_makes_it_the_saved_and_the_playing_pilot() {
        let mut store = MemoryStore::new();
        let mut first = Pilots::default();
        play(&mut first);
        first.save("ACE", true, &mut store);

        let mut pilots = Pilots::default();
        assert_eq!(pilots.load("ace", &store), Ok(()));
        assert_eq!(pilots.saved(), first.saved());
        assert_eq!(&pilots.playing, first.saved());
    }

    #[test]
    fn an_empty_name_loads_the_saved_pilots_own_name() {
        let mut store = MemoryStore::new();
        let mut pilots = Pilots::default();
        pilots.save("ACE", true, &mut store);
        // Another session writes a newer ACE record.
        let mut other = Pilots::default();
        play(&mut other);
        other.save("ACE", true, &mut store);

        assert_eq!(pilots.load("", &store), Ok(()));
        assert_eq!(pilots.saved().kills, 300);
    }

    #[test]
    fn an_empty_name_with_the_start_pilot_looks_up_the_default_name() {
        let mut store = MemoryStore::new();
        let mut someone = Pilots::default();
        someone.save(START_NAME, true, &mut store);
        let mut pilots = Pilots::default();
        assert_eq!(pilots.load("", &store), Ok(()));
        assert_eq!(pilots.load("", &MemoryStore::new()), Err(LoadError::NotFound));
    }

    #[test]
    fn a_missing_record_changes_nothing_but_the_playing_copy_still_resets() {
        let mut store = MemoryStore::new();
        let mut pilots = Pilots::default();
        pilots.playing.cash = 2_000;
        pilots.save("ACE", true, &mut store);
        let saved = pilots.saved().clone();
        play(&mut pilots);
        assert_eq!(pilots.load("NOBODY", &store), Err(LoadError::NotFound));
        assert_eq!(pilots.saved(), &saved);
        assert_eq!(pilots.playing, saved);
    }

    #[test]
    fn a_rejected_record_changes_nothing() {
        let mut store = MemoryStore::new();
        let mut pilots = Pilots::default();
        pilots.save("ACE", true, &mut store);
        let tampered = store.read("ACE").unwrap().replace("cash 1000", "cash 99999999");
        store.write("RICH", tampered);
        let saved = pilots.saved().clone();
        assert_eq!(pilots.load("RICH", &store), Err(LoadError::CheckMismatch));
        assert_eq!(pilots.saved(), &saved);
        assert_eq!(pilots.playing, saved);

        store.write("JUNK", "not a pilot".to_string());
        assert_eq!(pilots.load("JUNK", &store), Err(LoadError::NotARecord));
        assert_eq!(pilots.saved(), &saved);
    }

    #[test]
    fn a_loaded_records_missing_fields_come_from_the_start_pilot_given() {
        let mut start = Pilot::start();
        start.availability = [5; crate::capabilities::pilot::GOODS];
        let record = encode(&start);
        let record: String = record
            .lines()
            .filter(|l| !l.starts_with("availability"))
            .map(|l| format!("{l}\n"))
            .collect();
        let mut store = MemoryStore::new();
        store.write("DRIFTER", record);
        let mut pilots = Pilots::new(start.clone());
        assert_eq!(pilots.load("", &store), Ok(()));
        assert_eq!(pilots.saved(), &start);
    }

    #[test]
    fn skipping_the_load_still_starts_from_the_saved_pilot() {
        let mut store = MemoryStore::new();
        let mut pilots = Pilots::default();
        pilots.save("ACE", true, &mut store);
        let saved = pilots.saved().clone();
        play(&mut pilots);
        pilots.restore();
        assert_eq!(pilots.playing, saved);
    }
}
