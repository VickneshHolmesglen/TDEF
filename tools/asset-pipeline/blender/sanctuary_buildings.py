"""Sanctuary town buildings, painted-vector style (ADR-0045 phase 2).

Builds the 7 Overview buildings at 5 tiers each out of simple primitives and
renders each tier through one fixed 3/4 orthographic camera per building, so
a building's tiers keep their relative size: every tier is bigger and has more
parts than the one before (user: "more intricate and bigger the higher their
level"). Shading matches the in-game painted look: banded diffuse light times
a flat fill, faint brush grain, a thin dark outline (Freestyle).

Run inside Blender (Blender MCP):
    exec(open(r"G:/TDef/tools/asset-pipeline/blender/sanctuary_buildings.py").read())
    render_all()            # or render_all(["keep"], [5]) for one image
Raw renders go to assets/source/3d/sanctuary_buildings/<id>_tier_<n>.png; then
run tools/asset-pipeline/blender/compose_sanctuary_buildings.py (system
Python + Pillow) to fit them onto the game canvases in
assets/art/sanctuary/town/.

Axes: Z up; the camera looks from the front-right, so the -Y (front) and +X
(right) faces are the visible ones. Doors and most windows go there.
"""
import bpy, math

RAW_DIR = r"G:/TDef/assets/source/3d/sanctuary_buildings/"
RES = 1400            # raw render size (px); composed down to ~600 px
ORTHO = 7.0           # world units across the raw render, same for every tier
PITCH_DEG = 38.0      # camera elevation (the old tier art's 3/4 view)
YAW_DEG = 40.0        # camera swing toward +X
TARGET_Z = 1.6
BUILDINGS = ["armoury", "blacksmith", "castle", "keep", "menagerie", "seers_tower", "training_hall"]

ROOF = {
    "armoury": "#4f70a0", "blacksmith": "#b9573d", "castle": "#3e70bc", "keep": "#3f9088",
    "menagerie": "#709f3d", "seers_tower": "#7c5cc4", "training_hall": "#d78a3a",
}
exec(open(r"G:/TDef/tools/asset-pipeline/blender/painted_kit.py").read())


def gable(x, y, z, w, d, h, key, along_x=True, over=0.08):
    """Gable roof; ridge along X (or Y)."""
    if not along_x:
        w, d = d, w
    hw, hd = w / 2 + over, d / 2 + over
    v = [(-hw, -hd, 0), (hw, -hd, 0), (hw, hd, 0), (-hw, hd, 0), (-hw, 0, h), (hw, 0, h)]
    if not along_x:
        v = [(-py, px, pz) for px, py, pz in v]
    v = [(x + px, y + py, z + pz) for px, py, pz in v]
    f = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    return _obj("roof", v, f, key)


# ---------------------------------------------------------------- parts
def pad(w, d, key="cobble"):
    box(0, 0, -0.06, w, d, 0.06, key)


def windows_front(x, y, w, z, h, d, count, skip_mid=False, key="dark"):
    for i in range(count):
        if skip_mid and count % 2 == 1 and i == count // 2:
            continue
        wx = x - w / 2 + w * (i + 0.5) / count
        box(wx, y - d / 2 - 0.012, z + h * 0.35, 0.15, 0.03, h * 0.38, key)
        box(wx, y - d / 2 - 0.03, z + h * 0.33, 0.21, 0.05, 0.035, "wood")


def windows_side(x, y, w, z, h, d, count, key="dark"):
    for i in range(count):
        wy = y - d / 2 + d * (i + 0.5) / count
        box(x + w / 2 + 0.012, wy, z + h * 0.35, 0.03, 0.15, h * 0.38, key)
        box(x + w / 2 + 0.03, wy, z + h * 0.33, 0.05, 0.21, 0.035, "wood")


def house(x, y, w, d, h, roof, storeys=1, timber=False, door=True, chimney=False,
          roof_h=None, along_x=True, z=0.0, wall="wall", glow_windows=False):
    """Walls, plinth, storey bands, doors, windows and a gable roof. Returns roof top z."""
    box(x, y, z, w + 0.06, d + 0.06, 0.14, "stone_dark")
    box(x, y, z, w, d, h, wall)
    sh = h / storeys
    win = "glow" if glow_windows else "dark"
    for s in range(storeys):
        sz = z + s * sh
        if s > 0 or timber:
            box(x, y, sz + (0.0 if s > 0 else sh - 0.05), w + 0.03, d + 0.03, 0.06, "timber")
        n_front = max(1, int(w / 0.42))
        windows_front(x, y, w, sz, sh, d, n_front, skip_mid=(door and s == 0), key=win)
        windows_side(x, y, w, sz, sh, d, max(1, int(d / 0.45)), key=win)
    if timber:
        for cx in (-1, 1):
            box(x + cx * w / 2, y - d / 2, z, 0.07, 0.07, h, "timber")
            box(x + w / 2, y + cx * d / 2, z, 0.07, 0.07, h, "timber")
    if door:
        dw = min(0.3, w * 0.3)
        box(x, y - d / 2 - 0.02, z + 0.02, dw + 0.08, 0.04, min(0.5, sh * 0.72) + 0.06, "timber")
        box(x, y - d / 2 - 0.035, z + 0.02, dw, 0.04, min(0.5, sh * 0.72), "dark")
    rh = roof_h if roof_h is not None else (d if along_x else w) * 0.5
    gable(x, y, z + h, w, d, rh, roof, along_x)
    if chimney:
        box(x + w * 0.28, y + d * 0.12, z + h, 0.18, 0.18, rh + 0.35, "stone_dark")
        box(x + w * 0.28, y + d * 0.12, z + h + rh + 0.35, 0.24, 0.24, 0.06, "stone")
    return z + h + rh


def merlons_rect(x, y, w, d, z, key="stone"):
    box(x, y, z, w + 0.1, d + 0.1, 0.07, "stone_dark")
    step = 0.22
    for side in (-1, 1):
        n = max(2, int(w / step))
        for i in range(n):
            if i % 2 == 0:
                box(x - w / 2 + w * (i + 0.5) / n, y + side * (d / 2 + 0.02), z + 0.07, w / n, 0.1, 0.12, key)
        n = max(2, int(d / step))
        for i in range(n):
            if i % 2 == 0:
                box(x + side * (w / 2 + 0.02), y - d / 2 + d * (i + 0.5) / n, z + 0.07, 0.1, d / n, 0.12, key)


def merlons_round(x, y, r, z, key="stone"):
    prism(x, y, z, r * 1.12, r * 1.12, 0.07, "stone_dark")
    n = max(8, int(math.tau * r / 0.2))
    for i in range(0, n, 2):
        a = math.tau * i / n
        box(x + math.cos(a) * r * 1.08, y + math.sin(a) * r * 1.08, z + 0.07, 0.1, 0.1, 0.12, key, rot=a)


def tower(x, y, r, h, roof, cone=True, crenel=False, cone_h=None, wall="wall", z=0.0, slits=True,
          glow=False):
    """Round tower. Returns top z (roof tip or parapet)."""
    prism(x, y, z, r * 1.08, r * 1.08, 0.16, "stone_dark")
    prism(x, y, z, r, r * 0.96, h, wall)
    if slits:
        rows = max(1, int(h / 0.55))
        for j in range(rows):
            for a_deg in (-90.0, -40.0, 5.0):
                a = math.radians(a_deg)
                box(x + math.cos(a) * r * 0.97, y + math.sin(a) * r * 0.97, z + h * (j + 0.45) / rows,
                    0.06, 0.06, 0.2, "glow" if glow else "dark", rot=a)
    top = z + h
    if crenel:
        merlons_round(x, y, r * 0.96, top)
        top += 0.19
    if cone:
        ch = cone_h if cone_h is not None else r * 2.3
        prism(x, y, z + h, r * 1.22, 0.0, ch, roof, n=16)
        prism(x, y, z + h + ch, 0.025, 0.025, 0.2, "gold", n=6)
        top = z + h + ch + 0.2
    return top


def flag(x, y, z, roof, h=0.45):
    prism(x, y, z, 0.018, 0.018, h, "iron", n=6)
    box(x + 0.14, y, z + h - 0.18, 0.26, 0.02, 0.16, roof)


def banner(x, y, z, roof, w=0.2, h=0.42):
    """Hanging cloth banner on a front (-Y) wall, top at z."""
    box(x, y - 0.02, z - h, w, 0.025, h, roof)
    box(x, y - 0.035, z - 0.04, w + 0.06, 0.03, 0.04, "gold")
    box(x, y - 0.036, z - h * 0.55, w * 0.35, 0.02, w * 0.35, "gold")


def crate(x, y, s=0.2):
    box(x, y, 0, s, s, s, "wood")
    box(x, y, s * 0.45, s + 0.01, s + 0.01, s * 0.1, "timber")


def barrel(x, y, r=0.1, h=0.22, key="wood"):
    prism(x, y, 0, r, r, h, key, n=10)
    prism(x, y, h * 0.2, r * 1.04, r * 1.04, 0.025, "iron", n=10)
    prism(x, y, h * 0.75, r * 1.04, r * 1.04, 0.025, "iron", n=10)


def weapon_rack(x, y, roof):
    for dx in (-0.22, 0.22):
        box(x + dx, y, 0, 0.05, 0.05, 0.42, "timber")
    box(x, y, 0.32, 0.5, 0.05, 0.04, "timber")
    for i in range(4):
        sx = x - 0.16 + i * 0.1
        prism(sx, y - 0.04, 0.0, 0.012, 0.012, 0.55, "wood", n=5)
        prism(sx, y - 0.04, 0.55, 0.03, 0.0, 0.08, "iron", n=4)
    box(x + 0.32, y - 0.02, 0.0, 0.05, 0.05, 0.3, roof)


def shield(x, y, z, roof, r=0.12):
    prism(x, y - 0.01, z, r, r, 0.02, "gold", n=12, rot=0.0).rotation_euler = (math.pi / 2, 0, 0)
    o = prism(x, y - 0.025, z, r * 0.78, r * 0.78, 0.02, roof, n=12)
    o.rotation_euler = (math.pi / 2, 0, 0)


def anvil(x, y):
    box(x, y, 0, 0.12, 0.1, 0.14, "stone_dark")
    box(x, y, 0.14, 0.26, 0.11, 0.07, "iron")


def forge(x, y, s=1.0):
    box(x, y, 0, 0.42 * s, 0.34 * s, 0.3 * s, "stone_dark")
    box(x, y - 0.17 * s - 0.005, 0.08 * s, 0.22 * s, 0.02, 0.14 * s, "glow")
    prism(x, y + 0.02, 0.3 * s, 0.17 * s, 0.07 * s, 0.35 * s, "stone", n=4, rot=math.pi / 4)


def fence(x0, y0, x1, y1, key="wood", post_gap=0.3):
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    n = max(1, int(L / post_gap))
    a = math.atan2(dy, dx)
    for i in range(n + 1):
        t = i / n
        box(x0 + dx * t, y0 + dy * t, 0, 0.05, 0.05, 0.28, "timber")
    for z in (0.1, 0.22):
        box((x0 + x1) / 2, (y0 + y1) / 2, z, L, 0.03, 0.035, key, rot=a)


def dummy(x, y, roof):
    box(x, y, 0, 0.04, 0.04, 0.36, "timber")
    box(x, y, 0.26, 0.26, 0.04, 0.04, "timber")
    prism(x, y, 0.12, 0.08, 0.08, 0.2, "hay", n=8)
    prism(x, y, 0.33, 0.07, 0.05, 0.1, "cloth", n=8)
    box(x, y - 0.06, 0.18, 0.1, 0.02, 0.06, roof)


def target(x, y, roof, r=0.18):
    for dx in (-0.1, 0.1):
        box(x + dx, y + 0.06, 0, 0.03, 0.03, 0.4, "timber")
    for i, (rr, key) in enumerate(((r, "cloth"), (r * 0.66, roof), (r * 0.3, "gold"))):
        o = prism(x, y - 0.01 * i, 0.4, rr, rr, 0.03, key, n=16)
        o.rotation_euler = (math.radians(75), 0, 0)


def crystal(x, y, z, s=1.0):
    prism(x, y, z, 0.1 * s, 0.0, 0.26 * s, "crystal", n=6)
    o = prism(x, y, z, 0.1 * s, 0.0, -0.16 * s, "crystal", n=6)
    return o


def tree(x, y, s=1.0):
    prism(x, y, 0, 0.05 * s, 0.04 * s, 0.3 * s, "timber", n=6)
    bpy_sphere(x, y, 0.42 * s, 0.22 * s, "grass")


def bpy_sphere(x, y, z, r, key):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    for c in o.users_collection:
        c.objects.unlink(o)
    _COLL.objects.link(o)
    o.data.materials.append(mat(key))
    return o


def pen(x, y, w, d, roof):
    fence(x - w / 2, y - d / 2, x + w / 2, y - d / 2)
    fence(x + w / 2, y - d / 2, x + w / 2, y + d / 2)
    fence(x - w / 2, y - d / 2, x - w / 2, y + d / 2)
    box(x, y, -0.03, w, d, 0.035, "grass")
    prism(x - w * 0.25, y + d * 0.1, 0, 0.09, 0.09, 0.08, "hay", n=8)
    box(x + w * 0.2, y + d * 0.2, 0, 0.3, 0.08, 0.06, "wood")
    box(x + w * 0.2, y + d * 0.2, 0.035, 0.26, 0.05, 0.03, "water")


# ---------------------------------------------------------------- buildings
def build_armoury(t, roof):
    pad(1.2 + 0.55 * t, 1.1 + 0.3 * t, "dirt" if t < 3 else "cobble")
    if t == 1:
        house(0, 0, 0.95, 0.75, 0.55, roof)
        weapon_rack(0.8, -0.35, roof)
        return
    if t == 2:
        house(0, 0, 1.3, 0.9, 0.7, roof, timber=True)
        weapon_rack(1.0, -0.4, roof)
        barrel(-0.85, -0.35); crate(-0.85, 0.0)
        return
    w = 1.3 + 0.3 * t
    h = 0.5 + 0.3 * t
    house(0, 0, w, 1.05, h, roof, storeys=2 if t < 5 else 3, timber=True)
    for sx in (-w * 0.3, w * 0.3):
        shield(sx, -0.53, h * 0.72, roof)
    house(w / 2 + 0.4, 0.2, 0.75, 0.7, h * 0.6, roof, door=False, along_x=False)
    weapon_rack(-w / 2 - 0.35, -0.45, roof)
    crate(w / 2 + 0.4, -0.45); crate(w / 2 + 0.62, -0.42, 0.16)
    if t >= 4:
        top = tower(-w / 2 - 0.25, 0.3, 0.36, h + 0.6, roof, crenel=(t == 5))
        flag(-w / 2 - 0.25, 0.3, top, roof)
        banner(0, -0.53, h * 0.98, roof)
    if t == 5:
        tower(w / 2 + 0.95, 0.35, 0.3, h + 0.2, roof)
        merlons_rect(0, 0, w, 1.05, h, "stone")
        shield(0, -0.56, h * 0.5, roof, r=0.2)
        barrel(-w / 2 - 0.65, -0.55)


def build_blacksmith(t, roof):
    pad(1.3 + 0.55 * t, 1.1 + 0.3 * t, "dirt")
    if t == 1:
        for px, py in ((-0.4, -0.3), (0.4, -0.3), (-0.4, 0.3), (0.4, 0.3)):
            box(px, py, 0, 0.07, 0.07, 0.6, "timber")
        gable(0, 0, 0.6, 0.9, 0.7, 0.3, roof)
        forge(-0.1, 0.1); anvil(0.25, -0.2)
        return
    w = 1.0 + 0.35 * t
    h = 0.45 + 0.25 * t
    house(0, 0.1, w, 1.0, h, roof, timber=True, chimney=True, storeys=1 if t < 4 else 2,
          glow_windows=(t >= 3))
    # open forge lean-to on the right
    lx = w / 2 + 0.45
    for py in (-0.35, 0.35):
        box(lx + 0.35, py, 0, 0.07, 0.07, h * 0.75, "timber")
    gable(lx, 0.0, h * 0.75, 0.9, 0.85, 0.22, roof, along_x=False)
    forge(lx, 0.15, 1.0 + 0.1 * t)
    anvil(lx - 0.05, -0.3)
    barrel(-w / 2 - 0.25, -0.4, key="wood")
    prism(-w / 2 - 0.25, -0.4, 0.2, 0.09, 0.09, 0.02, "water", n=10)
    if t >= 3:
        crate(-w / 2 - 0.3, 0.1); weapon_rack(0.1, -0.85, roof)
    if t >= 4:
        box(-w * 0.3, 0.3, h, 0.22, 0.22, 0.9, "stone_dark")
        box(-w * 0.3, 0.3, h + 0.9, 0.28, 0.28, 0.07, "stone")
        banner(-w * 0.25, -0.4, h * 0.9, roof)
    if t == 5:
        house(-w / 2 - 0.55, 0.3, 0.8, 0.8, h * 0.8, roof, chimney=True, door=False, along_x=False,
              glow_windows=True)
        forge(lx + 0.5, -0.45, 0.8)
        prism(0, -0.2, h + 0.05, 0.06, 0.06, 0.4, "iron", n=6)
        box(0.15, -0.65, h * 0.9, 0.5, 0.04, 0.16, "gold")  # sign board


def build_castle(t, roof):
    pad(1.2 + 0.35 * t, 1.2 + 0.35 * t, "cobble")
    if t == 1:
        top = tower(0, 0, 0.42, 1.2, roof, cone=False, crenel=True)
        fence(-0.75, -0.65, 0.75, -0.65); fence(0.75, -0.65, 0.75, 0.6)
        flag(0, 0, top - 0.1, roof)
        return
    kh = 1.0 + 0.45 * t
    kw = 0.75 + 0.12 * t
    box(0, 0.05, 0, kw, kw, kh, "wall")
    windows_front(0, 0.05, kw, 0, kh, kw, 2)
    windows_side(0, 0.05, kw, 0, kh, kw, 2)
    merlons_rect(0, 0.05, kw, kw, kh)
    box(0, 0.05 - kw / 2 - 0.035, 0.02, 0.32, 0.05, 0.5, "dark")
    box(0, 0.05 - kw / 2 - 0.02, 0.02, 0.42, 0.05, 0.58, "timber")
    if t >= 3:
        prism(0, 0.05, kh + 0.19, kw * 0.38, kw * 0.38, 0.5, "wall", n=12)
        prism(0, 0.05, kh + 0.69, kw * 0.48, 0.0, 0.85, roof, n=12)
        flag(0, 0.05, kh + 1.54, roof, 0.5)
        banner(0, 0.05 - kw / 2, kh * 0.72, roof, 0.26, 0.55)
    else:
        flag(0, 0.05, kh + 0.19, roof)
    side = kw / 2 + 0.25
    if t >= 2:
        for sx in (-side, side):
            tower(sx, 0.35, 0.22 + 0.03 * t, kh * 0.62, roof, cone_h=0.6)
    if t >= 4:
        for sx in (-side - 0.05, side + 0.05):
            tower(sx, -0.55, 0.22, kh * 0.45, roof, cone=False, crenel=True)
        box(0, -0.6, 0, side * 2, 0.16, 0.5, "stone")
        merlons_rect(0, -0.6, side * 2, 0.16, 0.5)
        box(0, -0.69, 0.0, 0.36, 0.04, 0.42, "dark")
    if t == 5:
        for sx in (-side * 0.5, side * 0.5):
            banner(sx, -0.68, 0.48, roof, 0.16, 0.3)
        prism(0, -0.69, 0.42, 0.2, 0.2, 0.02, "gold", n=12).rotation_euler = (math.pi / 2, 0, 0)


def build_keep(t, roof):
    pad(1.3 + 0.45 * t, 1.2 + 0.35 * t, "cobble")
    w = 0.85 + 0.2 * t
    h = 0.6 + 0.35 * t
    house(0, 0, w, 0.95, h, roof, storeys=min(3, 1 + t // 2), roof_h=0.55)
    if t >= 2:
        top = tower(w / 2 + 0.3, 0.15, 0.28, h + 0.35, roof, crenel=(t >= 4))
        flag(w / 2 + 0.3, 0.15, top, roof)
    if t >= 3:
        house(-w / 2 - 0.42, 0.15, 0.75, 0.75, h * 0.62, roof, door=False, along_x=False)
        banner(-w * 0.22, -0.48, h * 0.9, roof); banner(w * 0.22, -0.48, h * 0.9, roof)
    if t >= 4:
        top = tower(-w / 2 - 0.55, -0.45, 0.24, h * 0.85, roof)
        box(0, -0.85, 0, w + 0.6, 0.12, 0.35, "stone")
        merlons_rect(0, -0.85, w + 0.6, 0.12, 0.35)
        box(0, -0.92, 0, 0.36, 0.04, 0.32, "dark")
    if t == 5:
        tower(0, 0.15, 0.3, h + 0.95, roof, cone_h=1.0)
        merlons_rect(0, 0, w, 0.95, h)
        tower(w / 2 + 0.55, -0.6, 0.2, h * 0.7, roof)
        shield(0, -0.49, h * 0.55, roof, 0.18)


def build_menagerie(t, roof):
    pad(1.6 + 0.55 * t, 1.3 + 0.35 * t, "dirt")
    bw = 0.7 + 0.2 * t
    bh = 0.45 + 0.17 * t
    house(-0.25 * (t > 1), 0.2, bw, 0.8, bh, roof, timber=True, roof_h=0.45)
    pen(bw / 2 + 0.35, -0.15, 0.7 + 0.08 * t, 0.7, roof)
    if t >= 2:
        prism(-bw / 2 - 0.45, 0.05, 0, 0.18, 0.18, 0.2, "hay", n=10)
        prism(-bw / 2 - 0.45, 0.05, 0.2, 0.18, 0.0, 0.15, "hay", n=10)
    if t >= 3:
        pen(-0.25, -0.75, 1.0, 0.45, roof)
        tree(-bw / 2 - 0.4, 0.55)
    if t >= 4:
        # aviary: ribbed dome on a round base
        ax, ay = bw / 2 + 0.4, 0.75
        prism(ax, ay, 0, 0.42, 0.42, 0.25, "stone")
        for i in range(8):
            a = math.tau * i / 8
            prism(ax + math.cos(a) * 0.38, ay + math.sin(a) * 0.38, 0.25, 0.02, 0.02, 0.5, "gold", n=4)
        prism(ax, ay, 0.75, 0.45, 0.0, 0.45, roof, n=12)
        flag(ax, ay, 1.2, roof, 0.35)
    if t == 5:
        tower(-bw / 2 - 0.5, 0.6, 0.25, bh + 0.5, roof)
        banner(-0.25, 0.2 - 0.4, bh * 0.9, roof)
        tree(bw / 2 + 1.0, -0.65, 0.8)


def build_seers_tower(t, roof):
    pad(0.9 + 0.35 * t, 0.9 + 0.35 * t, "cobble")
    r = 0.3 + 0.04 * t
    h = 0.5 + 0.55 * t
    if t == 1:
        house(0, 0, 0.7, 0.6, 0.45, roof, roof_h=0.32)
        prism(0.5, -0.3, 0, 0.12, 0.08, 0.2, "stone_dark", n=6)
        crystal(0.5, -0.3, 0.32)
        return
    top = tower(0, 0, r, h, roof, cone_h=0.7 + 0.15 * t, glow=(t >= 3))
    for ring_z in [h * f for f in (0.33, 0.66)][: max(0, t - 2)]:
        prism(0, 0, ring_z, r * 1.06, r * 1.06, 0.06, "gold")
    house(r + 0.25, -0.1, 0.5, 0.55, 0.4, roof, door=False, roof_h=0.25, along_x=False)
    crystal(0, 0, top + 0.15, 0.8 + 0.15 * t)
    if t >= 3:
        for a_deg in (200, 330):
            a = math.radians(a_deg)
            prism(math.cos(a) * (r + 0.4), math.sin(a) * (r + 0.4), 0, 0.08, 0.06, 0.3, "stone_dark", n=6)
            crystal(math.cos(a) * (r + 0.4), math.sin(a) * (r + 0.4), 0.42, 0.7)
    if t >= 4:
        prism(0, 0, h * 0.82, r * 1.4, r * 1.4, 0.08, "stone_dark")  # balcony
        tower(-r - 0.25, 0.15, 0.17, h * 0.5, roof, cone_h=0.45)
    if t == 5:
        tower(r + 0.1, 0.45, 0.15, h * 0.65, roof, cone_h=0.4)
        banner(0, -r, h * 0.62, roof, 0.18, 0.4)


def build_training_hall(t, roof):
    pad(1.7 + 0.55 * t, 1.3 + 0.35 * t, "dirt")
    if t == 1:
        dummy(-0.3, 0.0, roof); dummy(0.3, -0.1, roof)
        weapon_rack(0.0, 0.4, roof)
        return
    w = 0.9 + 0.35 * t
    h = 0.45 + 0.17 * t
    house(0, 0.35, w, 0.8, h, roof, timber=True, storeys=1 if t < 5 else 2, roof_h=0.42)
    for i in range(min(t, 4)):
        dummy(-w / 2 + 0.25 + i * 0.38, -0.45, roof)
    if t >= 3:
        target(w / 2 + 0.35, -0.2, roof)
        fence(-w / 2 - 0.2, -0.8, w / 2 + 0.2, -0.8)
        weapon_rack(-w / 2 - 0.35, 0.3, roof)
    if t >= 4:
        house(w / 2 + 0.45, 0.45, 0.7, 0.7, h * 0.8, roof, door=False, along_x=False)
        banner(-w * 0.25, -0.05, h * 0.95, roof); banner(w * 0.25, -0.05, h * 0.95, roof)
    if t == 5:
        top = tower(-w / 2 - 0.35, 0.65, 0.25, h + 0.6, roof)
        flag(-w / 2 - 0.35, 0.65, top, roof)
        target(w / 2 + 0.75, -0.35, roof)
        shield(0, -0.06, h * 0.55, roof, 0.16)


BUILDERS = {
    "armoury": build_armoury, "blacksmith": build_blacksmith, "castle": build_castle,
    "keep": build_keep, "menagerie": build_menagerie, "seers_tower": build_seers_tower,
    "training_hall": build_training_hall,
}


# ---------------------------------------------------------------- scene/render
def _setup_scene():
    setup_render(RES, RES)
    ortho_camera(PITCH_DEG, YAW_DEG, (0.0, 0.0, TARGET_Z), ORTHO)


def build(building_id, tier):
    clear_collection("SanctuaryBuilding")
    solo_collections(["SanctuaryBuilding"])
    BUILDERS[building_id](tier, ROOF[building_id])


def render_all(ids=None, tiers=None):
    _setup_scene()
    done = []
    for bid in ids or BUILDINGS:
        for t in tiers or range(1, 6):
            build(bid, t)
            done.append(render_to(RAW_DIR + "%s_tier_%d.png" % (bid, t)))
    return done
