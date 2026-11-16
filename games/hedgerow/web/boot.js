// Starts the Godot engine (web/shell.html) behind a loading screen.
/* global Engine */
(() => {
  const status = document.getElementById("status");
  const fill = document.getElementById("bar-fill");
  const notice = document.getElementById("notice");
  const fail = (msg) => { notice.textContent = msg; status.classList.add("failed"); };
  try {
    const config = JSON.parse(document.getElementById("godot-config").textContent);
    new Engine(config).startGame({
      onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; },
    }).then(() => { status.classList.add("done"); setTimeout(() => status.remove(), 600); },
      (err) => fail(err instanceof Error ? err.message : String(err)));
  } catch (err) {
    fail(`This browser can't run the game: ${err instanceof Error ? err.message : String(err)}`);
  }
})();
