# Warcraft Survivors

Survivors-style Warcraft III Reforged map. The whole game is one Lua file,
`src/ashenvale_survivor.lua`, pasted into the map's Custom Script Code
(Trigger Editor > map name at the top of the tree). The map is `map/WarcraftSurvivor.w3m`.

## Rules for the Lua source

- **No `%` character anywhere in `src/ashenvale_survivor.lua`**, not even in comments.
  The World Editor passes custom script through printf: `% e`, `% d` turn into
  garbage and `% s` crashes the editor on save. Use `\037` inside strings
  (it is `%` at runtime, so it also works in Lua patterns and `string.format`),
  and use `math.fmod(a, b)` instead of `a % b`.
  Check with: `Select-String -Path src\ashenvale_survivor.lua -Pattern '%'` (it should find nothing).
- The map must be set to Lua: Scenario > Map Options > Script Language. If the
  editor's temp folder (`map/*.w3mTemp`) contains `war3map.j`, the map is still on JASS.

## Testing

`python tools/smoketest/run.py` runs the script against mocked natives (needs `pip install lupa`).
The Armory step (`no button under: Upgrade`, or `upgrade costs gold` with "spent 0 gold") fails now and
then because gear drops are random: the armory keeps the item it selected on its first visit (before
any loot, so the first item), and Upgrade only works if the test run dropped that item. Run it again
before deciding that a change broke it.

## Standalone engine (engine/)

`engine/` is a fork of [corepunch/open-realm](https://github.com/corepunch/open-realm)
(C reimplementation of Warcraft III), on branch `survivor`. The goal is a standalone
survivor game (exe + web) built on it, using the Legacy 1.29 TFT data.

- Build: MSYS2 UCRT64 at `C:\msys64` (gcc, make, SDL2, zlib, libepoxy, diffutils).
  `powershell -ExecutionPolicy Bypass -File tools\build-windows.ps1 -Jobs 8` from `engine/`.
- Game data: `C:\Program Files (x86)\Warcraft III (Legacy)` (1.29.2, MPQ, no War3Patch.mpq).
- Run: `dist\windows\openwarcraft3.exe -data "C:\Program Files (x86)\Warcraft III (Legacy)" -tft +map "Maps/FrozenThrone/(2)EchoIsles.w3x"`.
  **`-tft` is required**: without it the engine hides `War3x*.mpq` and every TFT asset is "not found".
- Screenshots: add `+screenshot <frames>`; the engine writes `dist\windows\screenshots\shotNNNN.jpg`.
  Never capture the desktop: it shows the user's own windows.
- The engine's own agent rules are in `engine/AGENTS.md` (Quake 2 style, game logic stays in
  `games/warcraft-3/game/`, abilities in `skills/s_*.c`).
- Play: `engine\dist\windows\play_survivor.bat` (borderless window over the desktop,
  `vid_fullscreen 2`, so Alt+Tab does not minimize or switch modes; the menu loads behind a black
  screen, entering a zone shows that zone's loading screen). It writes the engine's output to
  `dist\windows\last_run.log` (one session; read it after a crash the user reports).
- Open (2026-10-30): the user reports Plaguelands crashing after a few minutes (local and web). Not
  reproduced: an 11:40 run (healed idle Blademaster, all bosses and Sapphiron, 139 enemies) and 200 s with
  ~150 Plaguelands casters both ran clean. Then the user's cases: Lich froze at 2:50 and Dreadlord (Inferno,
  Carrion Swarm, Vampiric Aura) at 0:32, both in the browser (full page freeze, Opera GX). Reproduced in neither
  native runs (walking Lich 5:30, Dreadlord with Inferno; memory flat ~630-670 MB) nor headless Chrome with the
  add-on embedded (`--out build/web/survivor-test`, Lich 7:40, Dreadlord 3:35 with audio unlocked; wasm 442-531 MB).
  Suspect: Opera GX's GX Control RAM/CPU limiter. Every zone track exists (some only in `War3Local.mpq`).
  2026-10-31: more reports (Reddit: black world after 5+ min "still getting gold but no xp", kicked to the menu;
  GitHub: page freeze during Stitches 4-5 times out of 5; the user: black world at 7:19 in Opera GX after many
  Alt+Tabs, HUD and timer still drawn, and GX Control's Hot Tabs Killer listing the game tab at 67 CPU). Ruled out:
  map-change leaks (10 native menu<->Plaguelands cycles flat at 630-700 MB; 6 web cycles flat at 442 MB wasm,
  `test_zone_cycle.lua`), a killed Stitches natively not reproduced (heroes did not kill it, `uabo=1` stayed), and
  Chrome visibility (30 minimize / tab switch / page freeze / resize disturbances on the real GPU over 9 min, world
  back every time; harness `cdp_alttab.py` in the 2026-10-31 scratchpad). The client drops to the menu after 10 s
  without a server packet (`CL_TIMEOUT_MSEC`). The script prints `SURVIVOR hero position invalid` once if the
  hero's position turns non-finite (diagnostic only). Next report: ask for the F12 console log.
  Same day, a Reddit tester (Edge): black world with the default Warcraft III UI showing. The hero's native chase of
  ranged attackers (Plaguelands casters too) was fixed the same day (see Engine problems); whether it caused these
  reports is unproven: ask testers again after 1.2.0.
- **Release procedure (the user's rule, 2026-11-01: every time).** After raising `version`/`notes` in
  `src/engine_boot.lua`, run `powershell -ExecutionPolicy Bypass -File tools\release\make_upload.ps1`
  (`-SkipNative`/`-SkipWeb`/`-SkipPortable` for steps already done). It builds the native and browser engines, the
  trimmed data and the portable build, stages the site, then:
  - **`release\` = exactly the site's web root** (page, `.htaccess`, `data\`, `download\` with the zip and
    `portable\`), mirrored with robocopy `/MIR` (anything else in it is deleted). The user opens it in WinSCP and
    copies everything. Nothing else may be written into `release\`.
  - **`engine\build\web\survivor-upload\download\Warcraft Survivors\WarcraftSurvivors.exe`**: the same portable
    build, playable, for the user to test locally before uploading (placed after the mirror, never uploaded).
  - Build outputs live in `engine\build\portable\` (portable folder + one `.previous-*`, `WarcraftSurvivors.zip`,
    `update\portable\`, the tester SFX). The paths below that say `release\` now mean that folder.
- Tester build: `powershell -ExecutionPolicy Bypass -File tools\release\make_release.ps1` writes
  `release\WarcraftSurvivors.exe` (7-Zip SFX, ~4 MB: engine + `src/` scripts + `Play Warcraft Survivors.bat`,
  which finds or asks for the tester's own 1.29 install and keeps it in `wc3path.txt`). No Blizzard data inside.
- Portable build (since 2026-10-31): `powershell -ExecutionPolicy Bypass -File tools\release\make_portable.ps1`
  writes `release\Warcraft Survivors Portable\` (launcher exe, `OpenRealm\` engine + scripts, `Data\`). `Data\` holds
  only the web build's trimmed archives and the 12 arena maps (`make_survivor_data.py` run into a temporary folder,
  ~200 MB instead of the whole 1.5 GB install); the engine mounts them natively the same way. An existing portable
  folder is moved to `.previous-<stamp>` first. Releases are built with `-Name 'Warcraft Survivors'`
  (`release\Warcraft Survivors\`, the source of `release\update\portable\` and the zip). Since 2026-10-31 the user
  plays and tests with a copy downloaded from the site's zip, which updates itself like a friend's: it lives outside
  the repository (never touch or rebuild it); a change reaches it by publishing a release. Neither
  holds a save: progress is `%APPDATA%\...\profile.pld` per PC, so a friend starts blank (Ashenvale only); the user's
  portable shows every zone because it shares the dev profile. Run with `APPDATA=<empty dir>` to see a blank start.
  The script also writes `release\WarcraftSurvivors.zip` (from the folder just built), which the browser
  lobby's **Download for Windows** button (top right, `Engine.web()` only) fetches from
  `SURVIVOR_ENGINE.download` (`/download/WarcraftSurvivors.zip`); stage it with
  `stage_survivor_upload.py ... --download ../release/WarcraftSurvivors.zip`. The button calls `EngineOpenURL(url)`
  (engine-only native, `MenuAction("openurl")` -> `CL_OpenURL` in `cl_main.c`: a temporary `<a download>` on the page,
  `SDL_OpenURL` natively).
- **Portable self-update (since 2026-10-31):** `SURVIVOR_ENGINE.version`/`notes`/`update` in `src/engine_boot.lua`
  (**raise `version` and rewrite `notes` for every release**; the lobby shows `v<version>` bottom right).
  `make_portable.ps1` runs `tools/release/portable_manifest.py write` (the folder's `version.json`: version, notes,
  update URL from the build's own `engine_boot.lua`, every file with size + sha1) and `stage` into
  `release\update\portable\` (`version.json` + `files\<path>`; unchanged files keep their timestamp, so a WinSCP
  synchronize uploads only what changed). `stage_survivor_upload.py ... --portable-update ../release/update/portable`
  puts it at `download/portable/` (= `SURVIVOR_ENGINE.update`); `survivor.htaccess` serves `version.json` no-cache.
  The launcher (`warcraft_survivors_launcher.cs`, compiled with `System.Web.Extensions.dll` for JSON) starts the
  engine with `+set survivor_updater <token>`, fetches the served `version.json` in the background and, when newer,
  writes `info.pld` to `%APPDATA%\warcraft-3\CustomMapData\WarcraftSurvivors\Update\` (preload files are the only
  files the script can read: `Preloader` runs their Lua block). The lobby (`Updater` in the script, menu map only)
  shows the window: notes, size, **Download & restart** / **Later** (Escape; leaves an "Update available" button,
  kept across map changes by the `survivor_update_later` cvar). Download writes `request.pld`; the launcher fetches
  only files whose sha1 differs into `.update\`, verifies each, reports `progress.pld` (bar, MB/s, time left; or an
  error with Retry), then the game quits (`EngineQuit`), the launcher moves old files to `.update-backup\` (rolled
  back on failure), drops files gone from the release, writes the new `version.json` and starts the new launcher
  (which deletes the backup holding the old exe). Saves are never touched. Test args: `--update-url <folder URL>`,
  and everything after `--` goes to the engine; `+set survivor_update_auto 1` presses Download. Tested end to end on
  copies in the scratchpad with a throttled local server (offer, Later, progress, restart into the new version with
  the launcher replaced, a file removed, a 404 -> Retry). Builds without `version.json` (every portable zip before
  this) cannot update: players download once by hand. First live update 1.0.0 -> 1.1.0 (boss telegraphs) worked on
  2026-10-31 (8 files, 8.9 MB). After an upload, check every changed file's sha1 on the live site against
  `version.json` before players see it: the first upload of 1.1.0 left the 8 changed files out (old copies served).
- Quick rebuild without the broken packaging step: from MSYS2 UCRT64 in `engine/`,
  `make -j8 OS=Windows_NT BIN_DIR=build-windows/bin LIB_DIR=build-windows/lib openwarcraft3`, then copy
  `build-windows\bin\openwarcraft3.exe` and `build-windows\lib\*.dll` into `dist\windows\`.
  From the Bash tool: `C:/msys64/usr/bin/env.exe MSYSTEM=UCRT64 OS=Windows_NT CHERE_INVOKING=1 /usr/bin/bash -lc 'make ...'`.
  Without `OS=Windows_NT` the libraries link as programs (`undefined reference to WinMain`).
  After editing `src/*.lua`, copy them to `dist\windows\share\warcraft-3\Scripts\Survivor\`.
- MPQ files: `build-windows\bin\mpqtool.exe -data <Legacy dir> cat <path>` (put `build-windows\lib`
  on PATH first). The full file list is `engine\tools\WarcraftIIIFileListZezulaLadik.txt`.
- Scripted input for tests: `+exec test_play.cfg` (in `share\warcraft-3\`) sends `oskey <key> <down>`
  commands after `wait` frames, like a player pressing Space, 1-4, WASD. A file with more than a
  few KB of `wait`s overflows the command buffer: chain files with `exec next.cfg` (see
  `flow_test*.cfg`: menu, forced camera scroll, Space into Ashenvale, cards, HUD, with screenshots).
- `python tools/engine_flow.py <name> w300 s k27 d100 w60 u100 ...` writes a chained `<name>.cfg`
  (w = wait frames, s = screenshot, k = tap key, d/u = key down/up, engine key codes); run it with
  `+exec <name>.cfg`. **Always add `+set vid_hidden 1`** to test runs (the window otherwise takes
  focus and receives whatever the user is typing), **`+set s_volume 0`** (a hidden window still plays
  its sound on the user's speakers), and `+set com_maxfps_background 0` so waits keep their pace. A hidden window renders at 1280x720.
- Test scripts in `Scripts\Survivor\` (each replaces the map's main; run alone as `wc3_lua_script`):
  `test_models.lua` (every hero preview model in one grid), `test_zone_shot.lua` (arena shot for a
  zone thumbnail), `test_weapon.lua` (prints the weapon fields of a few heroes), `test_trees.lua`
  (probes trees with an item: every tree must move it). Their source is `tools/engine_tests/`
  (versioned); copy them to `dist` like the `src/` scripts.

## Co-op (planned, not started)

`docs/coop-plan.md`: online co-op through a WebSocket relay on the WoW VPS (no LAN, no EOS: EOS has no browser
SDK), host-authoritative, agreed balance, resource estimates. The user is still deciding; do not start without them.

## Web version (since 2026-10-30)

- Emscripten SDK 4.0.21 in `C:\emsdk`. Build from `engine/` in Git Bash: `bash port/web/build-survivor.sh`
  (= `port/web/build-engine.py --survivor ../src`, about 5 minutes) writes `engine/build/web/survivor/`
  (`index.html/js/wasm` + page scripts; `src/*.lua` and `src/art/*.tga` are embedded at `/share/warcraft-3/Scripts/Survivor`).
  After editing `src/*.lua`, rebuild (the scripts are inside `index.wasm`); page JS can just be copied.
- Game data (self-hosted, the user's choice): `python port/web/make_survivor_data.py "<Legacy dir>" build/web/survivor`
  writes trimmed copies of War3/War3Local/War3x/War3xLocal.mpq, hard-links the arena maps from `engine_boot.lua`
  into `data/` and writes `data/files.json` (`id` + a `sha1` per file). `survivor.js` downloads it into the
  browser's OPFS on the first visit (199 MB since 2026-10-30; was 667 MB, then 1.16 GB; via `install-worker.js`
  `download`); when the id changes, files whose name, size and sha1 match the installed copy are copied from it
  locally and only the others are downloaded (tested in headless Chrome). Without `files.json` the page falls
  back to the upstream import panel. `data/` is Blizzard data: never in GitHub.
  **Trim** (`trim_archives`): keeps only the files in `tools/web_trace_reads.txt` (archive + name; `*` = highest
  archive that has it) plus `(listfile)`/`(attributes)`/`(signature)`. Hash and block tables are copied as they
  are, dropped entries marked deleted, kept payloads byte for byte (FIX_KEY files re-encrypted for their new offset).
  The tileset archives (`A.mpq`...) are read whole, so they stay whole. `--full` links the archives whole.
  **The reads list comes from `tools/web_trace.py`** (see its docstring): the engine logs every archive read and
  miss when `OPENREALM_FSTRACE=<file>` is set (`FS_TraceRead` in `common/common.c`); the tool runs every zone
  (roster, bosses, all 24 heroes, every spell), zone entry from the menu (loading screen), lobby tab, options
  page, every icon the script can show (generated `test_icons.lua`) and a defeat, hidden and muted, ~9 min,
  backing up and restoring the profile and config. Then `reads <full> <trimmed>` merges a trace on the install
  with one on the trimmed data (`run --data engine/build/web/survivor/data`; `compare` lists what the trim lost),
  adds numbered sound variants, every zone playlist and every asset path written in the script. Music is 89 MB.
  `run --only icons enter01 ...` reruns single sessions; `reads` takes any number of trace dirs. **Rerun it after adding
  heroes, spells, enemies, zones or UI art**, or the browser build misses those files (invisible model, silence).
  **Small updates (since 2026-10-30):** the four archives are trimmed to the frozen `tools/web_base_reads.txt` (the
  list first published), so they stay byte for byte the same; files the reads list gains go into
  `War3zUpdate<n>.mpq` (n = source archive index; the engine mounts every `.mpq` by name, later wins). Players
  then download only those (tested: 3 added files = 1.5 MB, the 199 MB copied locally). A name added to a lower
  archive that a higher base archive also has is repeated in the higher update archive, so priority holds.
  Never edit `web_base_reads.txt` casually: copying the reads list over it folds the updates in and makes every
  player download the 199 MB again (worth it only once the update archives get big).
  Rerun `stage_survivor_upload.py` afterwards: the upload folder shares `files.json` with the build through a hard link.
- Script-only changes re-download just `index.wasm` (8.5 MB, 4.8 MB gzipped: `survivor.htaccess` enables
  `mod_deflate` for wasm/js/html/json; check `curl -sI -H "Accept-Encoding: gzip" .../index.wasm` shows
  `Content-Encoding: gzip` after uploading the new `.htaccess`).
- Upload: `python port/web/stage_survivor_upload.py build/web/survivor build/web/survivor-upload` writes
  only the served files + `.htaccess` (`port/web/site/survivor.htaccess`: isolation headers, wasm type,
  HTTPS redirect) + `data/`. The user uploads its contents with WinSCP to OVH shared hosting, multisite
  folder `warcraftsurvivor` = `https://warcraftsurvivor.para-bellum.eu`.
- After an upload, the page, `.js` and `index.wasm` must reach the player together: OVH served them with
  `max-age=900`, and a cached old `index.js` with a new `index.wasm` is a black screen. `survivor.htaccess`
  now sets `no-cache` on html/js/wasm (revalidation, 304 when unchanged); re-upload `.htaccess` with it.
- Hosting: HTTPS (or localhost), every file served with `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`, `.wasm` as `application/wasm`, `data/` on the same origin.
  Local test: `python port/web/serve.py --directory build/web/survivor --port 8765`.
- Saves: the survivor build sets `BZ_WEB_HOME` (`/opfs/openrealm/user`), so the profile survives reloads
  (upstream keeps the user directory in memory).
- Headless test (own Chrome profile, never the desktop): the scratch `cdp_run.py` pattern, Chrome
  `--headless=new --use-angle=swiftshader --enable-unsafe-swiftshader` + CDP screenshots and key events.
  The engine's printf goes to its worker's console: CDP `Target.setAutoAttach` (flatten) + `Runtime.enable`
  per worker session. `build-engine.py --define DEBUG_MAP_LOAD --out build/web/survivor-timing` logs
  `MAP_LOAD` phase timings.
- **Fixed 2026-10-30, web load time:** every OPFS read through WasmFS costs ~2 ms whatever its size, and
  `mpq.c` read files one 4 KB sector at a time (about 10,000 reads per map): the menu map took 61 s,
  each zone ~30 s. Browser builds now read archives in 256 KB chunks with a 16 MB cache per archive
  (`MpqReadChunk` in `common/mpq.c`, `__EMSCRIPTEN__` only): menu 3.2 s, zone 2.9 s (server side).
- Saves are local to the browser (OPFS), not online: another browser or device starts fresh.
- **Fixed 2026-10-30, web sound:** no music (the engine module was built without `-DBZ_MUSIC_MP3`, now in
  `build-engine.py`), and crackling: the audio producer thread (`S_WebAudioProduce` in `sound/s_sound.c`)
  slept 2 ms after each 512-frame chunk, a 15.6 ms timer tick on Windows, so a quarter of the worklet's
  blocks played silence. It now fills to its target and sleeps only when full. To measure: count
  `available < needed` blocks in the built `audio-worklet.js` and post them through `node.port`
  (headless Chrome runs the context at 48 kHz with a key press to unlock it).
- Web fullscreen belongs to the page's button: `R_VideoFullscreen`/`R_VideoBorderless` are false under
  `__EMSCRIPTEN__` (config.cfg's `vid_fullscreen 1` made SDL fullscreen the page on the first click).
  `survivor.js` sets `survivor_web 1`; the script's `Engine.web()` hides Quit Game (a page cannot close).
- Saves (`openrealm/user` in OPFS) survive new uploads: the installer only deletes inside
  `openrealm/game-data/wc3`. They are lost if the player clears site data or the origin changes.
- Emscripten's port downloads (SDL2, zlib) fail with Python's SSL store on this machine;
  `build-survivor.sh` sets `SSL_CERT_FILE` from `certifi`.

## GitHub (open source, since 2026-10-30)

- This copy is nfastje's fork, `github.com/nfastje/Warcraft-3-Mod-survivor` (MIT, from
  `Willios/Warcraft-3-Mod-survivor`, remote `upstream`). Claude commits and pushes here when asked.
  Take the author's game updates with `git fetch upstream` and `git merge upstream/main`.
- Since 2026-11-01 `engine/` is in this repository: the author's open-realm fork
  (`github.com/Willios/open-realm-williosfork`, branch `survivor`) added as a squashed git subtree.
  Engine changes are committed here like any other file. Take the author's engine updates with
  `git subtree pull --prefix=engine https://github.com/Willios/open-realm-williosfork.git survivor --squash`
  (from the repository root, clean working tree), then rebuild.
- Bundling Blizzard data (as the Azeroth Survivors website download does with WoW MPQs) is the
  user's own risk decision; it never goes into either GitHub repository (DMCA takedowns hit the repo).
- **Never commit `release/`**: the portable build bundles the user's Warcraft III install
  (`War3.mpq`...). No `*.mpq`, no extracted Blizzard files, no zone thumbnails (screenshots of
  Blizzard maps). Tester builds go to GitHub Releases (the 4 MB SFX has no Blizzard data).
- `engine/dist/` is build output and ignored (`engine/.gitignore`); anything hand-written that
  lives only there must move into a tracked folder.
- Tests load and may save the real profile (`%APPDATA%\warcraft-3\CustomMapData\WarcraftSurvivors\profile2.pld`
  since save version 2; `profile.pld` is the old version 1 save, kept as a backup): back it up first and compare
  after, or run the engine with `APPDATA` pointing at an empty folder.
- Balance and mechanics pass: `docs/balance-plan.md` (phases, decisions, what each phase changed). Phase 1
  (2026-11-01): Warcraft III attributes per hero (`HEROES` `primary`/`attr`/`gain`), Stamina health, spell power,
  attribute stat cards; tuning numbers in `CFG`. New icons must already be in `tools/web_trace_reads.txt`, or the
  trimmed game data lacks them. Upgrade codes return their first level's art (Rhst gives the Sorceress Adept icon,
  which the data lacks): name the icon file instead. Phase 2 (2026-11-01): mana. `MANA_DATA` (Warcraft III cost
  and cooldown per ability) sets `def.mana`; `R.mana`/`R.maxMana` are the script's own (the engine has no
  `BlzSetUnitMaxMana`); `G.updateSpells` waits for mana.
- Keys (2026-11-01): spells cast on 1-4 or a slot click (`G.castSpell` -> `G.cast(inst, true)`; manual casts
  skip the heal/buff conditions), Shift+1-4 toggles autocast (`inst.auto`, off when learned: `CFG.AUTOCAST`, on
  for touch; test aid `+set survivor_autocast 1`), Ctrl+1-4 picks cards. A binding is key + 256 x modifiers
  (`META_STEP`; Reforged meta keys 1 Shift, 2 Ctrl), every key is registered plain, Shift and Ctrl (Reforged fires
  only the exact modifiers), and movement keys fall back to their plain binding while a modifier is held. The
  engine now does the same: `g_oskey.c` keeps each registration's meta and fires it only for those exact
  modifiers, and with `cl_fkeys 0` letters and digits skip their stock binds and command-card hotkeys (Q was the
  quest log, digits control groups, S Stop). Test key events through `oskey <engine key> <down> <mods>` in a cfg:
  keys posted to a hidden window with PostMessage do not carry Shift (Windows does not see it held). Ctrl+1-4
  switch browser tabs in Chrome: the web build needs other card keys.
- Phase 3 (2026-11-01): unlocks. `talent.unlock` / `hero.unlock` name an achievement (`ACH_BY_KEY`);
  `Profile.talentOpen`, `Profile.heroOpen`, `Profile.unlockText`. Hero chains are built after the achievement
  list ("<Hero> Joins": a boss with the first hero via `p.heroBosses`, 5:00 with the second via `p.heroTime`, kept by `G.endRun`). Starting heroes:
  Archmage, Blademaster, Death Knight, Demon Hunter. `Lobby.enter` refuses a locked hero; tests that call
  `G.startRun` directly (or `survivor_run`) are not gated.
- Phase 4 (2026-11-01): items. `item.stats` (`{key, stat, w}` in `ITEM_STAT_ORDER`) and `item.effect`
  (`ITEM_EFFECTS`); every value goes through `gearValue(b, w, ilvl)` (whole attributes, effect caps). Text:
  `G.describeItem`, `G.describeItemEffect`, `G.describeItemNext`. Effect fields live in `G.baseStats`; their
  timers and counters (`thirstUntil`, `souls`, `wardReady`, `escapeReady`, `sanctuaryReady`, `flamesClock`) on the
  run. Effect keys double as damage meter sources (`SOURCE_NAMES`), so they must not clash with spell keys. The
  engine wraps text anywhere, even inside "+3.4%": keep stat lists one per line, never one wrapped paragraph.
  Test aid: `+set survivor_gear "ofro desc clfm"`.
- Loading screens never reach `+screenshot`; capture only the game window with `PrintWindow`.
- Test aids: `+set survivor_tab codex` opens a lobby tab; `+set survivor_menu keys` opens the options
  at a page (`main`, `audio`, `keys`, `interface`); `+set survivor_run "5 1 1 2"` (hero, zone,
  difficulty, key) starts that run directly on the arena map; adding
  `Scripts/Survivor/test_defeat.lua` to `wc3_lua_script` kills the hero after 4 s (end screen).
  The server runs at 10 Hz (`FRAMETIME` 100 ms): count screenshot waits in client frames.
- On a clean exit the engine archives cvars into `%APPDATA%\warcraft-3\config.cfg` (the old
  windowed launcher left `vid_fullscreen "0"` there). Test runs that are killed write nothing.

### How the survivor script runs in the engine

The same Lua file as the Reforged map, unchanged. Engine-side pieces (all on branch `survivor`):

- `games/warcraft-3/game/g_lua.c`: Lua 5.4 host. Unknown Lua globals resolve to JASS natives,
  Blizzard.j functions and JASS globals; arguments convert by the native's `common.j` signature.
  Lua functions passed as `code` become native `jassFunc_t` records (trampoline). Handles are
  userdata keyed by pointer (edicts: slot + spawn time; enums: type + value). Calls run with the
  local human as `GetLocalPlayer()`. Runs `war3map.lua` maps, or `wc3_lua_script` files on any map.
- `games/warcraft-3/game/api/api_reforged.h`: natives newer than 1.29 `common.j` (frames, keys,
  unit/effect setters) plus their declarations, loaded right after `common.j`.
- `games/warcraft-3/game/hud/hud_script_frames.c`: `BlzCreateFrameByType` pool drawn on
  `LAYER_GAME_4` (`UIFLAG_PAINT_ORDERED` keeps tree order); clicks come back as `scriptframe`,
  pointer enter/leave as `scriptframehover` (client side: `SCR_LayoutScriptHover` in `cl_scrn.c`).
  A BACKDROP created with a template name (`EscMenuBackdrop`, `QuestButtonBaseTemplate`,
  `EscMenuButtonBackdropTemplate`, ...) copies that FDF backdrop (`UI_BackdropTemplate` in
  `hud/hud.c`) and draws with its edge file; `BlzFrameSetTexture` replaces only its background
  (its `blend` argument decides whether the background keeps its alpha).
  `BlzFrameSetAllPoints(world frame, game UI)` sets `PS_UIFLAG_FULL_WORLD`: the 3D view fills the window.
  `SPRITE`/`MODEL` frames take `BlzFrameSetModel`: the model plays Stand inside the frame (client
  `FT_MODEL`, `SCR_LayoutDrawPortrait`) seen from the front (models face +X; camera yaw -20 deg), fitted
  to its bind-pose body (`G_GetModelBindBounds` in `g_model.c`: geosets hidden at Stand start and flat
  ground decals such as the hero glow are skipped, 1st..99th percentile per axis). The file's sequence
  extents are padded (most heroes' include the glow), which made half the heroes look far away.
  `EngineFrameSetTeamColor(frame, color)` (engine-only native) sets its team color.
  Template lookups search `EscMenuTemplates`, `QuestDialog`, `StandardTemplates`, `BattleNetTemplates`
  and `DialogWar3.fdf` (the riveted iron `DialogBackdrop`); the Battle.net heavy/light corner
  templates have no texture in 1.29 (magenta).
- `games/warcraft-3/game/g_preload.c`: `PreloadGenClear`/`Preload`/`PreloadGenEnd` write retail-format
  preload files to `%APPDATA%\warcraft-3\CustomMapData\`; `Preloader` runs their `//!beginusercode`
  Lua block; `BlzSetAbilityTooltip`/`BlzGetAbilityTooltip` round-trip. The profile saves and loads this way.
- `EngineUnitModel(unitId)` (Lua, engine only) returns a unit type's model file (for the lobby portrait).
- `EngineCvar(name[, value])` (Lua, engine only) reads/sets console variables, which survive a map
  change. The script uses it to hand the chosen run from the menu map to the zone map and to style
  the zone's loading screen: `wc3_loading_quiet 1` (black), `wc3_loading_title/_subtitle/_text`,
  `wc3_loading_background` (row of `[LoadingScreens]` in `UI\WorldEditData.txt`; 34 = Ashenvale).
  The menu map and the zone arenas are listed in `SURVIVOR_ENGINE` in `src/engine_boot.lua`.
- `games/warcraft-3/game/g_oskey.c`: `BlzTriggerRegisterPlayerKeyEvent`; the client forwards keys
  as `oskey` when `PS_UIFLAG_FORWARD_KEYS` is set. `oskey` takes **engine** key codes: letters are
  lowercase ASCII (`d` = 100, `w` = 119), Escape 27, Space 32; uppercase codes are silently ignored.
- `EngineQuit()` (Lua, engine only) quits like the main menu's Quit (cvars are archived).
- Layered animation (engine only, World of Warcraft style): `EngineUnitUpperAnimation(unit, name[, speed])`
  plays a one-shot clip (attack, spell) on the bones from the chest up while the legs keep the base
  animation (walk); `''` ends it. Server: `edict.upper_animation`, `G_RunUpperAnimation` in `g_model.c`,
  sent as `entityState_t.upper_frame` (0 = none). Renderer: `MDLX_BindBoneMatricesUpper` in
  `r_mdx_anim.c` blends those bones in over 120 ms and out over 200 ms; the upper body is a node
  named like `Bone_Chest` (not a horse's) and everything under it (`MDLX_FindUpperBody`, found at
  load); without one the clip plays on the whole model. The hero swings and casts this way while
  walking (`G.heroSwing`, `R.upperAnim`); standing, it plays the whole-body sequence.
- `EngineUnitAnimation(unit)` (test aid) returns the sequence name, frame and upper clip the engine plays.
- Ground telegraphs (2026-10-31, WoW-style boss warnings; neither open-realm, azeroth-survivors-re nor benilla has
  one, benilla only has the 1.12 AoE reticle, `Spell-Shadow-*.blp` projected on the ground):
  `EngineTelegraph{shape='circle'|'ring'|'cone'|'line', x, y, angle (deg), radius, inner, arc (deg), length, width,
  duration (s), r, g, b, a, flash}` returns an id, `EngineTelegraphStop(id[, fade])` fades it without the flash.
  Server: `G_SendGroundTelegraph` (`g_effects.c`) sends one `TE_GROUND_TELEGRAPH` temp event (`groundTelegraph_t`
  in `common/shared.h`). Client (`cl_tent.c`, `CL_AddTelegraphs`) owns the timeline from its arrival: 150 ms fade
  and grow-in, fill swept from the origin to the edge over `duration`, then a 450 ms flash and fade (250 ms fade
  without flash), and fills `viewDef.telegraphs`. Renderer: `games/warcraft-3/renderer/r_telegraph.c`, one splat
  rect per telegraph whose UVs are the world XY, so the fragment shader draws any shape/angle procedurally (body
  faint in the middle and denser at the edge, outward ripples, bright rim + outer glow pulsing faster near the hit,
  hot fill with a bright front band). Drawn after the splat rects, so water draws over it (tinted in shallows).
  Script: `G.telegraph(spec)` (Flame Strike art on Reforged), `G.inTelegraph` (hit test), `G.bossCast` cycles
  `G.bossKits` (bosses: slam, cleave, slam, charge; final: slam, cleave, nova, charge, every 6.5 / 5.5 s);
  the boss stands still while it casts aimed spells (`info.casting`, `G.updateHeld`: Reforged counts
  `BlzPauseUnitEx`, the engine keeps a flag). Test aids: `+set survivor_boss final` (or 1-4) brings that boss in at
  3 s; `tools/engine_tests/test_telegraph.lua` (add-on) loops all four shapes around the hero, or with
  `+set telegraph_shapes 0 +set telegraph_kite 1` keeps the hero alive and slides it around the boss.
- Movement/animation test: `Scripts/Survivor/test_moveanim.lua` steers the hero with the same orders
  a right-click gives (re-clicks every 0.4 s, a tree click at 20 s) and logs `MOVEANIM` lines (sequence,
  upper clip, position) for 30 s. Run it with `+set survivor_run "5 1 1 2"` and `+exec pickcards.cfg`
  (presses 1 about once a second so level-up cards do not pause the run).
  **Use real input for input bugs:** `python tools/engine_clicks.py realclicks 0 -256 500 300 20 150`
  writes cfgs that send the client's own right-click command (`cmd smartpoint X Y`) around the spawn
  and pick cards; run with `+exec realclicks.cfg` and `+set moveanim_clicks 0` (the add-on then only logs).
- `vid_aspect` (cvar, set by the client in `cl_main.c` whenever the window size changes): the
  frame space is 0.6 high and centered on x 0.4, so the screen spans `0.4 +- 0.3 * vid_aspect`.
  It is empty for the first frames of a map: the HUD re-checks it every update (`Hud.edges`).
- Sound groups (`sound/s_sound.c`, `S_SetGroupVolumes`): each sound file is scaled by its group's
  cvar, by path: `Abilities\` -> `s_spellvolume`, `Sound\Ambient\` and `Doodads\` -> `s_ambiencevolume`,
  `Units\` and `Sound\Units\` -> `s_unitvolume`; music is `s_musicvolume`. The options menu sets them.
- `SetUnitAnimation` with a looping sequence (walk, stand) sets `UNIT_FLAG_ANIMATION_OVERRIDE`, and
  `M_MoveFrame` loops it instead of letting the unit's move pick its own clip (the hero's walk used
  to turn back into stand after one cycle). One-shots (attack) still end normally.
- Weapon field constants (`UNIT_WEAPON_RF_ATTACK_RANGE`, `_PROJECTILE_SPEED`, `UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART`)
  and their types are declared in `api_reforged.h`. Before that they were nil: every hero was
  read as melee (no missile, stop-and-swing), and passing nil to the native crashed the engine.
- Controls (script): Escape opens a WoW-style game menu (buttons stacked; Audio, Keybinds and
  Interface open their own page, Escape goes back). Movement is mouse (right-click) **or** keyboard
  (`Profile.data.opts.wasd`), never both; the mouse path in `G.updateMovement` is unchanged.
  Bindings: `ACTIONS` (default key codes = OSKEY values, Windows VK), saved in `Profile.data.binds`
  only when not default; binding a taken key swaps the two. Every key in `KEY_LIST` is registered.
  The starting spell is chosen per hero in the lobby pool (`Profile.data.starts`, `G.startSpell`).
- **Fixed 2026-10-29:** non-permanent text tags were never freed on the server, so after 100 damage
  numbers `CreateTextTag` failed for the rest of the map (`G_RunTextTags` in `g_multiboard.c`).
- `UnitDamageTarget` with a weapon type now plays that weapon's impact sound on the target's armor,
  as retail does (`G_PlayWeaponImpactSound` in `g_sound.c`). The hero's auto-attack passes its
  weapon type, read with `BlzGetUnitWeaponIntegerField(u, UNIT_WEAPON_IF_ATTACK_WEAPON_SOUND, 0)`
  (declared in `api_reforged.h`). Before, scripted hits were silent: only enemy hits clashed.
  `test_hitfx.lua` prints the hero's weapon sound type and churns 250 short-lived text tags.
- **Fixed 2026-10-29, sound:** the renderer skipped a model's events on its first sighting (meant for
  units scrolling into view), so every fresh spell effect lost its sound, keyed at the start of its
  sequence. A world model first seen within `WC3_EVENT_FRESH_MS` (250 ms) of its sequence start now
  fires its opening keys (`R_W3DispatchModelEvents` in `renderer/r_game.c`). Effects whose model has
  no SND event (Blizzard, Rain of Fire, Wind Walk, Impale) play a label from `AbilitySounds.slk` via
  `G.sound` (`def.sound` on cast, `def.waveSound` per wave).
- Script frames stack by (level, creation order) among siblings (`SF_BuildTree`); the smoke test's
  `MOCK.click` now picks the topmost button the same way.
- `BlzGetAbilityIcon` on an upgrade rawcode returns its per-level art list (`A.blp,B.blp,...`); the
  script keeps the first entry.
- Lobby title: `src/art/title.tga` (1024x128, WC3-logo style from the game's Friz Quadrata), made by
  `python tools/make_title.py <FRIZQT__.TTF> src/art/title.tga [preview.png]`; extract the font with
  `mpqtool cat 'Fonts\FRIZQT__.TTF'` and undo the `\r\n` translation. Engine only; Reforged shows gold text.
- 2026-10-30: Siphon Life talent (1 to 5 percent lifesteal, `s.lifesteal`, every damage source), hover tooltips on
  talent rows (`UI.tooltip`, shared with the HUD's spell/blessing tips), in-run Inventory panel (top right, 2x3,
  hover shows the item: `Hud.refreshGear`/`Hud.gearTip`), and the Wisp Companion perk (Rewards, 3 ranks): a wisp
  effect (`G.updateCompanion`) fetches gems and coins outside the pickup range. The smoke test checks the wisp.
- 2026-10-30: Endless mode (after Azeroth Survivors): the victory screen's **Endless Mode** button resumes the
  won run (`G.continueEndless`); the victory is banked first, and the endless end (death, or Restart/Main
  Menu = `G.endRun(false, true)`) adds only the gold/kills/bosses since (`R.banked`) and keeps the longest
  endless time per zone (`Profile.data.endless`, achievements at 15/20/30 min). Enemy health x1.15 and damage
  x1.08 per endless minute (`G.endlessScale`, `CFG.ENDLESS_*`), the horde at `MAX_ENEMIES`, a boss every 90 s
  (the zone's bosses then its final boss, in turn), elites every 25 s, rings continue.
- 2026-10-30: Stats panel under the hero frame (`STAT_ROWS`, `Hud.refreshStats`): one row per stat with the
  icon of the blessing that raises it, green when above the base; the `stats` action (C) hides it
  (`Profile.data.opts.stats = 0`).
- 2026-10-30: Storm, Earth and Fire is a real split (`def.split`, `G.startSplit/updateSplit/endSplit`): the hero
  is hidden (alpha 0), invulnerable and casts/attacks nothing for 12 s (x spell duration, not rank), enemies
  attack the spirits (`G.decoyNear`), the spirits are removed and the hero reappears; the cooldown starts at the
  merge. Before, the spirits lasted one cooldown and, at high rank, the split recast itself forever.
- 2026-10-30: Warden and Priestess of the Moon carry Shadowmeld (`Ashm`, `UnitAbilities.slk`); the script moves
  the hero, so the engine saw it standing still and hid it at night. The hero (and Mirror Images) lose `Ashm`.
- 2026-11-01, features ported in spirit from the Reforged fork (stock 1.29 art only, nothing imported):
  - **Medivh** (Tavern, hero 25): the campaign's `nmed`, a plain unit (hero natives are no-ops). His model has no
    Attack/Spell, only `Spell Attack` (hero fields `attackAnim`/`castAnim` = `spell`, kept in `R.attackAnim/castAnim`).
    Kit: Arcane Barrage (Mana Flare art), Raven Form (buff `morph = 'alternate'`: `AddUnitAnimationProperties` turns
    him into the raven, `Attack Alternate` for swings; `fly` = no collision), Enchanted Crows (orbit, Destroyer
    missile), Dark Portal (summons `ogru`, then `nchg` from rank 3). Icons BTNManaFlare/RavenForm/EnchantedCrows/DarkPortal.
  - **World objects** (`G.spawnWorldObject`, `WORLD_OBJECTS`, after Forgotten Hollow): Mine Cart, Barrel, Wooden
    Chest (paid, card hand), Pile of Treasure, Standard of Wealth, Shrine of Chance (paid, 55 percent hand), Shrine of
    Protection (10 s with no enemy near). Three at the start, one every 58-78 s, at most 6, gone after 100 s; walking
    within 150 uses one. Gold swirl (`GeneralAuraTarget`), a yellow ring (engine telegraph with a 100000 s cast, stopped
    on removal; Reforged has none), a permanent text tag for prices. Test aid: `+set survivor_objects all`.
  - **Hold to move**: the script sets `cl_smart_hold 1`; a held Smart button (right mouse) sends the ground point
    under the cursor every `cl_smart_hold_ms` (100) and at the press (`CL_SmartHoldFrame` in `client/cl_input.c`,
    ground only, never over the HUD). Test command `cursor <x> <y>` pushes a real mouse motion (hidden windows keep
    the cursor at 0,0, over the hero frame); `+smart`/`-smart` in a cfg hold and release.
  - **Touch** (browser): `cl_touch_smart 1` (script) makes a single finger on the world a held right button (the HUD
    and menus keep the left click). `survivor.js` sets `survivor_touch 1` on a coarse-pointer touch device; the
    script then forces mouse movement, shows a touch footer and a HUD Menu button (no Escape key on a phone).
  - **Collision** (`G.collide`): enemies block the scripted walk with their pathing radius (`EngineUnitCollision`,
    engine-only; `BlzGetUnitCollisionSize` on Reforged), scaled for bosses/elites; only steps toward an enemy are held
    back. Always on (the user's rule, 2026-11-01: no option to turn it off); Raven Form and Wind Walk pass through.
  - Blood (`FX.heroBlood`, CritterBloodAlbatross) on the hero at most every 0.2 s; Transmute 1.2 percent per rank.
  - Test add-on `tools/engine_tests/test_medivh.lua`: heals every player unit (Medivh is not `UNIT_TYPE_HERO`, which
    `test_plague.lua` heals), logs `MEDIVH` lines (position, sequence, upper clip), wolf packs every `medivh_pack` s.
  - `web_trace.py`: heroes beyond two per zone get a `heroNN` session (test_medivh, all objects, `medivh_spawn` = every
    unit their summons call); `reads --add <dirs>` merges traces of `run --only ...` into the current list.
- Test aid: `+set survivor_autopick 1` (engine) picks the first card of every hand after 0.3 s. Use it for any
  unattended run longer than a minute: `pickcards.cfg` presses are frame-counted and run out within seconds
  when `com_maxfps_background 0` lets a hidden window render hundreds of frames per second.
- `tools/engine_tests/test_zone_cycle.lua` (add-on, start on the menu map): `+set zone_cycle <n> +set zone_cycle_run
  "5 4 1 2"` goes menu -> zone (20 s, hero healed) -> menu n times, like Enter Zone / Return to Camp in a long session,
  for memory measurements across map loads. Logs `CYCLE` lines.
- `tools/engine_tests/test_plague.lua` (add-on): keeps the hero alive, logs `PLAGUE` lines (enemy count by
  type every 5 s) and, unless `plague_units "zzzz"`, spawns the Plaguelands casters next to the hero every 10 s.
- Web: the engine checks `emscripten_is_webgl_context_lost` about once a second (`R_WebCheckContextLost` in
  `renderer/r_main.c`) and calls the page's `openrealmContextLost` (survivor.js: reload prompt) instead of
  leaving a black canvas. Nothing recreated GL objects after a context loss before.
- Difficulty: Normal / Heroic / Mythic / Mythic+ (no cap, no affixes since 2026-10-29), opened per zone
  by winning the one before. The lobby button opens a window listing all four (`Lobby.buildDifficulty`);
  `+set survivor_menu difficulty` opens it for screenshots. Zone `power` climbs 0.7 (Ashenvale) to 3.3
  (Northrend); `density` thins the horde in the first two zones.
- Volume: a Master row drives `s_volume` (all effects, including sound kits and interface sounds that
  bypass the groups) and multiplies the music; every slider is squared (audio taper), so 10 is -40 dB.
- Zone thumbnails: `src/art/zone_*.tga` (512x256 crops of an arena shot, see `test_zone_shot.lua`),
  copied to `dist\windows\share\warcraft-3\Scripts\Survivor\`. All 12 zones have one (2026-10-30): shoot
  with `+set shot_fog "r g b start end"` and `+set shot_time` from the zone's `fog`/`time`, take the
  middle 1280x640 of the 1280x720 shot and resize it to 512x256 (24-bit uncompressed TGA, as PIL saves). Engine only; Reforged shows the campaign art.
- `games/warcraft-3/jass/jdo.c`: small public bridge API (native function records, pinned refs,
  signature access) and coroutines that can run native callbacks.

### Engine problems found (open or worked around)

- **Fixed 2026-10-31, gameplay (Northrend "everything bugged"):** a hit made the hero counterattack natively
  (`can_attack` in `skills/s_attack.c` ignored the script's `UnitRemoveAbility(hero, 'Aatk')`, which only auto-acquire
  honoured). Against ranged attackers the hero walked off to chase them (native `attack_walk`, no order, no `Amov`), on
  top of the scripted walk: double speed, Bladestorm's spin replaced by native walk/attack clips, the hero drifting
  while idle. Northrend opens with ranged Ice Trolls, so it showed at once; every zone with ranged enemies had it.
  Retaliation now skips a unit whose Attack was removed. `tools/engine_tests/test_zone_audit.lua` (add-on, any zone,
  `audit_seconds`, `moveanim_clicks 0` = no scripted orders) logs slots, the hero's speed/animation/native order and
  counts the script's own `SetUnitX` calls on the hero (`scriptMoves`): movement with `scriptMoves=0` is native.
  The crash the user saw there was not reproduced (4 min Northrend after the fix, clean).
- Engine unit tests on Windows: from MSYS2 (see Quick rebuild), `export PATH="$PWD/build-windows/lib:$PATH"` first
  (mpqtool and the tests need the DLLs, else exit 127), `make ... openwarcraft3-tests test-assets`, then
  `build-windows/bin/openwarcraft3-tests.exe -data build/tests +dedicated 1 +test "client_input.<name>"`.
  **Open (upstream, 2026-11-01):** `client_input.quick_arrow_press_is_sampled_before_release` kills the process
  (exit 127, also on the committed baseline): it copies `struct client_state` onto the stack, where the other tests
  `MemAlloc` it. So `+test "client_input.*"` dies there; run the tests one by one.
- 2026-10-31: F1-F11 run none of their stock binds (hero select, `save quick`, stock game menu, quests, allies) when
  `cl_fkeys` is 0 (`Key_Event` in `client/keys.c`; script key events still get them). The script sets it in `G.boot`.
- 2026-10-31: icon: `python tools/make_icon.py <FRIZQT__.TTF> tools/release/warcraft_survivors.ico [preview] [icons dir]`
  (gold "WS"). The launcher compiles with `/win32icon` (`make_portable.ps1`); the engine exe embeds a copy,
  `engine/port/windows/openwarcraft3.ico` (`openwarcraft3.rc`, windres rule in `games/warcraft-3/game.mk`), which SDL
  uses for the window and taskbar; the web survivor shell uses `port/web/site/icons/survivor-180/192.png`.
  The 7-Zip SFX tester exe (`make_release.ps1`) keeps the SFX module's icon.

- **Fixed 2026-10-29, art:** `DestroyEffect` freed an effect at once when its model had no Death
  sequence, so caster art made and destroyed in one call (Thunder Clap, War Stomp, Mirror Image: one
  one-shot Birth/Stand only) never showed. It now finishes the playing one-shot first (`G_DestroyEffect`
  in `g_effects.c`). Effects with neither Birth nor Stand (AvatarCaster: only Spell) play their first
  sequence (`G_GetFirstAnimation`); a looping Birth with no Stand (the dragon-missile xp gems) keeps
  looping instead of being freed after 0.5 s.
- **Fixed 2026-10-29, gameplay:** a Lua handle to a freed effect still reached its edict slot, and a new
  enemy in that slot was moved by the script (the magnet pulled enemies). Lua handles now remember the
  edict's spawn time and pass null when the slot was reused (`g_lua.c`).
- **Fixed 2026-10-29, animation:** every native order (`unit_setmove` in `g_ai.c`) resets the unit's
  animation, and the native walk then flips it between stand and walk until the script's `stop`
  lands 1-2 server frames later. Each right-click cut Bladestorm's spin. Replaying the spin after the
  `stop` did not help. Fix: `EngineUnitScriptOrders(unit, true)` (`UNIT_FLAG_SCRIPT_ORDERS`,
  `m_unit.c`): move/smart/attack/patrol/stop/holdposition orders only raise their events, no native
  behavior starts. The hero uses it; the Reforged path still cancels with `stop`.
- **Fixed 2026-10-29, input:** a real right-click on the ground (`smartpoint` client command ->
  `move_selectlocation` in `skills/s_move.c`) called `order_move` directly and raised **no order
  event**: in the engine the hero always walked natively and the script's movement never ran. Script
  orders (`IssuePointOrder`) take another path (`G_IssueUnitPointOrder`), so tests using them missed it.
  For `UNIT_FLAG_SCRIPT_ORDERS` units the click is now published as a `smart` point order. Other units
  still raise no event on a ground right-click (retail does): open.
- **Fixed 2026-10-29, gameplay:** a right-click on a tree, doodad or item is a target order with no
  point; `GetOrderPointX/Y` returned (0, 0), the middle of Moonglade, and the hero walked back to the
  spawn. The script now reads `GetOrderTarget()` with `GetWidgetX/Y` (separate point and target triggers).
- **Fixed 2026-10-30, gameplay:** the hero walked through trees. Its walk check (`G.walkable`) drops a
  hidden item with `SetItemPosition` and reads it back; retail pushes the item off trees, the engine
  put it exactly where asked. `SetItemPosition` now moves the item to the nearest free cell of the
  static pathing map (terrain plus baked buildings and destructables,
  `CM_ClosestStaticPathablePointForRadius` in `server/sv_routing.c`). `IsTerrainPathable` still reads
  only the terrain map. `test_trees.lua`: 8 of 8 Moonglade trees move the probe.
- Zones (2026-10-30): 12, each on its own official melee map with a matching tileset
  (`SURVIVOR_ENGINE.arenas` in `src/engine_boot.lua`, keyed by `ZONES` index). Play order is
  `ZONE_ORDER` (Ashenvale, Westfall, Tirisfal Glades, The Barrens, Stranglethorn Vale, Plaguelands,
  Alterac Valley, Felwood, Dalaran, Hellfire Peninsula, The Black Temple, Northrend); zones 7-12 were
  added later and keep their index in saves and gear ids (`z7b1`...), so old inventories stay valid.
  `Profile.data.unlocked` counts open places in `ZONE_ORDER`; saves without `zones=2` counted the
  first six by index and are migrated once in `Profile.load`. Arenas: Moonglade, `(2)TerenasStand`,
  `(6)CopperCanyon`, `Maps\(8)Plaguelands.w3m`, `Maps\(8)BloodvenomFalls.w3m`, `Maps\(12)IceCrown.w3m`,
  `Maps\(4)HarvestMoon.w3m`, `(6)StranglethornVale`, `Maps\(4)Frostsabre.w3m`, `(6)WizardsRetreat`,
  `(4)DevilsCauldron`, `(6)Demon'sCrossing`. RoC `.w3m` maps load fine.
  Any unit of any race can be an enemy (the script orders a native `attack` on the hero, so ranged
  units shoot). Units added to a tuned roster carry `extra = true`: they share the health-ladder step
  (`1.12^(index-1)`) of the unit before them instead of pushing every later unit up a step.
  The hero spawns at the playable area's center, so a candidate needs open
  ground there: `test_arena_probe.lua` (run alone) logs `ARENA` lines (walkable share of rings around
  the center) and frames it for `+screenshot`, then quits. Rejected: `(6)RuinsOfStratholme` (0 walkable,
  Dalaran Ruins tileset), `(8)GoldRush`, `(8)PlainsOfSnow`, `(3)Nighthaven`, `(4)Hellfire`,
  `(8)Deadlands`, `(6)DragonFire` (center blocked).
  `test_zone_change.lua` (add-on, `+set zone_change "5 4 1 2"` on the menu map) enters a zone the way
  the lobby does (`survivor_run` + `ChangeLevel`) and logs `ZONERUN` lines (enemies, hero), quits at 40 s.
  A run that ends (the idle hero dies) saves the real profile: back it up and restore it.
- **Fixed 2026-10-30, gameplay:** `UnitApplyTimedLife` was an empty stub, so every script summon
  (Feral Spirit, Water Elemental, all `kind = 'summon'` spells) lived forever and piled up to
  `CFG.MAX_SUMMONS`. It now applies the engine's BTLF status (`S_SpellApplyTimedLife`), which kills
  on expiry; the buff id argument is ignored (only BTLF expiry kills in `m_unit.c`).
- `GetTriggerEventId` is a stub in the engine (always null): do not branch on it; register one
  trigger per event instead.
- `Abilities\Spells\Orc\WindWalk\WindWalkCaster.mdl` does not exist in 1.29 (Wind Walk fades the hero).
- The Lua host has no `debug` library: test add-ons cannot reach the script's locals. Use cvar test
  aids instead, e.g. `+set survivor_spells "thunder_clap mirror_image"` (extra spells at run start).

- **Fixed 2026-10-29, gameplay:** damage triggers now run during the hit (`G_RunDamageTriggers` in
  `g_events.c`, called from `T_DamageInternal`), so `BlzSetEventDamage` changes the damage taken
  (dodge, damage reduction, extra lives work).
- **Fixed 2026-10-29, gameplay:** periodic timers fired at most once per 100 ms frame, so the
  script's 0.03125 s tick ran at a third of real speed (hero slow, enemies at full speed). They
  now fire once per elapsed period (`G_RunTimers`, at most 16 per frame).
- **Fixed 2026-10-29, gameplay:** `IsTerrainPathable` always answered "blocked": every spawn
  fell back to a random point next to the hero and WASD probes failed. It now reads the
  terrain pathing map (walk, float); other pathing types report pathable.
- **Fixed 2026-10-29:** `EnableUserControl(false)` blocked camera input on the server only; the
  client kept predicting scroll and zoom, so the view drifted. It now sets `PS_UIFLAG_NO_CAMERA`.
- **Fixed 2026-10-29:** the FDF frame pool (`MAX_UI_CLASSES`, was 2048) overflowed when script
  templates loaded the glue template files, and the engine then crashed. Now 4096.
- **Open, UI:** the portrait/minimap origin frames are not drawn where the script places them
  (the minimap is off now: `CFG.SHOW_MINIMAP = false`).
- **Fixed 2026-10-29:** black band under the world (the viewport stopped above the console), no
  mouse enter/leave frame events, `Preload*` natives were no-ops (no saved profile).
- **Open:** `SetCameraBounds` with a small rect moves the camera off its target. The lobby no
  longer uses the world (gradient background, model frame portrait), so this only matters for maps.
- **Fixed 2026-10-29, art:** the magenta armory icons were upgrade rawcodes whose icon is a
  comma-separated list. Gear is now Warcraft III items (`ZONE_ITEMS`), all checked in 1.29 `ItemFunc.txt`.
- **Alt+Tab (2026-10-29, untested by the user yet):** the borderless window is now one row taller
  than the display (an exact-fit GL window is promoted to exclusive fullscreen by Windows/drivers,
  which blanked and stalled the desktop on Alt+Tab), and the frame rate drops to
  `com_maxfps_background` (20) while the window has no focus.
- **Map load cost:** about 1.3 s game init per process plus 3.7 s per map load, whatever the map
  size (Echo Isles took as long as Moonglade). A second load in the same process took about 4 s.
- **Open:** each distinct Lua callback closure allocates a `jassFunc_t` that is never freed.
  A native that raises a JASS runtime error (longjmp) while called from Lua would skip Lua frames.

- **Upstream Windows build broken (fixed locally):** `common/map_load_debug.h` included
  `<windows.h>`, whose `SetRect`/`GetClassName` clash with WC3 game symbols. Now includes
  `<windef.h>` + `<winbase.h>` only.
- **`tools/build-windows.ps1` DLL bundling fails** because the project path has spaces.
  Workaround: run `dist-scripts/windows/bundle_mingw_dlls.sh dist/windows build-windows/bin/openwarcraft3.exe build-windows/lib/*.dll`
  from MSYS2 with relative paths, then copy `build\share` to `dist\windows\share`.
- **Intermittent black world at start (open):** sometimes only the HUD draws (terrain is
  submitted, screen stays black, minimap camera outline is squashed). Not fog related.
  Not reproduced in 6 later runs. Parked by the user on 2026-10-29.
- **Reforged map formats:** `map/WarcraftSurvivor.w3m` loads (terrain, camera), but
  `war3map.doo` v13/11 and `war3mapUnits.doo` v13/9 are rejected (`unsupported war3map.doo version`),
  and `war3map.lua` is ignored (the engine only runs `war3map.j`). Custom maps go in
  `dist\windows\share\warcraft-3\Maps\` (the `-data` folder's `Maps\` also works).
- **Reforged-saved terrain renders broken** (stretched streaks under the camera) on
  `map/WarcraftSurvivor.w3m`. Not investigated: arenas are official maps now (the user's choice),
  run with `+set wc3_lua_script "Scripts/Survivor/ashenvale_survivor.lua,Scripts/Survivor/engine_boot.lua"`
  and e.g. `+map "Maps/FrozenThrone/(6)Moonglade.w3x"` (Ashenvale tileset). The scripts are copied
  from `src/` to `dist\windows\share\warcraft-3\Scripts\Survivor\`.
- **Rawcode byte order:** the engine reads `'Hamg'` as a little-endian integer (string byte
  order), retail is big-endian. The Lua bridge's `FourCC` uses `string.unpack('<I4', s)`;
  any code that builds rawcodes by hand must do the same.
- **EVENT_PLAYER_UNIT_DAMAGED** is missing from 1.29 `common.j`; it is declared in the
  engine's Reforged declarations (`api/api_reforged.h`). `TriggerRegisterPlayerUnitEvent` crashed on
  a null event before a guard was added.
- Melee map strings show raw keys (`CRIPPLE_TIMER_HUMAN`) with the French locale MPQs.
- **Fixed 2026-11-01 (script workaround), positioned script sounds dropped the game to the main menu:**
  the Lua host runs every call as the local player (`g_lua.c`), so `StartSound` takes its owner-only path and
  `SV_StartSoundPolicy` tags the packet `SND_ENT` with the player's entity 0. `CL_ParseSound` rejects entity 0 and
  returns before reading `SND_POS`, so the position's bytes were read as message codes (`Unknown message N`, rest of
  the packet dropped). A low X byte of 19 (`svc_disconnect`) disconnected: about one Blizzard cast in 256, all six
  waves share the spot. `G.sound` now skips `SetSoundPosition` in the engine (an unpositioned owner sound writes
  neither field), which keeps the script safe on the author's engine builds too.
  Repro: a script `StartSound` positioned at x 275 logs `CL_Disconnect: Server disconnected.`
  **Engine fixed the same day:** `CL_ParseSound` reads every announced field before rejecting (a bad entity with a
  position plays there), and `SV_StartSoundPolicy` sends no `SND_ENT` for entity 0. Test:
  `client_sound.bad_entity_still_reads_position` in `client/cl_parse.c`.
- Builds made from a non-English 1.29 install show its text. `python tools/make_english_text.py "<Reforged folder>"
  "<engine Data folder>" [locale]` writes `War3zText.mpq` (the string files from Reforged's CASC storage,
  `tools/reforged_casc.py`); it sorts after `War3xLocal.mpq`, so the engine reads its strings instead. Voices stay
  (Reforged's are .ogg).

## Mistakes log

Every mistake Claude makes in this project is recorded here, with the lesson.

- **2026-11-01:** The first `web_trace.py reads --add` merged the new traces into the list but counted only their
  names as known, so ~70 script paths already listed per archive came back as duplicate `*` lines (caught in the
  diff before any data was built). The first Medivh trace also missed the chaos grunts his Dark Portal calls only
  from rank 3. Lesson: diff a regenerated list against the old one before using it, and trace what higher ranks
  and random spawns bring, not only what a short run happens to show.

- **2026-10-31:** During the Northrend audit a Python patch with `\037` went through a Bash heredoc again (sixth time);
  its assert caught it and nothing was written. Lesson unchanged: anything with `\` goes through the Edit tool.

- **2026-10-31:** Telegraph work: a Python patch passed through a Bash heredoc turned `\n` inside C strings into real
  newlines and broke the engine build (fifth time for this lesson), and a later heredoc silently missed a `\037`
  replacement. Also, the client read `MAX(0, MSG_ReadLong(msg))`: the macro evaluates its argument twice, so it read
  two longs, desynced the message and dropped every later temp event in the packet (only the first telegraph of each
  batch arrived, with the colour as its duration). Lesson: edits with `\` go through the Edit tool, no exceptions;
  never pass a reading/side-effect call to `MIN`/`MAX`, read into a variable first.

- **2026-10-31:** `make_portable.ps1` failed halfway: Claude's Bash shell had `cd`'d into
  `release\Warcraft Survivors Portable\OpenRealm` to list it, which locked the folder, so `Move-Item` copied
  everything to the `.previous-*` backup but could not delete the original (empty folders left behind).
  Lesson: inspect folders with absolute paths, never `cd` into a folder a script is about to move or delete.

- **2026-10-30:** The first trace-trimmed web data shipped without 11 hero icons (Keeper, Priestess, Warden, every
  Tavern hero) and without the zones' loading-screen art: the trace opened the lobby on one faction and started
  runs directly on the arena (`survivor_run`), so nothing drew the other factions' icons or a loading screen. The
  user found the magenta icons. `web_trace.py` now draws every icon the script can show (`test_icons.lua`) and
  enters each zone from the menu. Lesson: a usage trace covers only what it drives; list what the UI can show
  (every faction, page, screen) and drive each one, then compare the trimmed data on the same sessions.

- **2026-10-30:** The first file-trace batch (`OPENREALM_FSTRACE`) passed a relative trace path while the
  engine runs from `dist\windows`; no trace was written and the batch was stopped after its first wave.
  Lesson: paths handed to the engine (env vars, cvars) are absolute; check the first output exists.

- **2026-10-30:** While trimming the web archives, two Python scripts with backslash paths went through
  `python -c`/heredocs and failed to parse (third time for this lesson), and the first trim kept every
  shadowed War3.mpq file because the extension list was lower case while the names were upper case (caught by
  the per-archive counts before handover). Lesson: scripts with `\` go to a file; compare a new filter's
  result with the analysis it came from before trusting it.

- **2026-10-30:** The first web build was handed over with its 1-2 minute map loads blamed on headless
  software rendering ("With software GL the menu takes ~2 min" in this file); the user found the loads
  slow. Timing logs showed CPU/file phases, not rendering: per-sector OPFS reads. Lesson: when a
  new platform is slow, read the phase timings before naming a cause (repeat of the 2026-10-29 lesson).

- **2026-10-30:** Engine test batches backed up the real profile at their start and restored it at
  their end (about 6 minutes later) while the user was playing the game in between; a run the user
  finished inside that window would have been reverted. Lesson: before a batch that saves the
  profile, tell the user not to play until it ends, or keep the batch to one short run.

- **2026-10-30:** An 8-minute Plaguelands crash-hunt run relied on `+exec pickcards.cfg` with
  `com_maxfps_background 0`; the frame-counted presses ran out in seconds, a card hand paused the run at 1:30
  and the remaining 6.5 minutes tested nothing (the log's enemy count never changed). Lesson: check the first
  log lines of a long run for progress before waiting on it; unattended runs use `+set survivor_autopick 1`.

- **2026-10-30:** An 11-minute hidden test run played its music and sound on the user's speakers
  (`vid_hidden` hides the window, not the audio). Lesson: test runs get `+set s_volume 0`.

- **2026-10-30:** A "quick" screenshot run (`survivor_run`, no add-on) let the idle hero die at 0:11; the
  defeat saved one extra run into the user's real profile, with no backup taken (the user had played since the
  last one). Undone by hand (runs, kills, two codex entries). Lesson: **every** engine run with
  `survivor_run` can end a run and save: back up the profile right before it, and keep the hero alive
  (`test_plague.lua` heals it) when the run is not about dying.

- **2026-10-30:** Upload instructions said "a normal reload is usually enough" without checking the server's
  cache headers; OVH cached `index.js` for 15 minutes and the user got a black screen after uploading
  4 files. Lesson: check `curl -sI` headers of the live site before telling the user how fresh files reach
  players.

- **2026-10-30:** `test_plague.lua` healed the hero once a second; with 60 enemies the Lich died between two
  heals, the run ended and saved into the real profile (restored from the backup taken just before). The
  add-on now heals every 0.1 s. Lesson: compare the profile after every run that uses `survivor_run`, and a
  "keep alive" aid must outpace the worst burst, not the average damage.

**Rule: if you break anything, note it here.** Whenever a change of yours breaks something that
worked (a feature, a test, the build, the editor save, the user's profile), add an entry right away,
even if you fixed it in the same session: date, what broke, why, and the lesson.

- **2026-10-29:** Bladestorm "fixed" (spin replayed after the `stop`) and handed over without any test
  that moved the hero; the user found it still cancelled on the first step. A trace showed the native
  walk overriding the animation before the `stop` even ran. Lesson: when a test cannot exercise the
  input, build one that can (`IssuePointOrder` on the hero = a right-click, `EngineUnitAnimation` to
  read the result) before calling it fixed.
- **2026-10-29:** The second Bladestorm/attack fix was verified only with `IssuePointOrder` from a
  test script and handed over as working; the user saw no change, because a real right-click takes a
  different engine path (`smartpoint` -> `move_selectlocation`, no order event, native walk). Lesson:
  test input bugs through the real client command (`cmd smartpoint`, `tools/engine_clicks.py`), not a
  script-issued order that only looks equivalent.
- **2026-10-29:** `rm -f` emptied `engine/dist/windows/screenshots/` before a screenshot run without
  looking at what was there (older test shots). Lesson: list a folder before deleting from it, or
  write new shots elsewhere.
- **2026-10-29:** An engine test add-on used `debug.getupvalue` to reach the script's `G`; the engine's
  Lua has no `debug` library and the run was wasted. Lesson: engine test hooks go through cvars
  (`EngineCvar`), as `survivor_tab`/`survivor_run` do.

- **2026-10-29:** A Python script passed through a Bash heredoc matched `'ui\\framedef'` against
  file paths and found nothing (the heredoc changed the backslashes), and a long heredoc with
  quotes failed to parse at all. Lesson: write any script with backslashes or many quotes to a
  file with the Write tool and run the file (repeat of the 2026-10-29 backslash lesson).
- **2026-10-29:** The hero losing health fast was first taken for the `BlzSetEventDamage` no-op.
  The real causes were a stub `IsTerrainPathable` (spawns next to the hero) and timers running
  at a third of real speed. Lesson: log the actual hits and the clock before naming a cause.

- **2026-10-29:** The new stacked options menu could not be clicked (lobby and run): its full-screen
  click blocker (`UI.hit`, level 8) was a sibling of the page groups and stacked above them. The
  smoke test passed because `MOCK.click` ignored frame levels, and the engine check only took
  screenshots. Lesson: when frames move under new parent groups, check what lies above them; the
  mock now models the engine's stacking.
- **2026-10-28:** The Lua source used `%` in display text, patterns and modulo, which
  crashed the World Editor every time the code was pasted and saved. Lesson: test that the
  source contains no `%` before handing it over (see the rule above).
- **2026-10-28:** A smoke test failure was blamed on a fresh edit before checking whether
  it reproduced on the original file. It was a flaky random-loot step. Lesson: run the
  unchanged baseline before concluding that a change caused a failure.
- **2026-10-29:** To check the engine, a screenshot of the whole desktop was taken; the game
  was not in front, so it captured the user's browser. Lesson: use the engine's `screenshot`
  command (or capture only the game window), never the full screen.
- **2026-10-29:** C and Lua strings containing backslashes (`\n`, `\037`, `UI\\...`) were written
  through a Bash heredoc into Python patch scripts; the backslashes collapsed, which broke the
  engine build twice and turned a Lua pattern into control bytes. Lesson: make any edit that
  contains a backslash with the Edit tool, and grep the result.
- **2026-10-29:** A Python patch with `'\\037 power'` went through a Bash heredoc again; the
  assert caught it before writing. Lesson: Edit tool or a script file, never a heredoc, for `\`.
- **2026-10-29:** Movement tests sent `oskey 68` (uppercase D), which the engine ignores, and the
  visible test window took focus: the hero moved with the user's own typing and the log looked like
  a movement bug. Lesson: lowercase key codes, `vid_hidden 1`, and log positions before concluding.
- **2026-10-29:** `mpqtool cat > file` corrupts binary files (stdout is in text mode, `\n` becomes
  `\r\n`). Lesson: undo the translation or parse in the engine; do not trust a redirected binary.
- **2026-10-29:** After the smoke test passed and the engine log showed the fix (music streaming),
  a second multi-minute screenshot run was started just to watch an idle hero. The user stopped it.
  Lesson: once the smoke test and one engine log line cover a change, stop and hand over for play;
  do not chain screenshot runs to confirm behavior the user will check in seconds.
- **2026-10-29:** The black world was blamed on fog after one run with fog disabled. `r_fog`
  is WoW-only and six later runs with default settings rendered fine: the bug is intermittent.
  Lesson: repeat a run several times and check the cvar is actually read before blaming it.
# Test fast (background runs took WAY too long)

- **Smallest check that covers the change, then stop.** Pure logic/UI: `CompileCheck` + one render
  or the one sim for that area. Gameplay: the one sim for the touched level/kit. Net changes:
- **Run independent checks in one parallel batch** (one background call, `&` + `wait`), never one
  after another; start the slowest first and do other work meanwhile.
- **Don't re-run** a passed check after an unrelated edit; re-run only what the edit touches.
- **Dry runs first** where a tool has one; try variants as dry runs, bake once.
- **No baselines by stash/rebuild** unless a failure is truly unexplained: read the logs first, add a
  temporary print, rerun only the failing case.