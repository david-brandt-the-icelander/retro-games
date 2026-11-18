// Starts the Godot engine with the export's config and drives the loading screen (no inline script: the page's CSP forbids it).
(() => {
  const config = JSON.parse(document.getElementById("godot-config").textContent);
  const status = document.getElementById("status");
  const fill = document.getElementById("bar-fill");
  const notice = document.getElementById("notice");
  const engine = new Engine(config);
  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length) {
    status.classList.add("failed");
    notice.textContent = "This browser can't run the game: " + missing.join(", ") + ".";
    return;
  }
  engine.startGame({
    onProgress: (current, total) => { if (total > 0) fill.style.width = `${(100 * current) / total}%`; },
  }).then(() => {
    status.classList.add("done");
    document.getElementById("canvas").focus();
  }, (err) => {
    status.classList.add("failed");
    notice.textContent = String(err && err.message ? err.message : err);
  });
})();
