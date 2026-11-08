//! LodeStar's infrastructure: the implementations of traits the inner layers own, on the real
//! machine (docs/DESIGN.md § Project layout). So far, pilot records as files on disk behind the
//! saving feature's `PilotStore`. See `infrastructure.md` beside this crate's folder.

mod pilot_files;

pub use pilot_files::{PilotFiles, RECORD_EXTENSION};
