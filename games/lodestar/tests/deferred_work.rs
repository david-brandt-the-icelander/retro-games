//! The deferred-work gate of knowledge-driven development: no comment in a tracked source file
//! opens with one of the four deferred-work words, and there is no deferred-work folder. Write a
//! ⚠️ or ❌ in the document that owns the behaviour instead.
//! https://github.com/david-brandt-the-icelander/knowledge-driven-development/blob/main/06-enforcement.md

use std::fs;
use std::path::{Path, PathBuf};

/// The four words, assembled so this file does not trip its own gate.
fn words() -> [String; 4] {
    [["TO", "DO"].concat(), ["FIX", "ME"].concat(), ["HA", "CK"].concat(), ["X", "XX"].concat()]
}

const SKIP_DIRS: &[&str] = &["target", ".godot", ".git", "build"];

fn walk(dir: &Path, files: &mut Vec<PathBuf>, folders: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();
        if path.is_dir() {
            if SKIP_DIRS.contains(&name.as_str()) {
                continue;
            }
            folders.push(path.clone());
            walk(&path, files, folders);
        } else {
            files.push(path);
        }
    }
}

/// The comment openers for each kind of source file.
fn openers(path: &Path) -> &'static [&'static str] {
    match path.extension().and_then(|e| e.to_str()) {
        Some("rs") => &["//", "/*"],
        Some("gd" | "toml" | "cfg" | "gdextension" | "py" | "sh") => &["#"],
        Some("tscn" | "tres" | "godot") => &[";"],
        Some("gdshader") => &["//", "/*"],
        _ => &[],
    }
}

fn marker_in(line: &str, openers: &[&str], words: &[String]) -> bool {
    openers.iter().any(|opener| {
        line.match_indices(opener).any(|(at, _)| {
            let rest = line[at + opener.len()..].trim_start_matches(['/', '*', '!', '#', ' ', '\t']);
            words.iter().any(|w| {
                rest.starts_with(w.as_str())
                    && !rest[w.len()..].chars().next().is_some_and(|c| c.is_alphanumeric() || c == '_')
            })
        })
    })
}

#[test]
fn no_deferred_work_markers_or_folders() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let (mut files, mut folders) = (Vec::new(), Vec::new());
    walk(root, &mut files, &mut folders);
    let words = words();
    let mut found = Vec::new();
    for folder in &folders {
        let name = folder.file_name().unwrap().to_string_lossy();
        if words[0].eq_ignore_ascii_case(&name) {
            found.push(format!("{}: a deferred-work folder", folder.display()));
        }
    }
    for file in &files {
        let openers = openers(file);
        if openers.is_empty() {
            continue;
        }
        let Ok(text) = fs::read_to_string(file) else { continue };
        for (number, line) in text.lines().enumerate() {
            if marker_in(line, openers, &words) {
                found.push(format!("{}:{}: {}", file.display(), number + 1, line.trim()));
            }
        }
    }
    assert!(found.is_empty(), "deferred-work markers (write a ⚠️ or ❌ in the owning document):\n{}", found.join("\n"));
}

#[test]
fn the_gate_catches_a_planted_marker() {
    let words = words();
    let planted = format!("let x = 1; // {}: tidy up", words[0]);
    assert!(marker_in(&planted, &["//", "/*"], &words));
    assert!(!marker_in("// This mentions things to do later.", &["//"], &words));
    assert!(!marker_in(&format!("let s = \"{}\";", words[1]), &["//"], &words));
}
