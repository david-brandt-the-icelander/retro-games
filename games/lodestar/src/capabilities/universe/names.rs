//! Names, inhabitants and display labels: RULES A.3.5 and A.3.6 for the structure, the GDD
//! (§ 4.2 to § 4.5) for the words.

use super::galaxy::Seed;

/// The syllable table (GDD § 4.2). Entry 0 prints nothing.
pub const SYLLABLES: [&str; 32] = [
    "", "KA", "LO", "VI", "NE", "SE", "BO", "O", "MI", "DA", "RU", "EL", "HA", "NO", "PA", "I",
    "YA", "TO", "FE", "UN", "KE", "MO", "IR", "SA", "VO", "E", "NI", "HE", "DU", "LI", "OS", "TU",
];

/// The inhabitants of a system whose bit 7 of `b4` is clear (GDD § 4.5).
pub const DEFAULT_SETTLERS: &str = "Settler families";
/// List S, size words.
pub const SIZES: [&str; 3] = ["Towering", "Wiry", "Stunted"];
/// List C, colour words.
pub const COLOURS: [&str; 6] = ["Ochre", "Slate", "Rust", "Ivory", "Teal", "Violet"];
/// List K, body words.
pub const BODIES: [&str; 6] = ["Scaled", "Plated", "Downy", "Tusked", "Spined", "Webbed"];
/// List N, creature words (printed with one plural mark).
pub const CREATURES: [&str; 8] =
    ["Otter", "Badger", "Squid", "Snail", "Stag", "Eel", "Hound", "Bat"];

/// The Reach names, by internal galaxy number (GDD § 4.3).
pub const REACHES: [&str; 8] = [
    "Amber Reach",
    "Rose Reach",
    "Teal Reach",
    "Violet Reach",
    "Gilt Reach",
    "Jade Reach",
    "Rust Reach",
    "Steel Reach",
];

/// The printed economy, by code (GDD § 4.4).
pub const ECONOMIES: [&str; 8] = [
    "Wealthy factory world",
    "Working factory world",
    "Lean factory world",
    "Mixed, factory-led",
    "Mixed, farm-led",
    "Wealthy farm world",
    "Working farm world",
    "Lean farm world",
];

/// The government labels, by code (GDD § 4.4).
pub const GOVERNMENTS: [&str; 8] = [
    "Lawless",
    "Raider haven",
    "Contested",
    "Militia rule",
    "Kin councils",
    "Free charter",
    "Assembly",
    "Protectorate",
];

/// A system's name in capitals (RULES A.3.5): 3 syllables, or 4 when bit 6 of `b0` is set; each
/// takes entry `b5 & 31` of a private copy of the state, then advances the copy once.
pub fn name(seed: Seed) -> String {
    let count = if seed.bytes()[0] & 0x40 != 0 { 4 } else { 3 };
    let mut copy = seed;
    let mut out = String::new();
    for _ in 0..count {
        out.push_str(SYLLABLES[usize::from(copy.bytes()[5] & 31)]);
        copy = copy.advanced();
    }
    out
}

/// A system's inhabitants phrase, in word case, without brackets (RULES A.3.6).
pub fn inhabitants(seed: Seed) -> String {
    let b = seed.bytes();
    if b[4] & 0x80 == 0 {
        return DEFAULT_SETTLERS.to_string();
    }
    let mut words: Vec<String> = Vec::with_capacity(4);
    let a = b[5] >> 2;
    let size = usize::from(a & 7);
    if size < SIZES.len() {
        words.push(SIZES[size].to_string());
    }
    let colour = usize::from(a >> 3);
    if colour < COLOURS.len() {
        words.push(COLOURS[colour].to_string());
    }
    let k = (b[3] ^ b[1]) & 7;
    if usize::from(k) < BODIES.len() {
        words.push(BODIES[usize::from(k)].to_string());
    }
    let creature = usize::from(((b[5] & 3) + k) & 7);
    words.push(format!("{}s", CREATURES[creature]));
    words.join(" ")
}

/// The Reach's name for an internal galaxy number 0..7.
pub fn reach_name(galaxy: u8) -> &'static str {
    REACHES[usize::from(galaxy & 7)]
}

/// The printed economy for a code 0..7.
pub fn economy_label(economy: u8) -> &'static str {
    ECONOMIES[usize::from(economy & 7)]
}

/// The government label for a code 0..7.
pub fn government_label(government: u8) -> &'static str {
    GOVERNMENTS[usize::from(government & 7)]
}

#[cfg(test)]
mod tests {
    use super::super::galaxy::{Galaxy, GALAXIES};
    use super::*;

    #[test]
    fn three_syllables_when_bit_6_of_b0_is_clear() {
        // b0 = 0x38. b5 & 31 is 0x0E (PA); then after one step 0xA8 & 31 = 8 (MI); then
        // 0xF2 & 31 = 18 (FE).
        assert_eq!(name(Galaxy::FIRST.seed), "PAMIFE");
    }

    #[test]
    fn four_syllables_when_bit_6_of_b0_is_set() {
        // Bit 6 set in b0: (0040 0000 0100) gives b5 = 1 (KA); then (0000 0100 0140): 1 (KA);
        // then (0100 0140 0240): 2 (LO); then (0140 0240 0480): 4 (NE).
        assert_eq!(name(Seed([0x0040, 0x0000, 0x0100])), "KAKALONE");
        // w2 = 0x0F00: b5 & 31 = 15 (I). Step: (0, 0x0F00, 0x0F40): 15 again. Step:
        // (0x0F00, 0x0F40, 0x1E40): b5 = 0x1E = 30 (OS). Step: (0x0F40, 0x1E40, 0x3C80):
        // b5 & 31 = 0x3C & 31 = 28 (DU).
        assert_eq!(name(Seed([0x0040, 0x0000, 0x0F00])), "IIOSDU");
    }

    #[test]
    fn entry_0_prints_nothing_but_still_advances() {
        assert_eq!(name(Seed([0x0000, 0x0000, 0x0000])), "");
        // 3 syllables, the first index 0: (0000 0100 0000) → (0100 0000 0100): 1 (KA) →
        // (0000 0100 0200): 2 (LO).
        assert_eq!(name(Seed([0x0000, 0x0100, 0x0000])), "KALO");
    }

    #[test]
    fn system_names_near_home_follow_from_the_table() {
        let g = Galaxy::FIRST;
        let names: Vec<String> = [1, 2, 3, 4, 5].iter().map(|&i| g.system(i).name).collect();
        assert_eq!(names, ["NENOFE", "KAKEIR", "HASANI", "YADAE", "SANEIRU"]);
    }

    #[test]
    fn default_settlers_when_bit_7_of_b4_is_clear() {
        assert_eq!(inhabitants(Galaxy::FIRST.seed), DEFAULT_SETTLERS);
    }

    #[test]
    fn inhabitant_words_by_hand() {
        // System 2: b4 = 0xD1, b5 = 0xA0, b3 = 0xF2, b1 = 0xCD. a = 40: size 0 (Towering),
        // colour 5 (Violet); k = (0xF2 ^ 0xCD) & 7 = 7: no body word; creature (0 + 7) & 7 = 7.
        assert_eq!(Galaxy::FIRST.system(2).inhabitants, "Towering Violet Bats");
        // System 4: b5 = 0xB0, a = 44: size 4 (none), colour 5 (Violet); k = (0xFE ^ 0x7A) & 7
        // = 4 (Spined); creature (0 + 4) & 7 = 4 (Stag).
        assert_eq!(Galaxy::FIRST.system(4).inhabitants, "Violet Spined Stags");
    }

    #[test]
    fn all_four_words_and_the_creature_index_wraps() {
        // b5 = 0x0B: a = 2 (Stunted), colour 0 (Ochre); b3 ^ b1 = 5 (Webbed);
        // creature ((0x0B & 3) + 5) & 7 = 0 (Otter).
        let seed = Seed([0x0000, 0x0500, 0x0B80]);
        assert_eq!(inhabitants(seed), "Stunted Ochre Webbed Otters");
        // Only the creature: size 3+, colour 6+, body 6+. b5 = 0xFC: a = 63.
        let seed = Seed([0x0000, 0x0600, 0xFC80]);
        assert_eq!(inhabitants(seed), "Hounds");
    }

    #[test]
    fn longest_inhabitant_phrase_fits_the_gdd_budget() {
        // GDD § 4.5: the longest phrase is 30 characters.
        let longest = (0..GALAXIES)
            .flat_map(|g| Galaxy::reach(g).systems())
            .map(|s| s.inhabitants.len())
            .max();
        assert_eq!(longest, Some(30));
    }

    #[test]
    fn labels_come_from_the_gdd() {
        assert_eq!(economy_label(5), "Wealthy farm world");
        assert_eq!(economy_label(3), "Mixed, factory-led");
        assert_eq!(government_label(5), "Free charter");
        assert_eq!(government_label(0), "Lawless");
        assert_eq!(reach_name(0), "Amber Reach");
        assert_eq!(reach_name(7), "Steel Reach");
    }
}
