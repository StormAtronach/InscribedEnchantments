# Generates the glyph frame textures and template meshes for Inscribed Enchantments.
#
#   python tools/generate_rune_sets.py "<mod root>" ["<font dir>"]
#
# Output (all under <mod root>):
#   Textures/ie/<colour>/runeNNN.tga    normal glyph set   (192 RLE TGA frames)
#   Textures/ie/<colour>s/runeNNN.tga   small glyph set
#   Textures/ie/<colour>x/runeNNN.tga   sparse normal set (fewer glyphs, no resting glow, shorter events)
#   Textures/ie/<colour>xs/runeNNN.tga  sparse small set
#   Textures/ie/<colour>c/runeNNN.tga   cracks set (glowing crack network instead of glyphs)
#   Meshes/ie/<colour><suffix>.nif      template meshes (flip controller + animated node)
#
# An optional third argument limits the run to some sets, e.g. "c" or "x,xs"; the other sets'
# folders are then left alone.
#
# Glyph source: hardek's "Better Daedric Font" (Aligned+XY variant), based on Dongle's Oblivion Worn
# font; redistributable with credit and the accompanying text file (tools/font/, licence at mod root).
# Default font dir: tools/font next to this script.
#
# History:
#   0.2 cracks (2026-08-29): crack-network set; light flows from each crack's root to its tip.
#   0.2 sparse sets (2026-08-29): sparse variants of both sizes (per-set floor, event width, two-event chance).
#   iter 7 (2026-08-29): Better Daedric Font (256 px, anti-aliased, 52 letters); two glyph sizes.
#   iter 4 (2026-08-29): 192-frame loop as TGA (DXT1 steps visibly, 24-bit DDS renders white).
#   iter 3/2/1: layout and curve iterations on the vanilla 128 px font.
import sys, os, math, random, struct, shutil
import numpy as np
from PIL import Image, ImageFilter

root = sys.argv[1]
font_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "font")
only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else None
tex_out = os.path.join(root, "Textures", "ie")
mesh_out = os.path.join(root, "Meshes", "ie")

# --- tunables ---------------------------------------------------------------------------------
N = 192                # frames per loop (must match FRAMES in glow.lua)
FPS = 12.0             # frame rate of the template controllers at frequency 1 (BASE_FPS in glow.lua)
SIZE = 128             # default tile size in pixels (a set may override it with size=...)
PEAK = (0.35, 0.60)    # peak brightness range per glyph (1.0 = full colour); a set may override with peak=...
HALO_BLUR, HALO_GAIN = 3.0, 0.30   # faint wide glow around each glyph; a set may override the gain with halo=...
SEED = 11
# Glyph sets: folder suffix -> glyph count, scale range applied to the source glyphs (27-34 px tall),
# exclusion margin, edge blur, resting glow (fraction of colour), event width (fraction of the loop
# one event spans; gaussian, full width ~ 2x this), chance of a second event per loop.
# "" normal, "s" small, "x" sparse normal, "xs" sparse small. The sparse sets keep the glyph size
# of their parent set, place fewer glyphs, have no resting glow and light up for shorter windows.
# "c" (kind="cracks") draws a tileable crack network instead of glyphs: seeds = main cracks,
# length = walk budget in px, wobble = heading drift per px (rad), kink = chance per px of a sharp
# turn, branch = fork chance per px, flow = fraction of the loop the light takes to travel from a
# crack's root to its tip.
SETS = {
    "":   dict(glyphs=14, scale=(0.55, 0.65), pad=6,  blur=0.5, floor=0.05, event=0.22, two=0.3),
    "s":  dict(glyphs=20, scale=(0.36, 0.42), pad=4,  blur=0.3, floor=0.05, event=0.22, two=0.3),
    "x":  dict(glyphs=8,  scale=(0.55, 0.65), pad=10, blur=0.5, floor=0.0,  event=0.15, two=0.1),
    "xs": dict(glyphs=10, scale=(0.36, 0.42), pad=8,  blur=0.3, floor=0.0,  event=0.15, two=0.1),
    # peak and halo override PEAK and HALO_GAIN. The glow map is added onto the lit surface
    # colour as-is (D3DTOP_ADD, gamma space), so on a dark surface a line at 0.2 is two to three
    # times its surroundings and reads as a lit filament; cracks need a fraction of the glyph
    # values to read as a glimmer.
    "c":  dict(kind="cracks", seeds=5, length=80, wobble=0.06, kink=0.05, branch=0.025,
               blur=0.6, floor=0.0, event=0.25, two=0.2, flow=0.12, peak=(0.07, 0.14), halo=0.10),
    # Same style at twice the resolution: per-pixel rates scaled so the shape per texture
    # repeat stays the same (length x2, kink/branch /2, wobble /sqrt 2), core 2 px wide.
    "ch": dict(kind="cracks", size=256, width=2, seeds=5, length=160, wobble=0.042, kink=0.025, branch=0.0125,
               blur=0.8, floor=0.0, event=0.25, two=0.2, flow=0.12, peak=(0.07, 0.14), halo=0.10),
}
palette = {"ember": (253, 66, 136), "blood": (198, 57, 65), "rose": (244, 185, 223), "lilac": (176, 174, 255), "azure": (0, 124, 217),
           "violet": (152, 36, 168), "mint": (166, 255, 224), "moss": (128, 192, 128), "lime": (202, 228, 97), "ivory": (255, 255, 223),
           "white": (255, 255, 255)}   # hues follow the clusters in the vanilla MGEF lighting colours; must match PALETTE in glow.lua

# --- font glyphs -------------------------------------------------------------------------------
fnt = open(os.path.join(font_dir, "daedric_font.fnt"), "rb").read()
tex_name = fnt[12:296].split(b"\0")[0].decode("latin-1")            # texture base name stored in the header
tex = open(os.path.join(font_dir, tex_name + ".tex"), "rb").read()
W, H = struct.unpack_from("<II", tex, 0)
img = np.frombuffer(tex, np.uint8, W * H * 4, 8).reshape(H, W, 4)
mask = img[:, :, 3].astype(np.float32)
# .fnt: 296-byte header, then 256 records of 14 floats:
# [unknown, tl.x, tl.y, tr.x, tr.y, bl.x, bl.y, br.x, br.y, width, height, u, v, ascent]
glyphs = {}
for code in range(256):
    v = struct.unpack_from("<14f", fnt, 296 + code * 56)
    tlx, tly, brx, bry, w, h = v[1], v[2], v[7], v[8], v[9], v[10]
    if w <= 0 or h <= 0:
        continue
    x0, y0 = int(round(tlx * W)), int(round(tly * H)); x1, y1 = int(round(brx * W)), int(round(bry * H))
    if x1 <= x0 or y1 <= y0:
        continue
    crop = mask[y0:y1, x0:x1]
    ys = np.where(crop.max(axis=1) > 0)[0]; xs = np.where(crop.max(axis=0) > 0)[0]
    if len(ys) == 0:
        continue
    crop = crop[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1]
    glyphs[code] = crop / crop.max()
# Upper and lower case are the same glyphs in this font; keep one of each.
pool = [glyphs[c] for c in glyphs if chr(c).isupper()]
print("font %s: %dx%d, %d letter glyphs, %d-%d px tall" % (tex_name, W, H, len(pool), min(g.shape[0] for g in pool), max(g.shape[0] for g in pool)))


def rescale(g, f):
    im = Image.fromarray((g * 255).astype(np.uint8))
    im = im.resize((max(1, int(round(g.shape[1] * f))), max(1, int(round(g.shape[0] * f)))), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255


def envelope(t, centre, width):
    d = (t - centre + 0.5) % 1.0 - 0.5          # wrapped distance in loop fraction
    return math.exp(-0.5 * (d / (width / 2.0)) ** 2)


def build_frames(cfg):
    random.seed(SEED)
    size = cfg.get("size", SIZE)
    placed = []; occupied = np.zeros((size, size), bool); tries = 0
    while len(placed) < cfg["glyphs"] and tries < 8000:
        tries += 1
        g = rescale(random.choice(pool), random.uniform(*cfg["scale"]))
        h, w = g.shape
        if w >= size - 2 or h >= size - 2:
            continue
        x = random.randrange(0, size - w); y = random.randrange(0, size - h); pad = cfg["pad"]
        y0, y1, x0, x1 = max(0, y - pad), min(size, y + h + pad), max(0, x - pad), min(size, x + w + pad)
        if occupied[y0:y1, x0:x1].any():
            continue
        occupied[y0:y1, x0:x1] = True
        centres = [random.random()]
        if random.random() < cfg["two"]:
            centres.append((centres[0] + random.uniform(0.35, 0.65)) % 1.0)
        placed.append((g, x, y, centres, random.uniform(*cfg.get("peak", PEAK))))
    frames = []
    floor, width = cfg["floor"], cfg["event"]
    for k in range(N):
        canvas = np.zeros((size, size), np.float32); t = k / N
        for g, x, y, centres, peak in placed:
            b = floor + (peak - floor) * max(envelope(t, c, width) for c in centres)
            if b < 0.004:
                continue
            h, w = g.shape; canvas[y:y + h, x:x + w] = np.maximum(canvas[y:y + h, x:x + w], g * b)
        im = Image.fromarray(np.clip(canvas * 255, 0, 255).astype(np.uint8))
        core = im.filter(ImageFilter.GaussianBlur(cfg["blur"])) if cfg["blur"] > 0 else im
        halo = im.filter(ImageFilter.GaussianBlur(HALO_BLUR * size / SIZE)).point(lambda v: int(v * cfg.get("halo", HALO_GAIN)))
        frames.append(np.maximum(np.asarray(core), np.asarray(halo)))
    return placed, frames


# --- crack network -----------------------------------------------------------------------------
def build_crack_tile(cfg):
    """Random walks with wrap-around (the tile repeats with the base texture). Returns the crack
    mask, each crack pixel's position along its crack (0 root .. 1 tip), the crack id per pixel and
    the number of cracks."""
    random.seed(SEED)
    size = cfg.get("size", SIZE)
    mask = np.zeros((size, size), np.float32)
    arc = np.zeros((size, size), np.float32)
    cid = np.full((size, size), -1, np.int32)
    budget = [cfg["length"] * random.uniform(0.6, 1.4) for _ in range(cfg["seeds"])]
    # Seeds on a jittered grid so the cracks cover the tile instead of clustering.
    grid = int(math.ceil(math.sqrt(cfg["seeds"])))
    cells = random.sample([(i, j) for i in range(grid) for j in range(grid)], cfg["seeds"])
    walks = [((i + random.uniform(0.2, 0.8)) * size / grid, (j + random.uniform(0.2, 0.8)) * size / grid,
              random.uniform(0, 2 * math.pi), k) for k, (i, j) in enumerate(cells)]   # x, y, heading, crack id
    while walks:
        x, y, a, k = walks.pop()
        d = 0.0
        while d < budget[k]:
            a += random.gauss(0, cfg["wobble"])
            if random.random() < cfg["kink"]:
                a += random.choice((-1, 1)) * random.uniform(0.4, 0.9)
            x = (x + math.cos(a)) % size
            y = (y + math.sin(a)) % size
            ix, iy = int(x), int(y)
            if cid[iy, ix] not in (-1, k):          # ran into another crack: join it and stop
                break
            mask[iy, ix] = 1.0
            cid[iy, ix] = k
            arc[iy, ix] = d
            d += 1.0
            if d > 8 and random.random() < cfg["branch"]:
                budget.append(budget[k] * random.uniform(0.3, 0.6))
                walks.append((x, y, a + random.choice((-1, 1)) * random.uniform(0.5, 1.1), len(budget) - 1))
    lengths = np.ones(len(budget), np.float32)
    for k in range(len(budget)):
        sel = cid == k
        if sel.any():
            lengths[k] = arc[sel].max() + 1
    arc = np.where(cid >= 0, arc / lengths[np.maximum(cid, 0)], 0)
    # Widen the core to cfg["width"] pixels (wrapping), carrying id and position along with it.
    for _ in range(cfg.get("width", 1) - 1):
        for axis in (0, 1):
            shifted_cid, shifted_arc = np.roll(cid, 1, axis), np.roll(arc, 1, axis)
            grow = (cid < 0) & (shifted_cid >= 0)
            cid = np.where(grow, shifted_cid, cid)
            arc = np.where(grow, shifted_arc, arc)
            mask = np.where(grow, 1.0, mask)
    return mask, arc, cid, len(budget)


def build_crack_frames(cfg):
    """Each crack gets the same event windows as a glyph, delayed along the crack by `flow`, so the
    light runs from the root to the tip and fades back."""
    mask, arc, cid, count = build_crack_tile(cfg)
    events = []
    for _ in range(count):
        centres = [random.random()]
        if random.random() < cfg["two"]:
            centres.append((centres[0] + random.uniform(0.35, 0.65)) % 1.0)
        events.append((centres, random.uniform(*cfg.get("peak", PEAK))))
    floor, width = cfg["floor"], cfg["event"]
    size = cfg.get("size", SIZE)
    frames = []
    for f in range(N):
        t = f / N
        bright = np.zeros((size, size), np.float32)
        for k, (centres, peak) in enumerate(events):
            sel = cid == k
            if not sel.any():
                continue
            local_t = t - arc[sel] * cfg["flow"]
            env = np.max([np.exp(-0.5 * ((((local_t - c + 0.5) % 1.0) - 0.5) / (width / 2.0)) ** 2)
                          for c in centres], axis=0)
            bright[sel] = floor + (peak - floor) * env
        im = Image.fromarray(np.clip(mask * bright * 255, 0, 255).astype(np.uint8))
        core = im.filter(ImageFilter.GaussianBlur(cfg["blur"]))
        halo = im.filter(ImageFilter.GaussianBlur(HALO_BLUR * size / SIZE)).point(lambda v: int(v * cfg.get("halo", HALO_GAIN)))
        frames.append(np.maximum(np.asarray(core), np.asarray(halo)))
    return count, int(mask.sum()), frames


# --- template NIF writer -----------------------------------------------------------------------
class NifWriter:
    def __init__(self):
        self.blocks = []
    def u8(self, v): return struct.pack("<B", v)
    def u16(self, v): return struct.pack("<H", v)
    def u32(self, v): return struct.pack("<I", v)
    def i32(self, v): return struct.pack("<i", v)
    def f32(self, v): return struct.pack("<f", v)
    def bool4(self, v): return struct.pack("<I", 1 if v else 0)   # bools are 4 bytes in 4.0.0.2
    def string(self, s):
        b = s.encode("latin-1"); return struct.pack("<I", len(b)) + b
    def vec3(self, x, y, z): return struct.pack("<3f", x, y, z)
    def objectNET(self, name, extra=-1, controller=-1):
        return self.string(name) + self.i32(extra) + self.i32(controller)
    def avObject(self, name, props, controller=-1, flags=0):
        b = self.objectNET(name, -1, controller)
        b += self.u16(flags) + self.vec3(0, 0, 0)
        b += struct.pack("<9f", 1, 0, 0, 0, 1, 0, 0, 0, 1) + self.f32(1.0) + self.vec3(0, 0, 0)
        b += self.u32(len(props)) + b"".join(self.i32(p) for p in props)
        b += self.bool4(False)   # no bounding volume
        return b
    def add(self, typename, body):
        self.blocks.append(self.string(typename) + body); return len(self.blocks) - 1
    def texDesc(self, source, clamp=3, filt=2, uv=0):
        return self.i32(source) + self.u32(clamp) + self.u32(filt) + self.u32(uv) + struct.pack("<hh", 0, -75) + self.u8(0) + self.u8(0)
    def write(self, path, roots):
        with open(path, "wb") as f:
            f.write(b"NetImmerse File Format, Version 4.0.0.2\n" + self.u32(0x04000002) + self.u32(len(self.blocks)))
            for b in self.blocks:
                f.write(b)
            f.write(self.u32(len(roots)) + b"".join(self.i32(r) for r in roots))


def write_template(path, folder):
    # Block order: 0 root, 1 shape, 2 data, 3 texturing property, 4 flip controller,
    # 5 IE_anim (NiBSAnimationNode), 6 its NiVisController, 7 NiVisData, 8.. textures.
    w = NifWriter()
    ROOT, SHAPE, DATA, PROP, CTRL, ANIM, VIS, VISDATA, TEX0 = 0, 1, 2, 3, 4, 5, 6, 7, 8
    tex_ids = [TEX0 + k for k in range(N)]
    w.add("NiNode", w.avObject("InscribedEnchantments", []) + w.u32(2) + w.i32(SHAPE) + w.i32(ANIM) + w.u32(0))
    w.add("NiTriShape", w.avObject("glyphs", [PROP]) + w.i32(DATA) + w.i32(-1))
    verts = [(0, 0, 0), (1, 0, 0), (0, 1, 0)]
    data = w.u16(3) + w.bool4(True) + b"".join(w.vec3(*v) for v in verts)
    data += w.bool4(True) + b"".join(w.vec3(0, 0, 1) for _ in verts)
    data += w.vec3(0.33, 0.33, 0) + w.f32(1.0) + w.bool4(False)
    data += w.u16(1) + w.bool4(True) + b"".join(struct.pack("<2f", u, v) for u, v in [(0, 0), (1, 0), (0, 1)])
    data += w.u16(1) + w.u32(3) + struct.pack("<3H", 0, 1, 2) + w.u16(0)
    w.add("NiTriShapeData", data)
    prop = w.objectNET("", -1, CTRL) + w.u16(0) + w.u32(2) + w.u32(7)
    prop += w.bool4(True) + w.texDesc(tex_ids[0])            # base
    prop += w.bool4(False) + w.bool4(False) + w.bool4(False)   # dark, detail, gloss
    prop += w.bool4(True) + w.texDesc(tex_ids[0])            # glow
    prop += w.bool4(False) + w.bool4(False)                  # bump, decal 0
    w.add("NiTexturingProperty", prop)
    loop_seconds = N / FPS
    ctrl = w.i32(-1) + w.u16(0x0008) + w.f32(1.0) + w.f32(0.0) + w.f32(0.0) + w.f32(loop_seconds) + w.i32(PROP)
    ctrl += w.u32(4) + w.f32(0.0) + w.f32(1.0 / FPS) + w.u32(N) + b"".join(w.i32(t) for t in tex_ids)
    w.add("NiFlipController", ctrl)
    # The clock: an "animated" NiBSAnimationNode (NiAVObject flag 0x20). Its dummy NiVisController is what
    # makes the engine mark it always-update on first update (resetAnimPhasesRecursive), so the cell's
    # BSAnimationManager ticks it with global time. Cloned per decorated item at runtime.
    w.add("NiBSAnimationNode", w.avObject("IE_anim", [], VIS, 0x0020) + w.u32(0) + w.u32(0))
    w.add("NiVisController", w.i32(-1) + w.u16(0x0008) + w.f32(1.0) + w.f32(0.0) + w.f32(0.0) + w.f32(1.0) + w.i32(ANIM) + w.i32(VISDATA))
    w.add("NiVisData", w.u32(1) + w.f32(0.0) + w.u8(1))       # one key: visible from t = 0
    BS = chr(92)
    for k in range(N):
        body = w.objectNET("") + w.u8(1) + w.string("textures" + BS + "ie" + BS + folder + BS + ("rune%03d.tga" % k))
        body += w.u32(6) + w.u32(2) + w.u32(3) + w.u8(1)
        w.add("NiSourceTexture", body)
    w.write(path, [ROOT])


# --- output ------------------------------------------------------------------------------------
if only is None and os.path.isdir(tex_out):
    shutil.rmtree(tex_out)
os.makedirs(mesh_out, exist_ok=True)
for suffix, cfg in SETS.items():
    if only is not None and suffix not in only:
        continue
    means_of = lambda fr: (min(f.mean() for f in fr), max(f.mean() for f in fr), max(f.max() for f in fr))
    if cfg.get("kind") == "cracks":
        count, pixels, frames = build_crack_frames(cfg)
        print("set %r: %d cracks, %d crack px, frame mean %.2f-%.2f, peak %d" % ((suffix, count, pixels) + means_of(frames)))
    else:
        placed, frames = build_frames(cfg)
        print("set %r: %d glyphs (%d-%d px), frame mean %.2f-%.2f, peak %d" % (
            (suffix, len(placed), min(p[0].shape[0] for p in placed), max(p[0].shape[0] for p in placed)) + means_of(frames)))
    for name, (r, g, b) in palette.items():
        folder = name + suffix
        d = os.path.join(tex_out, folder)
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)
        for k, f in enumerate(frames):
            l = Image.fromarray(f)
            rgb = Image.merge("RGB", (l.point(lambda v: v * r // 255), l.point(lambda v: v * g // 255), l.point(lambda v: v * b // 255)))
            rgb.save(os.path.join(d, "rune%03d.tga" % k), compression="tga_rle")   # RLE TGA: DXT1 steps, 24-bit DDS renders white
        write_template(os.path.join(mesh_out, folder + ".nif"), folder)
generated = len(SETS if only is None else [s for s in SETS if s in only]) * len(palette)
print("done: %d texture sets, %d template meshes" % (generated, generated))
