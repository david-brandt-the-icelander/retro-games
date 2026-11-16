// Starts the Godot engine with the export's configuration, which the page holds as JSON (a separate
// file rather than Godot's inline script, so the page's Content-Security-Policy can forbid inline script).
/* global Engine */
(() => {
  const status = document.getElementById("status");
  const fill = document.getElementById("bar-fill");
  const notice = document.getElementById("notice");
  const fail = (err) => {
    notice.textContent = err instanceof Error ? err.message : String(err);
    status.classList.add("failed");
  };
  try {
    const config = JSON.parse(document.getElementById("godot-config").textContent);
    const missing = Engine.getMissingFeatures({ threads: false });
    if (missing.length) {
      fail(`This browser can't run the game: it lacks ${missing.join(", ")}.`);
      return;
    }
    new Engine(config).startGame({
      onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; },
    }).then(() => {
      status.classList.add("done");
      setTimeout(() => status.remove(), 600);
    }, fail);
  } catch (err) {
    fail(err);
  }
})();
