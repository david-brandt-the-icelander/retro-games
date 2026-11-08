//! Dependencies point inward only (docs/DESIGN.md § Project layout): capabilities may not use
//! features or use cases, and features may not use use cases. The crate boundaries enforce the
//! outer layers; this test enforces the ones inside lodestar-core.

use std::fs;
use std::path::{Path, PathBuf};

fn rust_files(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            rust_files(&path, out);
        } else if path.extension().is_some_and(|e| e == "rs") {
            out.push(path);
        }
    }
}

fn violations(layer: &str, forbidden: &[&str]) -> Vec<String> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("src").join(layer);
    let mut files = Vec::new();
    rust_files(&root, &mut files);
    let mut found = Vec::new();
    for file in files {
        let text = fs::read_to_string(&file).expect("readable source");
        for (number, line) in text.lines().enumerate() {
            let code = line.split("//").next().unwrap_or("");
            for outer in forbidden {
                let paths = [format!("crate::{outer}"), format!("super::super::{outer}")];
                if paths.iter().any(|p| code.contains(p.as_str())) {
                    found.push(format!("{}:{}: {layer} uses {outer}", file.display(), number + 1));
                }
            }
        }
    }
    found
}

#[test]
fn capabilities_depend_on_nothing_further_out() {
    let found = violations("capabilities", &["features", "use_cases"]);
    assert!(found.is_empty(), "{}", found.join("\n"));
}

#[test]
fn features_do_not_depend_on_use_cases() {
    let found = violations("features", &["use_cases"]);
    assert!(found.is_empty(), "{}", found.join("\n"));
}
