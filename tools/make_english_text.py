#!/usr/bin/env python3
"""Make War3zText.mpq: the game's text in another language, for the engine.

The portable build and the browser data carry the builder's Warcraft III 1.29
archives, so unit names, ability tooltips and menu strings come out in that
install's language (French for the published builds). This copies the same
string files from a Warcraft III Reforged install (any language Reforged
ships) into a small archive. The engine mounts every .mpq in its data folder,
sorted by name, and the last one wins: War3zText.mpq sorts after
War3xLocal.mpq, so its strings replace those. Voices stay as they are
(Reforged's are .ogg, which the engine does not play).

    python tools/make_english_text.py "<Reforged folder>" "<engine Data folder>" [locale]

locale is a Reforged locale folder (default enus; dede, eses, frfr, itit...).
Delete War3zText.mpq to go back. Run it again after a game update.
"""
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from reforged_casc import Casc  # noqa: E402

# The string files the survivor build reads from War3xLocal.mpq
# (tools/web_trace_reads.txt). Layout files (Glue\*.fdf) are left alone:
# Reforged's are for its own interface and their text comes from these.
FILES = [
    r"UI\FrameDef\GlobalStrings.fdf",
    r"UI\FrameDef\InfoPanelStrings.fdf",
    r"UI\WorldEditGameStrings.txt",
    r"UI\WorldEditStrings.txt",
    r"Units\CampaignAbilityStrings.txt",
    r"Units\CampaignUnitStrings.txt",
    r"Units\CampaignUpgradeStrings.txt",
    r"Units\CommandStrings.txt",
    r"Units\CommonAbilityStrings.txt",
    r"Units\HumanAbilityStrings.txt",
    r"Units\HumanUnitStrings.txt",
    r"Units\HumanUpgradeStrings.txt",
    r"Units\ItemAbilityStrings.txt",
    r"Units\ItemStrings.txt",
    r"Units\NeutralAbilityStrings.txt",
    r"Units\NeutralUnitStrings.txt",
    r"Units\NeutralUpgradeStrings.txt",
    r"Units\NightElfAbilityStrings.txt",
    r"Units\NightElfUnitStrings.txt",
    r"Units\NightElfUpgradeStrings.txt",
    r"Units\OrcAbilityStrings.txt",
    r"Units\OrcUnitStrings.txt",
    r"Units\OrcUpgradeStrings.txt",
    r"Units\UndeadAbilityStrings.txt",
    r"Units\UndeadUnitStrings.txt",
    r"Units\UndeadUpgradeStrings.txt",
    r"Units\UnitGlobalStrings.txt",
]
ARCHIVE = "War3zText.mpq"


# ---- MPQ (format 0, uncompressed files) ------------------------------------

def _crypt_table():
    table, seed = [0] * 0x500, 0x00100001
    for i in range(0x100):
        for j in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            high = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[i + j * 0x100] = high | (seed & 0xFFFF)
    return table


CRYPT = _crypt_table()


def mpq_hash(name, kind):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.upper().replace("/", "\\").encode("ascii"):
        seed1 = (CRYPT[(kind << 8) + ch] ^ (seed1 + seed2)) & 0xFFFFFFFF
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def mpq_encrypt(data, key):
    out, seed = [], 0xEEEEEEEE
    for (value,) in struct.iter_unpack("<I", data):
        seed = (seed + CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        out.append(value ^ ((key + seed) & 0xFFFFFFFF))
        key = (((~key << 21) + 0x11111111) | (key >> 11)) & 0xFFFFFFFF
        seed = (value + seed + (seed << 5) + 3) & 0xFFFFFFFF
    return struct.pack("<%dI" % len(out), *out)


def write_mpq(path, files):
    """files: list of (archive name, bytes). Adds a (listfile)."""
    files = list(files) + [("(listfile)", "".join(n + "\r\n" for n, _ in files).encode("ascii"))]
    size = 16
    while size < len(files) * 2:
        size *= 2
    hashes = [(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF, 0xFFFF, 0xFFFFFFFF)] * size
    blocks, body, pos = [], [], 32
    for index, (name, data) in enumerate(files):
        blocks.append((pos, len(data), len(data), 0x80000000))  # MPQ_FILE_EXISTS, stored as is
        body.append(data)
        pos += len(data)
        slot = mpq_hash(name, 0) & (size - 1)
        while hashes[slot][4] != 0xFFFFFFFF:
            slot = (slot + 1) & (size - 1)
        hashes[slot] = (mpq_hash(name, 1), mpq_hash(name, 2), 0, 0, index)
    hash_table = mpq_encrypt(b"".join(struct.pack("<IIHHI", *h) for h in hashes), mpq_hash("(hash table)", 3))
    block_table = mpq_encrypt(b"".join(struct.pack("<IIII", *b) for b in blocks), mpq_hash("(block table)", 3))
    total = pos + len(hash_table) + len(block_table)
    header = struct.pack("<4sIIHHIIII", b"MPQ\x1a", 32, total, 0, 3, pos, pos + len(hash_table), size, len(blocks))
    pathlib.Path(path).write_bytes(header + b"".join(body) + hash_table + block_table)


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    reforged, data_dir = sys.argv[1], pathlib.Path(sys.argv[2])
    locale = sys.argv[3].lower() if len(sys.argv) == 4 else "enus"
    if not (data_dir / "War3xLocal.mpq").is_file():
        raise SystemExit("%s has no War3xLocal.mpq: pass the engine's Data folder" % data_dir)
    casc = Casc(reforged)
    files, missing = [], []
    for name in FILES:
        casc_name = "war3.w3mod:_locales/%s.w3mod:%s" % (locale, name.lower().replace("\\", "/"))
        try:
            files.append((name, casc.read(casc_name)))
        except KeyError:
            missing.append(name)
    if not files:
        raise SystemExit("no %s text in %s" % (locale, reforged))
    out = data_dir / ARCHIVE
    write_mpq(out, files)
    print("%s: %d files (%s)" % (out, len(files), locale))
    for name in missing:
        print("  not in Reforged, kept from the build: " + name)


if __name__ == "__main__":
    main()
