//! The saved record: LodeStar's own text format for a pilot (RULES A.8, D.12, deliberate
//! difference 11), written and read by hand.
//!
//! A record is a header line, one `key value…` line per field of RULES A.7.1, and a `check` line:
//!
//! ```text
//! LODESTAR PILOT 1
//! name DRIFTER
//! position 60 93
//! galaxy-state 5D38 3CAC 0E31
//! galaxy 0
//! cash 1000
//! fuel 70
//! lasers 15 0 0 0
//! hold 22
//! cargo 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
//! ecm no
//! fuel-scoop no
//! area-blast no
//! energy-booster no
//! auto-dock no
//! galaxy-drive no
//! escape-pod no
//! missiles 3
//! legal 0
//! availability 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
//! market-byte 0
//! kills 0
//! check 0D765398
//! ```
//!
//! The check is a CRC-32 of the record's canonical text (every line above the check, as
//! [`encode`] writes it) rebuilt from the decoded values, so fields missing from a record take
//! their start values before the check is computed (RULES A.8.3 step 3).

use crate::capabilities::pilot::{
    Fitted, Pilot, BEAM_LASER, FULL_TANK, GOODS, MAX_MISSILES, NO_LASER, PULSE_LASER,
};

use super::name::is_pilot_name;

/// The first words of every record's first line.
pub const HEADER: &str = "LODESTAR PILOT";
/// The format version this code writes and reads.
pub const VERSION: &str = "1";
/// The highest availability a market holds (RULES A.7.1, A.9.4).
pub const MAX_AVAILABILITY: u8 = 63;
/// The highest galaxy number (RULES A.3.1).
pub const LAST_GALAXY: u8 = 7;

/// Why a record was not accepted. Every case is a rejection: loading changes nothing.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LoadError {
    /// No record is stored under the name.
    NotFound,
    /// The first line is not a LodeStar pilot record's header.
    NotARecord,
    /// The header names a format version this code does not read.
    UnsupportedVersion(String),
    /// A field's values do not parse, have the wrong count, or are out of the field's range.
    Malformed { line: usize, key: String },
    /// A field appears twice.
    Duplicate { line: usize, key: String },
    /// The record has no check value.
    MissingCheck,
    /// The check value does not match the fields.
    CheckMismatch,
}

/// The record for `pilot`, check line included.
pub fn encode(pilot: &Pilot) -> String {
    let body = canonical(pilot);
    format!("{body}check {:08X}\n", crc32(body.as_bytes()))
}

/// Reads a record, with the start pilot's values for missing fields.
pub fn decode(text: &str) -> Result<Pilot, LoadError> {
    decode_over(text, &Pilot::start())
}

/// Reads a record, with `start`'s values for fields the record does not have. A record is
/// accepted only when its header is right, every field it has parses within its range (galaxy
/// state exactly three words, cargo and availability exactly 17 entries), no field appears
/// twice, and its check matches. Unknown keys are ignored.
pub fn decode_over(text: &str, start: &Pilot) -> Result<Pilot, LoadError> {
    let mut lines = text
        .lines()
        .enumerate()
        .map(|(index, line)| (index + 1, line.trim()))
        .filter(|(_, line)| !line.is_empty());

    let (_, header) = lines.next().ok_or(LoadError::NotARecord)?;
    let words: Vec<&str> = header.split_ascii_whitespace().collect();
    match words[..] {
        [a, b, version] if [a, b].join(" ") == HEADER => {
            if version != VERSION {
                return Err(LoadError::UnsupportedVersion(version.to_string()));
            }
        }
        _ => return Err(LoadError::NotARecord),
    }

    let mut pilot = start.clone();
    let mut seen: Vec<&str> = Vec::new();
    let mut check = None;
    for (number, line) in lines {
        let mut words = line.split_ascii_whitespace();
        let Some(key) = words.next() else { continue };
        let values: Vec<&str> = words.collect();
        if seen.contains(&key) {
            return Err(LoadError::Duplicate { line: number, key: key.to_string() });
        }
        seen.push(key);
        let read = read_field(&mut pilot, key, &values, &mut check);
        if read.is_none() {
            return Err(LoadError::Malformed { line: number, key: key.to_string() });
        }
    }

    let check = check.ok_or(LoadError::MissingCheck)?;
    if crc32(canonical(&pilot).as_bytes()) != check {
        return Err(LoadError::CheckMismatch);
    }
    Ok(pilot)
}

/// Sets one field from its values; `None` when they are malformed.
fn read_field(pilot: &mut Pilot, key: &str, values: &[&str], check: &mut Option<u32>) -> Option<()> {
    let byte = u64::from(u8::MAX);
    match key {
        "name" => {
            let [name] = values else { return None };
            if !is_pilot_name(name) {
                return None;
            }
            pilot.name = (*name).to_string();
        }
        "position" => {
            let [x, y] = decimals::<2>(values, byte)?;
            pilot.position = (x as u8, y as u8);
        }
        "galaxy-state" => {
            let [w0, w1, w2] = hex_words(values)?;
            pilot.galaxy_state = [w0, w1, w2];
        }
        "galaxy" => pilot.galaxy = decimals::<1>(values, u64::from(LAST_GALAXY))?[0] as u8,
        "cash" => pilot.cash = decimals::<1>(values, u64::MAX)?[0],
        "fuel" => pilot.fuel = decimals::<1>(values, u64::from(FULL_TANK))?[0] as u8,
        "lasers" => {
            let lasers = decimals::<4>(values, byte)?;
            for (mount, value) in pilot.lasers.iter_mut().zip(lasers) {
                let value = value as u8;
                if ![NO_LASER, PULSE_LASER, BEAM_LASER].contains(&value) {
                    return None;
                }
                *mount = value;
            }
        }
        "hold" => pilot.hold = decimals::<1>(values, byte)?[0] as u8,
        "cargo" => pilot.cargo = decimals::<GOODS>(values, byte)?.map(|v| v as u8),
        "ecm" => pilot.fitted.ecm = flag(values)?,
        "fuel-scoop" => pilot.fitted.fuel_scoop = flag(values)?,
        "area-blast" => pilot.fitted.area_blast = flag(values)?,
        "energy-booster" => pilot.fitted.energy_booster = flag(values)?,
        "auto-dock" => pilot.fitted.auto_dock = flag(values)?,
        "galaxy-drive" => pilot.fitted.galaxy_drive = flag(values)?,
        "escape-pod" => pilot.fitted.escape_pod = flag(values)?,
        "missiles" => pilot.missiles = decimals::<1>(values, u64::from(MAX_MISSILES))?[0] as u8,
        "legal" => pilot.legal = decimals::<1>(values, byte)?[0] as u8,
        "availability" => {
            pilot.availability =
                decimals::<GOODS>(values, u64::from(MAX_AVAILABILITY))?.map(|v| v as u8);
        }
        "market-byte" => pilot.market_byte = decimals::<1>(values, byte)?[0] as u8,
        "kills" => pilot.kills = decimals::<1>(values, u64::from(u16::MAX))?[0] as u16,
        "check" => {
            let [value] = values else { return None };
            if value.len() != 8 || !value.bytes().all(|b| b.is_ascii_hexdigit()) {
                return None;
            }
            *check = Some(u32::from_str_radix(value, 16).ok()?);
        }
        _ => {}
    }
    Some(())
}

/// Every line of the record except the check, in the order and spelling `encode` writes.
fn canonical(pilot: &Pilot) -> String {
    let Fitted { ecm, fuel_scoop, area_blast, energy_booster, auto_dock, galaxy_drive, escape_pod } =
        pilot.fitted;
    let yes_no = |on: bool| if on { "yes" } else { "no" };
    let list = |values: &[u8]| values.iter().map(u8::to_string).collect::<Vec<_>>().join(" ");
    let [w0, w1, w2] = pilot.galaxy_state;
    let lines = [
        format!("{HEADER} {VERSION}"),
        format!("name {}", pilot.name),
        format!("position {} {}", pilot.position.0, pilot.position.1),
        format!("galaxy-state {w0:04X} {w1:04X} {w2:04X}"),
        format!("galaxy {}", pilot.galaxy),
        format!("cash {}", pilot.cash),
        format!("fuel {}", pilot.fuel),
        format!("lasers {}", list(&pilot.lasers)),
        format!("hold {}", pilot.hold),
        format!("cargo {}", list(&pilot.cargo)),
        format!("ecm {}", yes_no(ecm)),
        format!("fuel-scoop {}", yes_no(fuel_scoop)),
        format!("area-blast {}", yes_no(area_blast)),
        format!("energy-booster {}", yes_no(energy_booster)),
        format!("auto-dock {}", yes_no(auto_dock)),
        format!("galaxy-drive {}", yes_no(galaxy_drive)),
        format!("escape-pod {}", yes_no(escape_pod)),
        format!("missiles {}", pilot.missiles),
        format!("legal {}", pilot.legal),
        format!("availability {}", list(&pilot.availability)),
        format!("market-byte {}", pilot.market_byte),
        format!("kills {}", pilot.kills),
    ];
    let mut text = lines.join("\n");
    text.push('\n');
    text
}

/// Exactly `N` decimal numbers, each at most `max`.
fn decimals<const N: usize>(values: &[&str], max: u64) -> Option<[u64; N]> {
    if values.len() != N {
        return None;
    }
    let mut out = [0; N];
    for (slot, word) in out.iter_mut().zip(values) {
        if word.is_empty() || !word.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        *slot = word.parse::<u64>().ok().filter(|v| *v <= max)?;
    }
    Some(out)
}

/// Exactly three words of four hex digits: the six bytes of a galaxy state.
fn hex_words(values: &[&str]) -> Option<[u16; 3]> {
    if values.len() != 3 {
        return None;
    }
    let mut out = [0; 3];
    for (slot, word) in out.iter_mut().zip(values) {
        if word.len() != 4 || !word.bytes().all(|b| b.is_ascii_hexdigit()) {
            return None;
        }
        *slot = u16::from_str_radix(word, 16).ok()?;
    }
    Some(out)
}

/// `yes` or `no`.
fn flag(values: &[&str]) -> Option<bool> {
    match values {
        ["yes"] => Some(true),
        ["no"] => Some(false),
        _ => None,
    }
}

/// CRC-32 (the reflected 0xEDB88320 polynomial, as zip and PNG use), bit by bit.
fn crc32(bytes: &[u8]) -> u32 {
    let mut crc = u32::MAX;
    for &byte in bytes {
        crc ^= u32::from(byte);
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !crc
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every field at the top of its range.
    fn extreme_high() -> Pilot {
        Pilot {
            name: "ZZZZZZ9".to_string(),
            position: (255, 255),
            galaxy_state: [0xFFFF; 3],
            galaxy: 7,
            cash: u64::MAX,
            fuel: 70,
            lasers: [BEAM_LASER; 4],
            hold: 255,
            cargo: [255; GOODS],
            fitted: Fitted {
                ecm: true,
                fuel_scoop: true,
                area_blast: true,
                energy_booster: true,
                auto_dock: true,
                galaxy_drive: true,
                escape_pod: true,
            },
            missiles: 4,
            legal: 255,
            availability: [63; GOODS],
            market_byte: 255,
            kills: u16::MAX,
        }
    }

    /// Every field at the bottom of its range.
    fn extreme_low() -> Pilot {
        Pilot {
            name: "0".to_string(),
            position: (0, 0),
            galaxy_state: [0; 3],
            galaxy: 0,
            cash: 0,
            fuel: 0,
            lasers: [NO_LASER; 4],
            hold: 0,
            cargo: [0; GOODS],
            fitted: Fitted::default(),
            missiles: 0,
            legal: 0,
            availability: [0; GOODS],
            market_byte: 0,
            kills: 0,
        }
    }

    /// `pilot`'s record with the line for `key` replaced and the check left as it was (a
    /// malformed line is rejected before the check is looked at).
    fn with_line(pilot: &Pilot, key: &str, line: &str) -> String {
        let body: String = canonical(pilot)
            .lines()
            .map(|l| if l.split(' ').next() == Some(key) { line.to_string() } else { l.to_string() })
            .map(|l| l + "\n")
            .collect();
        format!("{body}check {:08X}\n", crc32(canonical(pilot).as_bytes()))
    }

    /// A record without the line for `key`, check left as the full record's.
    fn without(pilot: &Pilot, key: &str) -> String {
        encode(pilot)
            .lines()
            .filter(|l| l.split(' ').next() != Some(key))
            .map(|l| format!("{l}\n"))
            .collect()
    }

    #[test]
    fn crc32_matches_the_standard_check_value() {
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        assert_eq!(crc32(b""), 0);
    }

    #[test]
    fn the_start_pilot_round_trips() {
        let start = Pilot::start();
        let text = encode(&start);
        assert!(text.starts_with("LODESTAR PILOT 1\nname DRIFTER\nposition 60 93\n"));
        assert!(text.contains("\ngalaxy-state 5D38 3CAC 0E31\n"));
        assert!(text.contains("\nlasers 15 0 0 0\n"));
        // The check of the start pilot's record, computed apart with an independent CRC-32.
        assert!(text.ends_with("\nkills 0\ncheck 0D765398\n"));
        assert_eq!(decode(&text), Ok(start));
    }

    #[test]
    fn extreme_pilots_round_trip() {
        for pilot in [extreme_high(), extreme_low()] {
            assert_eq!(decode(&encode(&pilot)), Ok(pilot));
        }
        let text = encode(&extreme_high());
        assert!(text.contains("\ncash 18446744073709551615\n"));
        assert!(text.contains("\nkills 65535\n"));
    }

    #[test]
    fn a_mixed_pilot_round_trips() {
        let mut pilot = Pilot::start();
        pilot.name = "ACE1".to_string();
        pilot.lasers = [BEAM_LASER, PULSE_LASER, NO_LASER, BEAM_LASER];
        pilot.cargo[3] = 12;
        pilot.cargo[16] = 200;
        pilot.fitted.fuel_scoop = true;
        pilot.fitted.escape_pod = true;
        pilot.availability = [7, 0, 63, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15];
        pilot.market_byte = 0xA7;
        pilot.galaxy_state = [0x0001, 0xABCD, 0x00F0];
        assert_eq!(decode(&encode(&pilot)), Ok(pilot));
    }

    #[test]
    fn blank_lines_extra_spaces_crlf_and_lowercase_hex_are_read() {
        let start = Pilot::start();
        let text = encode(&start)
            .replace("galaxy-state 5D38 3CAC 0E31", "galaxy-state   5d38 3cac\t0e31")
            .replace('\n', "\r\n\r\n");
        let text = format!("\n  {text}");
        assert_eq!(decode(&text), Ok(start));
    }

    #[test]
    fn the_check_is_case_insensitive() {
        let mut pilot = Pilot::start();
        pilot.kills = 3;
        let text = encode(&pilot);
        let (body, check) = text.trim_end().rsplit_once(' ').unwrap();
        assert_eq!(decode(&format!("{body} {}\n", check.to_ascii_lowercase())), Ok(pilot));
    }

    #[test]
    fn missing_fields_take_start_values_before_the_check() {
        // A record without its kills line is accepted when the start value, 0, is what the
        // check was computed over...
        let start = Pilot::start();
        assert_eq!(decode(&without(&start, "kills")), Ok(start.clone()));
        // ...and rejected when the missing field held something else.
        let mut veteran = Pilot::start();
        veteran.kills = 40;
        assert_eq!(decode(&without(&veteran, "kills")), Err(LoadError::CheckMismatch));
    }

    #[test]
    fn missing_fields_take_the_given_start_pilots_values() {
        // The start market is computed by whoever starts a new game (RULES A.9.7).
        let mut start = Pilot::start();
        start.availability = [9; GOODS];
        start.market_byte = 0;
        let text = without(&start, "availability");
        assert_eq!(decode_over(&text, &start), Ok(start.clone()));
        assert_eq!(decode(&text), Err(LoadError::CheckMismatch));
    }

    #[test]
    fn only_a_header_and_a_check_is_the_start_pilot() {
        let start = Pilot::start();
        let check = crc32(canonical(&start).as_bytes());
        assert_eq!(decode(&format!("LODESTAR PILOT 1\ncheck {check:08X}\n")), Ok(start));
    }

    #[test]
    fn a_changed_value_fails_the_check() {
        let text = encode(&Pilot::start()).replace("cash 1000", "cash 9000000");
        assert_eq!(decode(&text), Err(LoadError::CheckMismatch));
        let text = encode(&Pilot::start()).replace("ecm no", "ecm yes");
        assert_eq!(decode(&text), Err(LoadError::CheckMismatch));
    }

    #[test]
    fn a_changed_check_fails() {
        let text = encode(&Pilot::start());
        let (body, check) = text.trim_end().rsplit_once(' ').unwrap();
        let flipped = u32::from_str_radix(check, 16).unwrap() ^ 1;
        assert_eq!(decode(&format!("{body} {flipped:08X}\n")), Err(LoadError::CheckMismatch));
    }

    #[test]
    fn a_record_without_a_check_is_rejected() {
        assert_eq!(decode(&without(&Pilot::start(), "check")), Err(LoadError::MissingCheck));
    }

    #[test]
    fn text_that_is_not_a_record_is_rejected() {
        for text in ["", "\n\n", "hello", "LODESTAR PILOT", "LODESTAR SHIP 1\ncheck 00000000", "{\"name\":\"DRIFTER\"}"] {
            assert_eq!(decode(text), Err(LoadError::NotARecord), "{text:?}");
        }
        // The header must come first.
        let text = format!("name DRIFTER\n{}", encode(&Pilot::start()));
        assert_eq!(decode(&text), Err(LoadError::NotARecord));
    }

    #[test]
    fn another_version_is_rejected() {
        let text = encode(&Pilot::start()).replace("LODESTAR PILOT 1", "LODESTAR PILOT 2");
        assert_eq!(decode(&text), Err(LoadError::UnsupportedVersion("2".to_string())));
    }

    #[test]
    fn a_galaxy_state_must_be_six_bytes() {
        let start = Pilot::start();
        for line in [
            "galaxy-state 5D38 3CAC",
            "galaxy-state 5D38 3CAC 0E31 0000",
            "galaxy-state 5D38 3CAC E31",
            "galaxy-state 5D38 3CAC 00E31",
            "galaxy-state 5D38 3CAC 0G31",
            "galaxy-state",
        ] {
            assert_eq!(
                decode(&with_line(&start, "galaxy-state", line)),
                Err(LoadError::Malformed { line: 4, key: "galaxy-state".to_string() }),
                "{line}"
            );
        }
    }

    #[test]
    fn cargo_and_availability_must_have_seventeen_entries() {
        let start = Pilot::start();
        let sixteen = ["0"; 16].join(" ");
        let eighteen = ["0"; 18].join(" ");
        for key in ["cargo", "availability"] {
            for values in [&sixteen, &eighteen] {
                let text = with_line(&start, key, &format!("{key} {values}"));
                assert!(matches!(decode(&text), Err(LoadError::Malformed { key: k, .. }) if k == key));
            }
        }
    }

    #[test]
    fn values_out_of_their_range_are_rejected() {
        let start = Pilot::start();
        for (key, line) in [
            ("name", "name drifter"),
            ("name", "name ABCDEFGH"),
            ("name", "name"),
            ("name", "name ACE ONE"),
            ("position", "position 256 0"),
            ("position", "position 60"),
            ("position", "position -1 93"),
            ("galaxy", "galaxy 8"),
            ("cash", "cash 18446744073709551616"),
            ("cash", "cash -5"),
            ("cash", "cash +5"),
            ("cash", "cash 1e3"),
            ("cash", "cash 100.0"),
            ("fuel", "fuel 71"),
            ("lasers", "lasers 15 0 0 16"),
            ("lasers", "lasers 15 0 0"),
            ("hold", "hold 256"),
            ("cargo", "cargo 256 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"),
            ("ecm", "ecm true"),
            ("ecm", "ecm"),
            ("missiles", "missiles 5"),
            ("legal", "legal 256"),
            ("availability", "availability 64 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"),
            ("market-byte", "market-byte 256"),
            ("kills", "kills 65536"),
        ] {
            let result = decode(&with_line(&start, key, line));
            assert!(
                matches!(&result, Err(LoadError::Malformed { key: k, .. }) if k == key),
                "{line}: {result:?}"
            );
        }
    }

    #[test]
    fn a_malformed_check_is_rejected() {
        let text = encode(&Pilot::start());
        let (body, _) = text.trim_end().rsplit_once(' ').unwrap();
        for check in ["1234567", "123456789", "1234567G", ""] {
            let result = decode(&format!("{body} {check}\n"));
            assert!(matches!(&result, Err(LoadError::Malformed { key, .. }) if key == "check"), "{check}");
        }
    }

    #[test]
    fn a_field_given_twice_is_rejected() {
        let text = encode(&Pilot::start()).replace("kills 0\n", "kills 0\nkills 0\n");
        assert_eq!(decode(&text), Err(LoadError::Duplicate { line: 23, key: "kills".to_string() }));
    }

    #[test]
    fn unknown_keys_are_ignored() {
        let start = Pilot::start();
        let text = encode(&start).replace("kills 0\n", "kills 0\nnickname Bob the pilot\n");
        assert_eq!(decode(&text), Ok(start));
    }
}
