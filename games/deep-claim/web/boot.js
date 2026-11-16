// Starts the Godot engine behind a loading screen (godot/web_shell/shell.html). A file of its own,
// not an inline script, so the page's Content-Security-Policy (web/_headers) can forbid inline scripts.
(function () {
  const status = document.getElementById("status");
  const fill = document.getElementById("bar-fill");
  const notice = document.getElementById("notice");
  const fail = (err) => {
    notice.textContent = "This browser can't run the game: " + (err instanceof Error ? err.message : String(err));
    status.classList.add("failed");
  };
  try {
    const config = JSON.parse(document.getElementById("godot-config").textContent);
    const engine = new Engine(config);
    engine.startGame({
      onProgress: (current, total) => { if (total > 0) fill.style.width = Math.round((current / total) * 100) + "%"; },
    }).then(() => {
      status.classList.add("done");
      setTimeout(() => status.remove(), 600);
    }, fail);
  } catch (err) {
    fail(err);
  }
})();
