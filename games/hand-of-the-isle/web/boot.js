// Starts the Godot engine on the play page (godot/web_shell/shell.html): a script file of its own, because the
// page's Content-Security-Policy allows no inline script.
(() => {
  const status = document.getElementById("status");
  const fill = document.getElementById("bar-fill");
  const notice = document.getElementById("notice");
  const fail = (text) => {
    status.classList.add("failed");
    notice.textContent = text;
  };
  const config = JSON.parse(document.getElementById("godot-config").textContent);
  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length) {
    fail("This browser can't run Hand of the Isle (it lacks " + missing.join(", ") + "). Try a current Chrome, Edge, Firefox or Safari.");
    return;
  }
  const engine = new Engine(config);
  engine
    .startGame({
      onProgress: (current, total) => {
        if (total > 0) fill.style.width = Math.round((100 * current) / total) + "%";
      },
    })
    .then(
      () => status.classList.add("done"),
      (err) => fail("Hand of the Isle couldn't start: " + (err && err.message ? err.message : String(err))),
    );
})();
