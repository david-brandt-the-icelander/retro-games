//! Pilot records as files: one `<NAME>.pilot` text file per saved pilot in one folder (docs/DESIGN.md
//! § In-game UI, Saving). The record's format and its accept and reject rules are the saving
//! feature's; this only stores and fetches the text.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use lodestar_core::features::saving::{is_pilot_name, PilotStore};

/// The file extension of a pilot record.
pub const RECORD_EXTENSION: &str = "pilot";

/// A folder of pilot records. The Godot host points it at `user://pilots/`; tests at a scratch
/// folder. The folder is made on the first write.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PilotFiles {
    folder: PathBuf,
}

impl PilotFiles {
    pub fn new(folder: impl Into<PathBuf>) -> Self {
        Self { folder: folder.into() }
    }

    /// The folder the records live in.
    pub fn folder(&self) -> &Path {
        &self.folder
    }

    /// The file a pilot's record is kept in, or `None` for a name no record may hold (so a name
    /// can never reach outside the folder).
    pub fn path_of(&self, name: &str) -> Option<PathBuf> {
        is_pilot_name(name).then(|| self.folder.join(format!("{name}.{RECORD_EXTENSION}")))
    }

    /// The names that have a record file, sorted. A missing folder has none.
    pub fn names(&self) -> Vec<String> {
        let Ok(entries) = fs::read_dir(&self.folder) else { return Vec::new() };
        let mut names: Vec<String> = entries
            .flatten()
            .filter_map(|entry| {
                let path = entry.path();
                if path.extension()? != RECORD_EXTENSION || !path.is_file() {
                    return None;
                }
                let name = path.file_stem()?.to_str()?.to_string();
                is_pilot_name(&name).then_some(name)
            })
            .collect();
        names.sort();
        names
    }

    /// Writes `record` under `name`, through a temporary file renamed into place so a crash never
    /// leaves half a record.
    pub fn try_write(&self, name: &str, record: &str) -> io::Result<()> {
        let path = self
            .path_of(name)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "not a pilot name"))?;
        fs::create_dir_all(&self.folder)?;
        let partial = path.with_extension(format!("{RECORD_EXTENSION}.partial"));
        fs::write(&partial, record)?;
        fs::rename(&partial, &path)
    }
}

impl PilotStore for PilotFiles {
    fn read(&self, name: &str) -> Option<String> {
        fs::read_to_string(self.path_of(name)?).ok()
    }

    /// The trait has no way to report a failed write; the saving feature has already taken the
    /// save in play, and a write that fails leaves the file as it was.
    fn write(&mut self, name: &str, record: String) {
        let _ = self.try_write(name, &record);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use lodestar_core::features::saving::{decode, encode, MemoryStore, Pilots, SaveOutcome};
    use lodestar_core::use_cases::fly_in_system::start_pilot;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// A fresh, empty folder under the system's temporary folder for one test.
    fn scratch() -> PathBuf {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let n = NEXT.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join(format!("lodestar-pilots-{}-{n}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        dir
    }

    #[test]
    fn a_written_record_reads_back_unchanged() {
        let dir = scratch();
        let mut files = PilotFiles::new(&dir);
        let record = encode(&start_pilot());
        files.write("DRIFTER", record.clone());
        assert_eq!(files.read("DRIFTER"), Some(record.clone()));
        assert_eq!(decode(&record), Ok(start_pilot()));
        assert!(dir.join("DRIFTER.pilot").is_file());
        assert!(!dir.join("DRIFTER.pilot.partial").exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_second_write_replaces_the_first() {
        let dir = scratch();
        let mut files = PilotFiles::new(&dir);
        files.write("ACE1", "one".into());
        files.write("ACE1", "two".into());
        assert_eq!(files.read("ACE1").as_deref(), Some("two"));
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_missing_record_or_folder_reads_as_none() {
        let files = PilotFiles::new(scratch());
        assert_eq!(files.read("NOBODY"), None);
        assert!(files.names().is_empty());
    }

    #[test]
    fn names_that_no_record_may_hold_never_touch_the_disk() {
        let dir = scratch();
        let mut files = PilotFiles::new(&dir);
        for bad in ["", "../X", "lower", "TOOLONGX", "A B", "A.B"] {
            assert_eq!(files.path_of(bad), None, "{bad}");
            files.write(bad, "x".into());
            assert_eq!(files.read(bad), None);
        }
        assert!(!dir.exists(), "nothing was written");
    }

    #[test]
    fn names_lists_only_record_files_with_pilot_names_sorted() {
        let dir = scratch();
        let mut files = PilotFiles::new(&dir);
        files.write("ZED", "z".into());
        files.write("ACE1", "a".into());
        fs::write(dir.join("notes.txt"), "x").unwrap();
        fs::write(dir.join("lower.pilot"), "x").unwrap();
        fs::create_dir(dir.join("DIR.pilot")).unwrap();
        assert_eq!(files.names(), vec!["ACE1".to_string(), "ZED".to_string()]);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn the_saving_feature_saves_and_loads_through_files_as_through_memory() {
        let dir = scratch();
        let mut files = PilotFiles::new(&dir);
        let mut memory = MemoryStore::new();
        let mut on_disk = Pilots::new(start_pilot());
        let mut in_memory = Pilots::new(start_pilot());
        on_disk.playing.cash = 12_345;
        in_memory.playing.cash = 12_345;
        assert_eq!(on_disk.save("ace 1", true, &mut files), SaveOutcome::Saved);
        assert_eq!(in_memory.save("ace 1", true, &mut memory), SaveOutcome::Saved);
        assert_eq!(files.read("ACE1"), memory.read("ACE1"));

        let mut fresh = Pilots::new(start_pilot());
        assert_eq!(fresh.load("ACE1", &files), Ok(()));
        assert_eq!(fresh.playing.cash, 12_345);
        assert_eq!(fresh.playing.name, "ACE1");
        fs::remove_dir_all(dir).unwrap();
    }
}
