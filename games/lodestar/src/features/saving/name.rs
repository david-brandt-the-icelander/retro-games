//! The pilot name and the name prompt (RULES A.8.2 step 2, D.6.12).

/// The longest name the prompt takes (RULES A.7.1).
pub const MAX_NAME: usize = 7;

/// One key press given to the name prompt.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NameKey {
    /// A typed character. Letters A–Z and digits are taken (letters in capitals); anything else
    /// is ignored.
    Char(char),
    /// Delete the last character.
    Delete,
    /// Finish with the typed name, which may be empty.
    Confirm,
    /// Finish with an empty name.
    Cancel,
}

/// The name prompt shown for saving and for loading (RULES D.6.12).
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct NamePrompt {
    typed: String,
}

impl NamePrompt {
    /// An empty prompt.
    pub fn new() -> Self {
        Self::default()
    }

    /// What has been typed so far, as the prompt echoes it.
    pub fn typed(&self) -> &str {
        &self.typed
    }

    /// Takes one key. Returns the finished name (possibly empty) on confirm or cancel, and the
    /// prompt starts empty again; returns `None` while the pilot is still typing.
    pub fn press(&mut self, key: NameKey) -> Option<String> {
        match key {
            NameKey::Char(c) => {
                if c.is_ascii_alphanumeric() && self.typed.len() < MAX_NAME {
                    self.typed.push(c.to_ascii_uppercase());
                }
                None
            }
            NameKey::Delete => {
                self.typed.pop();
                None
            }
            NameKey::Confirm => Some(std::mem::take(&mut self.typed)),
            NameKey::Cancel => {
                self.typed.clear();
                Some(String::new())
            }
        }
    }
}

/// The name the prompt holds after `input` is typed into it character by character and
/// confirmed, or `None` when that name is empty. Use it for a name that arrives as text (a text
/// field, an imported file name): `"Ace 1!"` gives `"ACE1"`, and `"abcdefghij"` gives `"ABCDEFG"`.
pub fn validate_name(input: &str) -> Option<String> {
    let mut prompt = NamePrompt::new();
    for c in input.chars() {
        prompt.press(NameKey::Char(c));
    }
    Some(prompt.typed).filter(|name| !name.is_empty())
}

/// True when `name` is a name a saved record may hold: 1..7 characters, each A–Z or 0–9
/// (RULES A.7.1).
pub fn is_pilot_name(name: &str) -> bool {
    (1..=MAX_NAME).contains(&name.len())
        && name.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn type_keys(prompt: &mut NamePrompt, keys: &[NameKey]) -> Option<String> {
        let mut result = None;
        for key in keys {
            result = prompt.press(*key);
        }
        result
    }

    fn chars(text: &str) -> Vec<NameKey> {
        text.chars().map(NameKey::Char).collect()
    }

    #[test]
    fn letters_are_stored_in_capitals_and_digits_kept() {
        let mut prompt = NamePrompt::new();
        let mut keys = chars("ace9");
        keys.push(NameKey::Confirm);
        assert_eq!(type_keys(&mut prompt, &keys), Some("ACE9".to_string()));
    }

    #[test]
    fn at_most_seven_characters_and_further_ones_are_ignored() {
        let mut prompt = NamePrompt::new();
        type_keys(&mut prompt, &chars("ABCDEFGHIJ"));
        assert_eq!(prompt.typed(), "ABCDEFG");
        // Deleting makes room again.
        prompt.press(NameKey::Delete);
        prompt.press(NameKey::Char('z'));
        assert_eq!(prompt.press(NameKey::Confirm), Some("ABCDEFZ".to_string()));
    }

    #[test]
    fn every_other_key_is_ignored() {
        let mut prompt = NamePrompt::new();
        type_keys(&mut prompt, &chars(" -_.!?é ß\t\nÄ1"));
        assert_eq!(prompt.typed(), "1");
    }

    #[test]
    fn delete_removes_the_last_character_and_does_nothing_when_empty() {
        let mut prompt = NamePrompt::new();
        prompt.press(NameKey::Delete);
        assert_eq!(prompt.typed(), "");
        type_keys(&mut prompt, &chars("AB"));
        prompt.press(NameKey::Delete);
        assert_eq!(prompt.typed(), "A");
    }

    #[test]
    fn confirm_may_return_an_empty_name() {
        let mut prompt = NamePrompt::new();
        assert_eq!(prompt.press(NameKey::Confirm), Some(String::new()));
    }

    #[test]
    fn cancel_returns_an_empty_name_whatever_was_typed() {
        let mut prompt = NamePrompt::new();
        type_keys(&mut prompt, &chars("ACE"));
        assert_eq!(prompt.press(NameKey::Cancel), Some(String::new()));
        assert_eq!(prompt.typed(), "");
    }

    #[test]
    fn the_prompt_starts_empty_after_finishing() {
        let mut prompt = NamePrompt::new();
        type_keys(&mut prompt, &chars("ACE"));
        prompt.press(NameKey::Confirm);
        assert_eq!(prompt.typed(), "");
    }

    #[test]
    fn validate_name_applies_the_prompt_rules_to_text() {
        assert_eq!(validate_name("Ace 1!"), Some("ACE1".to_string()));
        assert_eq!(validate_name("abcdefghij"), Some("ABCDEFG".to_string()));
        assert_eq!(validate_name("drifter"), Some("DRIFTER".to_string()));
        assert_eq!(validate_name(""), None);
        assert_eq!(validate_name("  !?"), None);
    }

    #[test]
    fn record_names_are_one_to_seven_capitals_or_digits() {
        for good in ["A", "0", "DRIFTER", "ACE1", "1234567"] {
            assert!(is_pilot_name(good), "{good}");
        }
        for bad in ["", "ABCDEFGH", "ace", "AC E", "AC-E", "ÄCE"] {
            assert!(!is_pilot_name(bad), "{bad}");
        }
    }
}
