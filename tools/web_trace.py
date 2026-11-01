"""Record the game files Warcraft Survivors reads, for the browser data.

The engine logs every archive read when OPENREALM_FSTRACE names a file
(FS_OpenFile/FS_ReadFileAll in engine/common/common.c; "-" for a file no
archive has). This runs hidden, muted sessions under it:

- every zone (ZONES in src/ashenvale_survivor.lua): its whole enemy roster and
  bosses spawned every 10 s (test_plague.lua, which also keeps the hero alive),
  two heroes (the run's hero and one spawned) and both their spell pools, so
  the 12 runs cover the first 24 heroes and their spells;
- every hero beyond those (Medivh): a run of its own with its whole pool, packs
  that trigger "when surrounded" spells and every world object kind at once
  (test_medivh.lua, survivor_objects all);
- entering every zone from the menu (test_zone_change.lua: its loading screen);
- every lobby tab and options page, the hero model grid, every icon the script
  can show (test_icons.lua, generated), one defeat (end screen).

  python tools/web_trace.py run <trace dir>                 # on the Legacy install
  python tools/web_trace.py reads <trace dir> [more dirs]   # -> tools/web_trace_reads.txt
  python tools/web_trace.py run <dir> --only hero25 icons   # new content only, then:
  python tools/web_trace.py reads --add <dir>               #   added to the current list
  python tools/web_trace.py run <dir2> --data engine/build/web/survivor/data
  python tools/web_trace.py compare <trace dir> <dir2>      # files the trimmed data lost

Each run plays out differently (random spawns, deaths, sound variants): merge
the full and trimmed traces into the list. The reads list (archive, name;
"*" = the highest archive that has it: every zone's music playlist and every
numbered variant of a traced sound) is what port/web/make_survivor_data.py keeps.
Rerun after adding heroes, spells, enemies, zones or UI art.

Runs save to the real profile (the defeat does); it and config.cfg are backed
up first and put back afterwards. Do not play while it runs (about 8 minutes).
"""
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIST = ROOT / "engine" / "dist" / "windows"
LEGACY = r"C:\Program Files (x86)\Warcraft III (Legacy)"
READS = ROOT / "tools" / "web_trace_reads.txt"
LISTFILE = ROOT / "engine" / "tools" / "WarcraftIIIFileListZezulaLadik.txt"
APPDATA = pathlib.Path(os.environ.get("APPDATA", "")) / "warcraft-3"
SAVED = [APPDATA / "CustomMapData" / "WarcraftSurvivors" / "profile.pld", APPDATA / "config.cfg"]
SCRIPTS = "Scripts/Survivor/ashenvale_survivor.lua,Scripts/Survivor/engine_boot.lua"
MENU_MAP = "Maps/FrozenThrone/(6)Moonglade.w3x"


def script_data():
    src = (ROOT / "src" / "ashenvale_survivor.lua").read_text(encoding="utf-8")
    boot = (ROOT / "src" / "engine_boot.lua").read_text(encoding="utf-8")
    heroes_src = src[src.index("local HEROES = {"):src.index("local SPELLS = {}")]
    heroes = [(m.group(1), re.findall(r"'(\w+)'", m.group(2))) for m in
              re.finditer(r"\{id = '(\w{4})', name = .*?pool = \{([^}]*)\}", heroes_src, re.S)]
    zones_src = src[src.index("local ZONES = {"):src.index("local ZONE_ORDER")]
    zones = []
    for block in re.split(r"\n        \{name = ", zones_src)[1:]:
        units = []
        for uid in re.findall(r"id = '(\w{4})'", block):
            if uid not in units:
                units.append(uid)
        zones.append(units)
    maps = {}
    for m in re.finditer(r"\[(\d+)\] = \{map = '((?:[^'\\]|\\.)*)'", boot):
        maps[int(m.group(1))] = re.sub(r"\\(.)", r"\1", m.group(2)).replace("\\", "/")
    music = set()
    for group in re.findall(r"music = \{([^}]*)\}", src):
        music.update(re.findall(r"'(\w+)'", group))
    music.update(re.findall(r"G\.playMusic\(\{'(\w+)'\}\)", src))
    if len(heroes) < 2 * len(zones) or len(maps) != len(zones):
        raise SystemExit("unexpected script layout: %d heroes, %d zones, %d arenas" %
                         (len(heroes), len(zones), len(maps)))
    return heroes, zones, maps, music


ICON_ADDON = DIST / "share" / "warcraft-3" / "Scripts" / "Survivor" / "test_icons.lua"


def write_icon_addon():
    """test_icons.lua (generated, run alone): draws every icon U.icon can return,
    the rawcode's art and the fallback name of each hero, spell, blessing, item,
    talent and perk. The lobby only draws the faction on screen, so a trace of
    it alone misses the others' icons."""
    src = (ROOT / "src" / "ashenvale_survivor.lua").read_text(encoding="utf-8")
    heroes_src = src[src.index("local HEROES = {"):src.index("local SPELLS = {}")]
    codes = set(re.findall(r"\bcode = '(\w{4})'", src)) | set(re.findall(r"\{id = '(\w{4})'", heroes_src))
    names = set(re.findall(r"\bicon = '(\w+)'", src)) | {"BTNSelectHeroOn"}
    for code, name in re.findall(r"U\.icon\('(\w{4})', '(\w+)'\)", src):
        codes.add(code)
        names.add(name)
    lua = """-- Generated by tools/web_trace.py: every icon the script can show, in one grid.
local CODES = {%s}
local NAMES = {%s}
function main()
    InitBlizzard()
    BlzHideOriginFrames(true)
    local game = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
    local paths, seen = {}, {}
    local function add(path)
        if path and path ~= '' and not seen[path] then
            seen[path] = true
            paths[#paths + 1] = path
        end
    end
    for _, code in ipairs(CODES) do
        local ok, result = pcall(BlzGetAbilityIcon, FourCC(code))
        if ok and type(result) == 'string' then
            add(result:match('^[^,]*'))
        end
    end
    for _, name in ipairs(NAMES) do
        add('ReplaceableTextures\\\\CommandButtons\\\\' .. name .. '.blp')
    end
    for i, path in ipairs(paths) do
        local col, row = math.fmod(i - 1, 40), (i - 1) // 40
        local f = BlzCreateFrameByType('BACKDROP', 'TIicon' .. i, game, '', 0)
        BlzFrameSetAbsPoint(f, FRAMEPOINT_TOPLEFT, -0.1 + col * 0.025, 0.59 - row * 0.025)
        BlzFrameSetSize(f, 0.024, 0.024)
        BlzFrameSetTexture(f, path, 0, true)
    end
    print('ICONS ' .. #paths)
end
""" % (", ".join("'%s'" % c for c in sorted(codes)), ", ".join("'%s'" % n for n in sorted(names)))
    ICON_ADDON.write_text(lua, encoding="utf-8")


def plan(data, seconds):
    heroes, zones, maps, _ = script_data()
    common = ["-data", data, "-tft", "+set", "vid_hidden", "1", "+set", "s_volume", "0",
              "+set", "com_maxfps", "30", "+set", "com_maxfps_background", "30",
              "+set", "survivor_autopick", "1"]
    half = len(zones)
    runs = []
    for z in range(1, half + 1):
        _, pool = heroes[z - 1]
        other_id, other_pool = heroes[z + half - 1]
        runs.append(("zone%02d" % z, seconds, common + [
            "+set", "wc3_lua_script", SCRIPTS + ",Scripts/Survivor/test_plague.lua",
            "+set", "survivor_run", "%d %d 1 2" % (z, z),
            "+set", "survivor_spells", " ".join(pool + other_pool),
            "+set", "plague_units", " ".join(zones[z - 1] + [other_id]),
            "+set", "plague_len", "9999", "+set", "plague_move", "1", "+map", maps[z]]))
    # Heroes beyond two per zone (Medivh, a plain unit test_plague.lua would not
    # heal): their own run with the whole pool, packs that trigger "when
    # surrounded" spells, and every world object kind at once.
    src = (ROOT / "src" / "ashenvale_survivor.lua").read_text(encoding="utf-8")
    for index in range(2 * half + 1, len(heroes) + 1):
        hero_id, pool = heroes[index - 1]
        # Every unit its summons can call (higher ranks call other types).
        summoned = []
        for key in pool:
            m = re.search(r"spell\('%s', \{[^}]*?units = \{([^}]*)\}" % key, src, re.S)
            for uid in re.findall(r"'(\w{4})'", m.group(1)) if m else []:
                if uid not in summoned:
                    summoned.append(uid)
        runs.append(("hero%02d" % index, seconds, common + [
            "+set", "medivh_spawn", " ".join(summoned),
            "+set", "wc3_lua_script", SCRIPTS + ",Scripts/Survivor/test_medivh.lua",
            "+set", "survivor_run", "%d 1 1 2" % index,
            "+set", "survivor_spells", " ".join(pool),
            "+set", "survivor_objects", "all",
            "+set", "medivh_hero", hero_id, "+set", "medivh_len", "9999", "+map", maps[1]]))
    # Entering each zone from the menu, as the lobby does: its loading screen.
    for z in range(1, half + 1):
        runs.append(("enter%02d" % z, 30, common + [
            "+set", "wc3_lua_script", SCRIPTS + ",Scripts/Survivor/test_zone_change.lua",
            "+set", "zone_change", "%d %d 1 2" % (z, z), "+map", MENU_MAP]))
    menu = common + ["+set", "wc3_loading_quiet", "1"]
    for tab in ("character", "collection", "codex", "talents", "achievements", "rewards"):
        runs.append(("tab_" + tab, 40, menu + ["+set", "wc3_lua_script", SCRIPTS,
                                               "+set", "survivor_tab", tab, "+map", MENU_MAP]))
    for page in ("main", "audio", "keys", "interface", "difficulty"):
        runs.append(("menu_" + page, 40, menu + ["+set", "wc3_lua_script", SCRIPTS,
                                                 "+set", "survivor_menu", page, "+map", MENU_MAP]))
    runs.append(("models", 40, common + ["+set", "wc3_lua_script", "Scripts/Survivor/test_models.lua",
                                         "+map", MENU_MAP]))
    runs.append(("icons", 40, common + ["+set", "wc3_lua_script", "Scripts/Survivor/test_icons.lua",
                                        "+map", MENU_MAP]))
    runs.append(("defeat", 40, common + [
        "+set", "wc3_lua_script", SCRIPTS + ",Scripts/Survivor/test_defeat.lua",
        "+set", "survivor_run", "%d 1 1 2" % (half + 1), "+map", maps[1]]))
    return runs


def run(args):
    out = pathlib.Path(args.dir).resolve()  # The engine runs from DIST: absolute paths only.
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.trace"):
        old.unlink()
    backup = out / "saved"
    backup.mkdir(exist_ok=True)
    for path in SAVED:
        if path.is_file():
            shutil.copy2(path, backup / path.name)
    write_icon_addon()
    pending = [r for r in plan(str(pathlib.Path(args.data).resolve()), args.seconds)
               if not args.only or r[0] in args.only]
    active = []
    try:
        while pending or active:
            while pending and len(active) < args.parallel:
                name, seconds, cmd = pending.pop(0)
                env = dict(os.environ, OPENREALM_FSTRACE=str(out / (name + ".trace")))
                log = open(out / (name + ".log"), "w")
                proc = subprocess.Popen([str(DIST / "openwarcraft3.exe")] + cmd, cwd=DIST, env=env,
                                        stdout=log, stderr=subprocess.STDOUT)
                active.append((name, time.time() + seconds, proc, log))
                print("start", name, flush=True)
            time.sleep(2)
            for item in list(active):
                name, deadline, proc, log = item
                if proc.poll() is None and time.time() < deadline:
                    continue
                # Killed, not quit: a clean exit would archive the test cvars into config.cfg.
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                log.close()
                active.remove(item)
                if not (out / (name + ".trace")).is_file():
                    raise SystemExit("no trace from " + name + ": see " + str(out / (name + ".log")))
                print("done", name, flush=True)
    finally:
        for _, _, proc, log in active:
            proc.kill()
            log.close()
        for path in SAVED:
            saved = backup / path.name
            if saved.is_file() and path.read_bytes() != saved.read_bytes():
                shutil.copy2(saved, path)
                print("restored", path, flush=True)


def load(directory):
    reads, misses = set(), set()
    for trace in pathlib.Path(directory).glob("*.trace"):
        for line in trace.read_text(encoding="latin-1").splitlines():
            archive, _, name = line.partition("\t")
            name = name.replace("/", "\\")
            if archive == "-":
                misses.add(name.upper())
            elif not re.match(r"^[a-z]\.mpq\\", name, re.I):  # Inside a tileset archive, kept whole.
                reads.add((pathlib.PureWindowsPath(archive).name, name))
    return reads, misses


def listfile():
    return {line.strip().replace("/", "\\") for line in
            LISTFILE.read_text(encoding="latin-1").splitlines() if line.strip()}


def sound_variants(names, listed):
    """Every numbered sibling of a traced sound (Hit1.wav -> Hit2.wav, Hit3.wav...):
    the game picks one at random, so one trace never hears them all."""
    stems = set()
    for name in names:
        m = re.match(r"^(.*?)\d+\.(wav|mp3)$", name, re.I)
        if m:
            stems.add(m.group(1).upper())
    found = set()
    for name in listed:
        m = re.match(r"^(.*?)\d+\.(wav|mp3)$", name, re.I)
        if m and m.group(1).upper() in stems:
            found.add(name)
    return found


def reads(args):
    found, misses = set(), set()
    for directory in args.dirs:
        dir_reads, dir_misses = load(directory)
        found |= dir_reads
        misses |= dir_misses
    lines = {"%s\t%s" % r for r in found}
    known = {name.upper() for _, name in found}
    if args.add and READS.is_file():
        # Only the new sessions were traced (run --only): keep the list's
        # earlier files (known, so not listed twice) and add these traces'.
        for line in READS.read_text(encoding="utf-8").splitlines():
            if line.strip():
                lines.add(line)
                known.add(line.partition("\t")[2].upper())
    listed = listfile()
    # A trimmed-data trace misses what the trim lost. Most misses are probes for
    # files that exist nowhere (.mdl before .mdx): keep only listed names.
    upper = {name.upper(): name for name in listed}
    lines.update("*\t" + upper[name] for name in misses if name in upper and name not in known)
    lines.update("*\t" + name for name in sound_variants(known, listed) if name.upper() not in known)
    lines.update("*\tSound\\Music\\mp3Music\\%s.mp3" % m for m in script_data()[3])
    # Every asset path written out in the script (effects, banners, loading art).
    src = (ROOT / "src" / "ashenvale_survivor.lua").read_text(encoding="utf-8")
    for raw in re.findall(r"'((?:[^'\\\n]|\\\\)+\.(?:blp|mdx|mdl|wav|mp3|tga))'", src, re.I):
        name = raw.replace("\\\\", "\\")
        for candidate in (name.upper(), re.sub(r"\.MDL$", ".MDX", name.upper())):
            if candidate in upper and candidate not in known:
                lines.add("*\t" + upper[candidate])
    READS.write_text("".join(l + "\n" for l in sorted(lines, key=lambda l: (l.lower(), l))), encoding="utf-8")
    print("%d files -> %s" % (len(lines), READS))


def compare(args):
    full_reads, full_misses = load(args.full)
    trimmed_reads, trimmed_misses = load(args.trimmed)
    # Map\file names are probes of the map archive before the base data: they miss
    # on the install too, whenever that file was opened at all.
    lost = sorted(n for n in trimmed_misses - full_misses if not re.search(r"\.W3[MX]\\", n))
    print("%d files missing from the trimmed data that the install has" % len(lost))
    for name in lost:
        print("  " + name)
    # A dropped copy can also fall through to a lower archive's older one.
    source = {}
    for archive, name in full_reads:
        source.setdefault(name.upper(), set()).add(archive.lower())
    moved = sorted("%s (%s)" % (name, archive) for archive, name in trimmed_reads
                   if name.upper() in source and archive.lower() not in source[name.upper()])
    print("%d files read from another archive than on the install" % len(moved))
    for line in moved:
        print("  " + line)
    return 1 if lost or moved else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("run")
    p.add_argument("dir")
    p.add_argument("--data", default=LEGACY)
    p.add_argument("--seconds", type=int, default=160, help="per zone (bosses come at 120 s)")
    p.add_argument("--parallel", type=int, default=6)
    p.add_argument("--only", nargs="*", help="run only these sessions (zone01, tab_codex, icons...)")
    p = sub.add_parser("reads")
    p.add_argument("dirs", nargs="+", help="trace dirs (merged: each run plays out differently)")
    p.add_argument("--add", action="store_true", help="keep the current list and add these traces' files")
    p = sub.add_parser("compare")
    p.add_argument("full")
    p.add_argument("trimmed")
    args = parser.parse_args()
    sys.exit({"run": run, "reads": reads, "compare": compare}[args.cmd](args))


if __name__ == "__main__":
    main()
