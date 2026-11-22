export {};

// The page around the Godot game (godot/web_shell/shell.html): starts the engine behind a loading
// screen. Everything else (the match in ?match=, going to the multiplayer page) the game does itself.
declare const Engine: new (config: unknown) => { startGame(o: { onProgress(c: number, t: number): void }): Promise<void> };

const status = document.getElementById("status")!;
const fill = document.getElementById("bar-fill")!;
const notice = document.getElementById("notice")!;
try {
  const config = JSON.parse(document.getElementById("godot-config")!.textContent!);
  const engine = new Engine(config);
  engine.startGame({
    onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; },
  }).then(() => { status.classList.add("done"); setTimeout(() => status.remove(), 600); }, (err: unknown) => {
    notice.textContent = err instanceof Error ? err.message : String(err);
    status.classList.add("failed");
  });
} catch (err) {
  notice.textContent = `This browser can't run the game: ${err instanceof Error ? err.message : String(err)}`;
  status.classList.add("failed");
}
