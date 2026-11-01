#!/usr/bin/env python3
"""Read files from a local Warcraft III Reforged install (CASC storage).

Read-only, standard library only. Enough of CASC for Reforged's data:
.build.info -> build config -> encoding table (content key -> encoded key)
-> local indices (encoded key -> data.### offset) -> BLTE (raw or zlib).
Reforged's root is a text list of "name|content key|..." lines.

    python tools/reforged_casc.py "<Reforged folder>" list <pattern>
    python tools/reforged_casc.py "<Reforged folder>" cat <name> > out

<pattern> is a case-insensitive regular expression on the CASC names, e.g.
"enus.w3mod:units.*strings". make_english_text.py uses this module.
"""
import pathlib
import re
import struct
import sys
import zlib


class Casc:
    def __init__(self, install):
        self.root_dir = pathlib.Path(install)
        self.data_dir = self.root_dir / "Data"
        info = self._build_info()
        config = self._config(info["Build Key"])
        self.index = self._read_indices()
        self.encoding = self._read_encoding(config["encoding"].split()[1])
        root_ckey = config["root"].split()[0]
        self.names = self._read_root(self._read_ckey(bytes.fromhex(root_ckey)))

    def _build_info(self):
        lines = (self.root_dir / ".build.info").read_text(encoding="utf-8").splitlines()
        header = [h.split("!")[0] for h in lines[0].split("|")]
        for line in lines[1:]:
            row = dict(zip(header, line.split("|")))
            if row.get("Active") == "1":
                return row
        raise SystemExit("no active build in .build.info")

    def _config(self, key):
        path = self.data_dir / "config" / key[0:2] / key[2:4] / key
        config = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if " = " in line and not line.startswith("#"):
                name, value = line.split(" = ", 1)
                config[name] = value
        return config

    def _read_indices(self):
        # One index per bucket (first two hex digits); the highest version wins.
        latest = {}
        for path in (self.data_dir / "data").glob("*.idx"):
            bucket, version = path.stem[:2], int(path.stem[2:], 16)
            if bucket not in latest or version > latest[bucket][0]:
                latest[bucket] = (version, path)
        index = {}
        for _, path in latest.values():
            data = path.read_bytes()
            header_size = struct.unpack_from("<I", data, 0)[0]
            (_version, _bucket, _extra, size_len, offset_len, key_len,
             offset_bits) = struct.unpack_from("<HBBBBBB", data, 8)
            pos = (8 + header_size + 15) & ~15
            entries_len = struct.unpack_from("<I", data, pos)[0]
            pos += 8
            entry = key_len + offset_len + size_len
            for at in range(pos, pos + entries_len - entry + 1, entry):
                key = data[at:at + key_len]
                where = int.from_bytes(data[at + key_len:at + key_len + offset_len], "big")
                size = int.from_bytes(data[at + key_len + offset_len:at + entry], "little")
                index.setdefault(key, (where >> offset_bits, where & ((1 << offset_bits) - 1), size))
        return index

    def _read_ekey(self, ekey):
        found = self.index.get(ekey[:9])
        if found is None:
            raise KeyError("encoded key %s not in the local indices" % ekey.hex())
        archive, offset, size = found
        with open(self.data_dir / "data" / ("data.%03d" % archive), "rb") as f:
            f.seek(offset + 30)  # 30-byte local header: reversed key, size, flags, checksums
            return blte(f.read(size - 30))

    def _read_encoding(self, ekey_hex):
        data = self._read_ekey(bytes.fromhex(ekey_hex))
        if data[:2] != b"EN":
            raise SystemExit("unexpected encoding table header")
        ckey_len, ekey_len = data[3], data[4]
        page_kb = struct.unpack_from(">H", data, 5)[0]
        page_count = struct.unpack_from(">I", data, 9)[0]
        espec_len = struct.unpack_from(">I", data, 18)[0]
        pos = 22 + espec_len + page_count * (ckey_len + 16)
        table = {}
        for page in range(page_count):
            at, end = pos + page * page_kb * 1024, pos + (page + 1) * page_kb * 1024
            while at + 6 + ckey_len <= end:
                count = data[at]
                if count == 0:
                    break
                ckey = data[at + 6:at + 6 + ckey_len]
                table[ckey] = data[at + 6 + ckey_len:at + 6 + ckey_len + ekey_len]
                at += 6 + ckey_len + count * ekey_len
        return table

    def _read_ckey(self, ckey):
        return self._read_ekey(self.encoding[ckey])

    @staticmethod
    def _read_root(data):
        names = {}
        for line in data.decode("utf-8", "replace").splitlines():
            parts = line.split("|")
            if len(parts) >= 2 and re.fullmatch(r"[0-9a-fA-F]{32}", parts[1]):
                names[parts[0].lower()] = bytes.fromhex(parts[1])
        return names

    def find(self, pattern):
        rx = re.compile(pattern, re.I)
        return sorted(name for name in self.names if rx.search(name))

    def read(self, name):
        return self._read_ckey(self.names[name.lower()])


def blte(data):
    if data[:4] != b"BLTE":
        raise ValueError("not a BLTE block")
    header_size = struct.unpack_from(">I", data, 4)[0]
    if header_size == 0:
        return _chunk(data[8:])
    count = int.from_bytes(data[9:12], "big")
    out, at = [], header_size
    for i in range(count):
        comp = struct.unpack_from(">I", data, 12 + i * 24)[0]
        out.append(_chunk(data[at:at + comp]))
        at += comp
    return b"".join(out)


def _chunk(chunk):
    mode = chunk[:1]
    if mode == b"N":
        return chunk[1:]
    if mode == b"Z":
        return zlib.decompress(chunk[1:])
    if mode == b"F":
        return blte(chunk[1:])
    raise ValueError("unsupported BLTE chunk mode %r" % mode)


def main():
    if len(sys.argv) != 4 or sys.argv[2] not in ("list", "cat"):
        raise SystemExit(__doc__)
    casc = Casc(sys.argv[1])
    if sys.argv[2] == "list":
        for name in casc.find(sys.argv[3]):
            print(name)
    else:
        sys.stdout.buffer.write(casc.read(sys.argv[3]))


if __name__ == "__main__":
    main()
