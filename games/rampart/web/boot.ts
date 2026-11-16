// Starts the Godot engine from the shell page (godot/web_shell/shell.html), with a progress bar and a
// notice if the browser can't run it. The page allows no inline script, so this lives in its own file.
declare const Engine: {
  new (config: unknown): { startGame(o: { onProgress(current: number, total: number): void }): Promise<void> };
  getMissingFeatures?(o?: unknown): string[];
};

const statusEl = document.getElementById("status")!;
const fill = document.getElementById("bar-fill")!;
const notice = document.getElementById("notice")!;

function fail(message: string): void {
  statusEl.classList.add("failed");
  notice.textContent = message;
}

const missing = typeof Engine.getMissingFeatures === "function" ? Engine.getMissingFeatures({ threads: false }) : [];
if (missing.length) {
  fail(`This browser can't run Rampart: it lacks ${missing.join(", ")}. A recent Chrome, Edge, Firefox or Safari will.`);
} else {
  const config = JSON.parse(document.getElementById("godot-config")!.textContent!);
  new Engine(config)
    .startGame({ onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; } })
    .then(() => {
      statusEl.classList.add("done");
      document.getElementById("canvas")!.focus();
    })
    .catch((e: unknown) => fail(`Rampart couldn't start: ${e instanceof Error ? e.message : String(e)}`));
}

export {};
