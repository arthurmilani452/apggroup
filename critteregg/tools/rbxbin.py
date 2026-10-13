"""Minimal Roblox binary place (.rbxl) reader/writer.

Reads every chunk, decodes INST/PRNT and the String-typed PROP chunks we need
(Name, Source), and can write the file back with chosen Source values replaced
and new script instances appended. Every other chunk is kept byte-for-byte.
"""
import struct
import lz4.block
import zstandard

MAGIC = b"<roblox!\x89\xff\x0d\x0a\x1a\x0a"


def _dec_chunk(raw_header, data):
    name, clen, ulen, _ = raw_header
    if clen == 0:
        return data
    if data[:4] == b"\x28\xb5\x2f\xfd":
        return zstandard.ZstdDecompressor().decompress(data, max_output_size=ulen)
    return lz4.block.decompress(data, uncompressed_size=ulen)


class Chunk:
    def __init__(self, name, payload, raw=None):
        self.name = name
        self.payload = payload  # uncompressed bytes
        self.raw = raw  # original header+data bytes (kept when unchanged)
        self.dirty = False

    def encode(self):
        if self.raw is not None and not self.dirty:
            return self.raw
        if self.name == b"END\0":
            return self.name + struct.pack("<III", 0, len(self.payload), 0) + self.payload
        comp = lz4.block.compress(self.payload, store_size=False)
        return self.name + struct.pack("<III", len(comp), len(self.payload), 0) + comp


def read_place(path):
    blob = open(path, "rb").read()
    assert blob[:14] == MAGIC, "not a binary place"
    version, class_count, inst_count = struct.unpack_from("<Hii", blob, 14)
    pos = 32
    chunks = []
    while pos < len(blob):
        name = blob[pos:pos + 4]
        clen, ulen, res = struct.unpack_from("<III", blob, pos + 4)
        size = clen if clen else ulen
        data = blob[pos + 16:pos + 16 + size]
        raw = blob[pos:pos + 16 + size]
        payload = _dec_chunk((name, clen, ulen, res), data)
        chunks.append(Chunk(name, payload, raw))
        pos += 16 + size
        if name == b"END\0":
            break
    return {"header": blob[:32], "class_count": class_count, "inst_count": inst_count, "chunks": chunks, "tail": blob[pos:]}


# ---------- primitive codecs ----------

def deinterleave(buf, count, width=4):
    out = []
    for i in range(count):
        out.append(bytes(buf[j * count + i] for j in range(width)))
    return out


def interleave(values, width=4):
    count = len(values)
    out = bytearray(count * width)
    for i, v in enumerate(values):
        for j in range(width):
            out[j * count + i] = v[j]
    return bytes(out)


def unzig32(b):
    x = struct.unpack(">I", b)[0]
    return (x >> 1) ^ -(x & 1)


def zig32(v):
    return struct.pack(">I", ((v << 1) ^ (v >> 31)) & 0xFFFFFFFF)


def read_refs(buf, pos, count):
    vals = [unzig32(b) for b in deinterleave(buf[pos:pos + count * 4], count)]
    acc, out = 0, []
    for v in vals:
        acc += v
        out.append(acc)
    return out, pos + count * 4


def write_refs(refs):
    prev, deltas = 0, []
    for r in refs:
        deltas.append(zig32(r - prev))
        prev = r
    return interleave(deltas)


def read_string(buf, pos):
    n = struct.unpack_from("<I", buf, pos)[0]
    return bytes(buf[pos + 4:pos + 4 + n]), pos + 4 + n


# ---------- chunk decoders ----------

def parse_inst(payload):
    class_id, = struct.unpack_from("<I", payload, 0)
    cname, pos = read_string(payload, 4)
    is_service = payload[pos]
    count, = struct.unpack_from("<I", payload, pos + 1)
    refs, pos = read_refs(payload, pos + 5, count)
    return {"class_id": class_id, "class": cname.decode(), "is_service": is_service, "refs": refs, "service_markers": payload[pos:pos + count] if is_service else b""}


def build_inst(info):
    out = struct.pack("<I", info["class_id"])
    c = info["class"].encode()
    out += struct.pack("<I", len(c)) + c
    out += bytes([info["is_service"]]) + struct.pack("<I", len(info["refs"]))
    out += write_refs(info["refs"])
    if info["is_service"]:
        out += info["service_markers"]
    return out


def prop_header(payload):
    class_id, = struct.unpack_from("<I", payload, 0)
    pname, pos = read_string(payload, 4)
    type_id = payload[pos]
    return class_id, pname.decode(), type_id, pos + 1


def parse_strings(payload, pos, count):
    vals = []
    for _ in range(count):
        s, pos = read_string(payload, pos)
        vals.append(s)
    return vals


def build_string_prop(class_id, pname, type_id, values):
    p = pname.encode()
    out = struct.pack("<I", class_id) + struct.pack("<I", len(p)) + p + bytes([type_id])
    for v in values:
        out += struct.pack("<I", len(v)) + v
    return out


def parse_prnt(payload):
    count, = struct.unpack_from("<I", payload, 1)
    children, pos = read_refs(payload, 5, count)
    parents, pos = read_refs(payload, pos, count)
    return children, parents


def build_prnt(children, parents):
    return bytes([0]) + struct.pack("<I", len(children)) + write_refs(children) + write_refs(parents)


class Place:
    def __init__(self, path):
        self.doc = read_place(path)
        self.classes = {}  # class_id -> inst info
        self.inst_chunk = {}
        self.prop_chunks = {}  # (class_id, prop) -> chunk
        for ch in self.doc["chunks"]:
            if ch.name == b"INST":
                info = parse_inst(ch.payload)
                self.classes[info["class_id"]] = info
                self.inst_chunk[info["class_id"]] = ch
            elif ch.name == b"PROP":
                cid, pname, tid, _ = prop_header(ch.payload)
                self.prop_chunks[(cid, pname)] = ch
            elif ch.name == b"PRNT":
                self.prnt_chunk = ch
        self.ref_class = {}
        self.ref_index = {}
        for cid, info in self.classes.items():
            for i, r in enumerate(info["refs"]):
                self.ref_class[r] = cid
                self.ref_index[r] = i
        children, parents = parse_prnt(self.prnt_chunk.payload)
        self.parent = dict(zip(children, parents))
        self.children = {}
        for c, p in zip(children, parents):
            self.children.setdefault(p, []).append(c)
        self._strings = {}

    def strings(self, class_id, prop):
        key = (class_id, prop)
        if key not in self._strings:
            ch = self.prop_chunks.get(key)
            if ch is None:
                return None
            cid, pname, tid, pos = prop_header(ch.payload)
            assert tid in (0x01,), f"{prop} type {tid} is not String"
            self._strings[key] = (tid, parse_strings(ch.payload, pos, len(self.classes[class_id]["refs"])))
        return self._strings[key][1]

    def class_of(self, ref):
        return self.classes[self.ref_class[ref]]["class"]

    def name_of(self, ref):
        cid = self.ref_class[ref]
        names = self.strings(cid, "Name")
        return names[self.ref_index[ref]].decode("utf-8", "replace") if names else "?"

    def path_of(self, ref):
        parts = []
        r = ref
        while r is not None and r != -1:
            parts.append(self.name_of(r))
            r = self.parent.get(r)
        return list(reversed(parts))

    def roots(self):
        return [c for c, p in self.parent.items() if p == -1]

    def set_source(self, ref, text):
        cid = self.ref_class[ref]
        vals = self.strings(cid, "Source")
        vals[self.ref_index[ref]] = text.encode("utf-8")
        tid = self._strings[(cid, "Source")][0]
        ch = self.prop_chunks[(cid, "Source")]
        ch.payload = build_string_prop(cid, "Source", tid, vals)
        ch.dirty = True

    def write(self, path):
        out = bytearray(self.doc["header"])
        for ch in self.doc["chunks"]:
            out += ch.encode()
        out += self.doc["tail"]
        open(path, "wb").write(bytes(out))
