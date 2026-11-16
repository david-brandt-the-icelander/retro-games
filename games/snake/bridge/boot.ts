// The page around the game (godot/web_shell/shell.html): starts Godot's engine with the export's own
// settings, fills the loading bar, and says plainly when the browser can't run the game.
// It is a file of its own because the page's Content-Security-Policy allows no inline script.
declare const Engine: (new (config: unknown) => { startGame(o: { onProgress(current: number, total: number): void }): Promise<void> }) & {
  getMissingFeatures?(o?: { threads?: boolean }): string[];
};

const loading = document.getElementById("status")!;
const fill = document.getElementById("bar-fill")!;
const notice = document.getElementById("notice")!;

function fail(message: string): void {
  notice.textContent = message;
  loading.classList.add("failed");
}

const missing = Engine.getMissingFeatures?.({ threads: false }) ?? [];
if (missing.length) {
  fail(`This browser can't run the game (it lacks ${missing.join(", ")}). Try a recent Chrome, Firefox, Edge or Safari.`);
} else {
  const config = JSON.parse(document.getElementById("godot-config")!.textContent!);
  new Engine(config).startGame({
    onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; },
  }).then(() => {
    loading.classList.add("done");
    setTimeout(() => loading.remove(), 600);
  }, (err: unknown) => {
    console.error(err);
    fail("The game didn't load. Reload the page to try again.");
  });
}

export {};
