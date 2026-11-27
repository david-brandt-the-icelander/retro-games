# `.zazzle/zizd/`: retro-games' zizd pipelines

The steps zazzle's builders and deployers run for this repository, written against zazzle's step-pipeline spec
(`src/macos/zazzle-pipeline/pipeline-spec.md`, sections 1–4). There is **one named pipeline per game**, named after
the game's folder under `games/` (`david-brandt-the-icelander/retro-games:chess` is `games/chess`). Every pipeline
runs the same two step containers, so they live once, in `.zazzle/zizd/build/` and `.zazzle/zizd/deploy/`, and each
reads its game from the pipeline's name in `ZAZZLE_PIPELINE`. The pipeline files themselves go in the orchestrator
(`continuous_integration_and_delivery`, `.zazzle/zizd/pipelines/david-brandt-the-icelander/retro-games/GAME.json`);
the copies below are what goes there.

| Step | Phase | Image | What it does | Leaves in `/zazzle/output` |
|---|---|---|---|---|
| `build` | build | `node:22.23.2-bookworm-slim`, Godot 4.7.2 with its Web, Linux x86_64, Windows x86_64 and macOS export templates (SHA-512 checked) | copies the game, `vendor/` and `games/word-lists/` out of the read-only checkout, then `npm ci`, `npm test`, `npm run test:godot` when the game has it, `npm run build`, the check that `dist/` ships no `.dev` folder, and `wrangler deploy --dry-run --outdir` with the game's own locked wrangler: the game's `npm run deploy` short of the upload, as `.github/workflows/game.yml` ran it | `BUILD` (game, commit, versions), `wrangler.jsonc`, `bundle/index.js` (+ map), `dist.tar.gz` |
| `deploy` | deploy (`deploys: true`) | `node:22.23.2-bookworm-slim`, wrangler 4.167.0, gh 2.103.3 (SHA-256 checked) | from `/zazzle/input/artifacts/build/` only: the database migration gate, then `wrangler deploy bundle/index.js --no-bundle` with the game's `wrangler.jsonc` and `dist/`. Never rebuilds: no `npm ci`, no Godot. | nothing |

The Godot games (Gambit, Deep Claim, Double Cross, Hand of the Isle, Hedgerow, Inkwell Academy, Iron Haze, Neon
Cycles, Rampart, Neon Snake, Swarmhold, Thrustbound, Twelve Banners) are the ones whose `package.json` has
`test:godot`; the step finds that itself. Godot is in the one `build` image for every game, so a game that gains
Godot needs no pipeline change. The image takes Godot's arm64 or x86_64 Linux editor to match the builder, and the
two differ in one default: only the x86_64 editor imports S3TC/BPTC textures unless told otherwise. Every game sets
ETC2/ASTC itself and none sets S3TC/BPTC, so the step appends `import_s3tc_bptc=true` to its copy's
`project.godot` (never the repository's; `override.cfg` would not do, since the exporting editor ignores it) when
`project.godot` does not decide it: the build is then the one GitHub's x86_64 runners made, on either kind of builder. Without it, an arm64
builder leaves desktop texture formats out of the web builds and refuses the macOS export outright. Iron Haze and Twelve Banners stamp the commit on their landing page from
`GITHUB_SHA`, which the step sets to the commit being built.

wrangler: each game's bundle is made by the wrangler its own `package-lock.json` holds (4.158.0 to 4.167.0 today).
The deploy image only uploads, with 4.167.0, the newest any game holds; bump it there when a game's lock moves past
it.

## The deploy step

- **Refuses** without `CLOUDFLARE_API_TOKEN` or `GITHUB_TOKEN`, without the build's artifacts, with artifacts of
  another game or commit (`BUILD` against `ZAZZLE_PIPELINE` and `ZAZZLE_COMMIT`), or with a shallow checkout.
- **The database migration gate** (`docs/database-migrations.md`): nothing deploys while a change to this game's
  `worker/schema.sql` or `worker/migrations/` since its last deploy is unacknowledged in the pull request that
  brought it. It runs `.github/scripts/migration-gate.sh deploy BASE` from the checkout at the commit being deployed,
  with `MIGRATION_GATE_GAME` set to the game (each game has its own D1 database, so another game's migration does
  not hold this one back). `BASE`, "the last deploy", is the commit in the newest of the Worker's deployments whose
  version message is `zizd <commit>`, which this step writes with `wrangler deploy --message`; before the first such
  deploy, the commit that added `.zazzle/zizd/deploy/run.sh`. A deploy by hand with `npm run deploy` writes no such
  message, so the gate then looks further back, never less far. The old Deploy workflow's `migration_applied`
  override is gone: `MIGRATION_APPLIED` is unset, and every database change is acknowledged in its pull request,
  which `main` requires anyway. When the gate refuses: apply the migration, tick the box in the pull request, and run
  the deploy again. Production's database is still migrated only by hand.
- **Halting:** it checks `ZAZZLE_HALT_FILE` before the gate and before the upload, and exits **75** when asked to
  halt.
- **By hand only** (no pipeline names it): `DEPLOY_DRY_RUN=1` needs no Cloudflare credentials, takes the gate's
  `BASE` from `MIGRATION_GATE_BASE` (or the fallback above) instead of asking Cloudflare, and runs
  `wrangler deploy --dry-run` on the artifacts. The gate still runs, and needs `GITHUB_TOKEN` when it finds a
  database change.

## Config keys

Names only; the values are in the orchestrator's config files (later zeecrets), never here. The `build` step needs
no key: the repository is public and `vendor/icelander-auth` is committed.

| Key | Step | Where it goes |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | `deploy` | **`deploy_keys`** (`config/david-brandt-the-icelander/retro-games/GAME.json`, or `shared.json` if one token serves every game). It must deploy Workers, their routes on `icelander.net` and their Durable Object migrations, and read the Workers' deployments and versions (the gate's "last deploy") in account `ab026008f5aa2bef2dca4cfccd0f70ef`. |
| `GITHUB_TOKEN` | `deploy` | `keys` (the builder's own key in `shared.json`). The gate reads pull requests and the pull requests of commits in `david-brandt-the-icelander/retro-games` with it; read access is enough. |
| `CLOUDFLARE_ACCOUNT_ID?` | `deploy` | optional, `keys` or `deploy_keys`. Without it the step uses `ab026008f5aa2bef2dca4cfccd0f70ef`, the account `.github/workflows/game.yml` named. |

No `environments`: each game deploys from `main`. A release branch, when there is one, becomes an environment with
its `branch`.

## `paths`

Each pipeline starts on a commit that changes its game's folder, `vendor/` (the sign-in library every Worker
bundles), the two step folders, or the migration gate; Laumufarþegi also on `games/word-lists/`, whose topics it
bundles. `.dev/` folders are left out, as `.github/scripts/changed-games.sh` leaves them out: they document the code
and no build ships them.

## Trying it by hand

With the spec's "Trying a step by hand" recipe, `ZAZZLE_PIPELINE=david-brandt-the-icelander/retro-games:GAME`, and
the `build` step's output copied into the deploy step's `input/artifacts/build/`. Run the deploy step only without
credentials (it refuses) or with `-e DEPLOY_DRY_RUN=1`. On the owner's Mac, wrap each `docker build` and
`docker run` in `continuous_integration_and_delivery/bin/ci-run NAME --`.

## Not here

- `games/dawn-chorus/` has no pipeline here: Dawn Chorus is its own repository, with its own pipeline.
- `games/lodestar/` has none: it is a desktop game that nothing deploys, and `game.yml` never built it (`cargo test`
  in its folder).
- `games/word-lists/` is data, not a game.
- The `.dev` validators (`ci.yml`'s `diagrams` job), the per-pull-request game builds (`ci.yml`'s `game` job) and the
  "Database migration" pull request check (`migrations.yml`) are pull-request checks, which zizd defers.

## What goes at cutover

Not removed yet. When the pipelines are registered and have deployed each game once:

- `.github/workflows/game.yml`: replaced by the `build` step (and the `deploy` step for its never-used `deploy` input);
- `.github/workflows/ci.yml`: its `game` job is the `build` step; its `diagrams` job and `.github/scripts/changed-games.sh`
  stay until zizd runs pull-request checks;
- `.github/workflows/migrations.yml` stays (`main` requires its check) until zizd runs pull-request checks;
- the games' READMEs and the top-level `README.md` ("Deploying") then say that zizd deploys, not `npm run deploy`.

## The pipeline files

### `advent-calendar`

```json
{
  "id": "david-brandt-the-icelander/retro-games:advent-calendar",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/advent-calendar", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `chess`

```json
{
  "id": "david-brandt-the-icelander/retro-games:chess",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/chess", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `deep-claim`

```json
{
  "id": "david-brandt-the-icelander/retro-games:deep-claim",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/deep-claim", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `dictator`

```json
{
  "id": "david-brandt-the-icelander/retro-games:dictator",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/dictator", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `double-cross`

```json
{
  "id": "david-brandt-the-icelander/retro-games:double-cross",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/double-cross", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `dulmal`

```json
{
  "id": "david-brandt-the-icelander/retro-games:dulmal",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/dulmal", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `hand-of-the-isle`

```json
{
  "id": "david-brandt-the-icelander/retro-games:hand-of-the-isle",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/hand-of-the-isle", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `hedgerow`

```json
{
  "id": "david-brandt-the-icelander/retro-games:hedgerow",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/hedgerow", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `hivestorm`

```json
{
  "id": "david-brandt-the-icelander/retro-games:hivestorm",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/hivestorm", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `inkwell-academy`

```json
{
  "id": "david-brandt-the-icelander/retro-games:inkwell-academy",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/inkwell-academy", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `iron-haze`

```json
{
  "id": "david-brandt-the-icelander/retro-games:iron-haze",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/iron-haze", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `kvardinn`

```json
{
  "id": "david-brandt-the-icelander/retro-games:kvardinn",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/kvardinn", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `laumufarthegi`

```json
{
  "id": "david-brandt-the-icelander/retro-games:laumufarthegi",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/laumufarthegi", "vendor", "games/word-lists", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `lundey`

```json
{
  "id": "david-brandt-the-icelander/retro-games:lundey",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/lundey", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `meg`

```json
{
  "id": "david-brandt-the-icelander/retro-games:meg",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/meg", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `neon-cycles`

```json
{
  "id": "david-brandt-the-icelander/retro-games:neon-cycles",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/neon-cycles", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `pinochle`

```json
{
  "id": "david-brandt-the-icelander/retro-games:pinochle",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/pinochle", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `rally`

```json
{
  "id": "david-brandt-the-icelander/retro-games:rally",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/rally", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `rampart`

```json
{
  "id": "david-brandt-the-icelander/retro-games:rampart",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/rampart", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `shatterbelt`

```json
{
  "id": "david-brandt-the-icelander/retro-games:shatterbelt",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/shatterbelt", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `snake`

```json
{
  "id": "david-brandt-the-icelander/retro-games:snake",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/snake", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `swarmhold`

```json
{
  "id": "david-brandt-the-icelander/retro-games:swarmhold",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/swarmhold", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `thrustbound`

```json
{
  "id": "david-brandt-the-icelander/retro-games:thrustbound",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/thrustbound", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```

### `twelve-banners`

```json
{
  "id": "david-brandt-the-icelander/retro-games:twelve-banners",
  "repos": ["https://github.com/david-brandt-the-icelander/retro-games.git"],
  "paths": ["games/twelve-banners", "vendor", ".zazzle/zizd/build", ".zazzle/zizd/deploy", ".github/scripts/migration-gate.sh", "!**/.dev/**"],
  "steps": [
    {"name": "build", "path": ".zazzle/zizd/build"},
    {"name": "deploy", "path": ".zazzle/zizd/deploy", "config": ["CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "CLOUDFLARE_ACCOUNT_ID?"], "deploys": true}
  ],
  "supersede": true,
  "halt": { "deployment": "should" }
}
```
