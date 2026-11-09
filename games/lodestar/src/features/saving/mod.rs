//! Saving and loading the pilot: the two copies (RULES A.7.3), the name prompt (RULES D.6.12),
//! the record in LodeStar's own format and its accept and reject rules (RULES A.8, D.12,
//! deliberate difference 11). See `saving.md`.

mod name;
mod pilots;
mod record;

pub use name::{is_pilot_name, validate_name, NameKey, NamePrompt, MAX_NAME};
pub use pilots::{MemoryStore, PilotStore, Pilots, SaveOutcome};
pub use record::{decode, decode_over, encode, LoadError, HEADER, VERSION};
