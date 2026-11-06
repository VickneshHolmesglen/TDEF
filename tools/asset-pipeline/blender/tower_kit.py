"""Tower component kit -- 3D pilot (2026-11-06).

Run inside Blender (via the Blender MCP or Blender's text editor):

    exec(open(r"G:/TDef/tools/asset-pipeline/blender/tower_kit.py").read())
    build_family("octagon")          # base + shaft + top for one silhouette family
    build_weapon("siege")            # one weapon crown
    export_all(r"G:/TDef/assets/source/3d/tower_kit")

Conventions (shared by every piece so any Top seats on any Shaft on any Base):
  * 1 Blender unit = one grid cell's width. Pieces stand on z = 0, centred on
    the origin, front faces -Y (toward the game camera).
  * Every Base ends at BASE_H, every Shaft is SHAFT_H tall, so a stack is
    Base(0) -> Shaft(BASE_H) -> Top(BASE_H + SHAFT_H). No per-piece seat data.
  * Materials use image textures (generated here, saved to disk) with box UVs,
    so glTF export keeps the look; no procedural nodes that the exporter drops.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

BASE_H = 0.30
SHAFT_H = 0.80
TEX_DIR = r"G:/TDef/assets/source/3d/tower_kit/textures"
CAMERA_PITCH_DEG = 50.0  # Hd2dSceneryProfile.camera_pitch_deg default (live 3D view)
# The painted 2D tower set was drawn from a lower angle; sprite renders match it
# so a rendered piece can replace a painted one without looking tipped over.
SPRITE_PITCH_DEG = 30.0

# name -> (base rgb, noise amplitude, streak (wood grain) amount, roughness, metallic)
PALETTE = {
    "stone":      ((0.40, 0.37, 0.33), 0.045, 0.0, 0.9, 0.0),
    "stone_lite": ((0.56, 0.51, 0.44), 0.035, 0.0, 0.85, 0.0),
    "stone_dark": ((0.17, 0.16, 0.15), 0.05, 0.0, 0.9, 0.0),
    "wood":       ((0.36, 0.22, 0.12), 0.08, 0.6, 0.8, 0.0),
    "brass":      ((0.78, 0.52, 0.22), 0.06, 0.0, 0.4, 0.8),
    "gold":       ((0.95, 0.72, 0.20), 0.05, 0.0, 0.3, 0.9),
    "iron":       ((0.26, 0.26, 0.28), 0.06, 0.0, 0.45, 0.6),
    "rune":       ((0.45, 0.85, 1.00), 0.03, 0.0, 0.4, 0.0),  # emissive, see EMISSIVE
}


# Materials that glow (glTF exports these as emissive): name -> strength.
EMISSIVE = {"rune": 2.5}


# ---------------------------------------------------------------- textures --

def _make_texture(name, rgb, amp, streak, size=256, seed=0):
    path = os.path.join(TEX_DIR, f"{name}.png")
    os.makedirs(TEX_DIR, exist_ok=True)
    rng = np.random.default_rng(seed + sum(map(ord, name)))  # str hash() is salted per process
    # Tileable value noise: sum of a few octaves of wrapped, upsampled random grids.
    acc = np.zeros((size, size))
    for octave, weight in ((8, 0.4), (16, 0.4), (32, 0.2)):  # low-frequency: reads as stone, not speckle, once pixelated
        g = rng.random((octave, octave))
        rep = size // octave
        up = np.kron(g, np.ones((rep, rep)))
        # cheap blur by averaging rolled copies keeps it tileable
        for s in (rep // 2,):
            up = (up + np.roll(up, s, 0) + np.roll(up, s, 1) + np.roll(np.roll(up, s, 0), s, 1)) / 4
        acc += weight * up
    acc = (acc - acc.mean()) / (acc.std() + 1e-6)
    if streak:
        x = np.arange(size)
        grain = np.sin(x[None, :] * 2 * math.pi * 6 / size + acc * 1.5)
        acc = acc * (1 - streak) + grain * streak
    img = np.clip(np.array(rgb)[None, None, :] * (1 + amp * acc[..., None] * 2.2), 0, 1)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)
    im = bpy.data.images.get(name) or bpy.data.images.new(name, size, size, alpha=True)
    im.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())  # Blender rows are bottom-up
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return im


def material(name):
    mat = bpy.data.materials.get("tk_" + name)
    if mat:
        return mat
    rgb, amp, streak, rough, metal = PALETTE[name]
    img = _make_texture(name, rgb, amp, streak)
    mat = bpy.data.materials.new("tk_" + name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if name in EMISSIVE:
        nt.links.new(tex.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = EMISSIVE[name]
    return mat


# --------------------------------------------------------------- geometry --

def _finish(obj, mat_name, bevel=0.012, parent=None):
    obj.data.materials.clear()
    obj.data.materials.append(material(mat_name))
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=0.5)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    for p in obj.data.polygons:
        p.use_smooth = False
    if parent:
        obj.parent = parent
    return obj


def prism(name, sides, radius, z0, h, mat, parent, bevel=0.012, top_radius=None):
    """Regular prism standing on z0, oriented so a flat face points -Y."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=radius, radius2=top_radius if top_radius is not None else radius,
        depth=h, location=(0, 0, z0 + h / 2))
    obj = bpy.context.active_object
    obj.name = name
    # Cone vertex 0 sits at +X, so face normals start at pi/sides. Rotate so a
    # face (not a corner) points -Y, matching face_frames()/corners().
    obj.rotation_euler.z = (-math.pi / 2 - math.pi / sides) % (2 * math.pi / sides)
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, mat, bevel, parent)


def box(name, size, loc, rot_z, mat, parent, bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler.z = rot_z
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    return _finish(obj, mat, bevel, parent)


def cylinder(name, radius, depth, loc, rot, mat, parent, verts=16, bevel=0.006):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, mat, bevel, parent)


def face_frames(sides, radius):
    """(angle of outward normal, apothem, face width) per face; one face at -Y."""
    apothem = radius * math.cos(math.pi / sides)
    width = 2 * radius * math.sin(math.pi / sides)
    out = []
    for i in range(sides):
        a = -math.pi / 2 + i * 2 * math.pi / sides
        out.append((a, apothem, width))
    return out


def corners(sides, radius):
    return [(-math.pi / 2 + (i + 0.5) * 2 * math.pi / sides, radius) for i in range(sides)]


def _root(name):
    old = bpy.data.objects.get(name)
    if old:
        for c in list(old.children_recursive) + [old]:
            bpy.data.objects.remove(c, do_unlink=True)
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    return root


def panel_on_face(prefix, a, apothem, width, z, h, parent, frame_mat="brass", fill_mat="stone_dark", slit=False):
    nx, ny = math.cos(a), math.sin(a)
    rz = a + math.pi / 2
    box(prefix + "_frame", (width * 0.72, 0.03, h), (nx * (apothem + 0.004), ny * (apothem + 0.004), z), rz, frame_mat, parent)
    box(prefix + "_fill", (width * 0.58, 0.03, h * 0.72), (nx * (apothem + 0.010), ny * (apothem + 0.010), z), rz, fill_mat, parent)
    if slit:
        box(prefix + "_slit", (width * 0.07, 0.03, h * 0.42), (nx * (apothem + 0.016), ny * (apothem + 0.016), z), rz, "iron", parent, bevel=0)


# ------------------------------------------------------------ structure -----
# glb contract (ADR-0043): root named after the piece; bases/shafts carry a
# `Seat` empty at their top face; crowns carry a `Crown` empty (the turn
# pivot) holding everything that turns; additive detail lives in `Tier2`,
# `Tier3`, `Tier4` empties. Everything outside the tier groups is the T1 body.

def empty(name, parent, loc=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    return obj


def tier_groups(parent):
    """Tier2..Tier4 empties under parent; returns {2: obj, 3: obj, 4: obj}."""
    return {t: empty(f"Tier{t}", parent) for t in (2, 3, 4)}


def ring_band(name, sides, radius, z, h, mat, parent):
    """Thin full-perimeter band hugging a prism (iron hoops, gold trims)."""
    return prism(name, sides, radius, z, h, mat, parent, bevel=0.004)


def studs_on_corners(prefix, sides, radius, z, mat, parent, size=0.03):
    for i, (a, rad) in enumerate(corners(sides, radius)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=size / 2,
                                             location=(math.cos(a) * rad, math.sin(a) * rad, z))
        _finish(bpy.context.active_object, mat, 0, parent).name = f"{prefix}{i}"


def merlons(prefix, sides, radius, z, h, mat, parent):
    """Crenellation: one block per face, centred on the face."""
    for i, (a, ap, w) in enumerate(face_frames(sides, radius)):
        box(f"{prefix}{i}", (w * 0.42, 0.07, h), (math.cos(a) * (ap - 0.035), math.sin(a) * (ap - 0.035), z + h / 2),
            a + math.pi / 2, mat, parent)


def buttresses(prefix, sides, radius, h, mat, parent, depth=0.08):
    """Sloped corner buttresses standing on the piece's ground plane."""
    for i, (a, rad) in enumerate(corners(sides, radius)):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=depth * 0.9, radius2=depth * 0.35, depth=h,
                                        location=(math.cos(a) * rad, math.sin(a) * rad, h / 2))
        obj = bpy.context.active_object
        obj.rotation_euler.z = a + math.pi / 4
        bpy.ops.object.transform_apply(rotation=True)
        _finish(obj, mat, 0.004, parent).name = f"{prefix}{i}"


def runes_on_faces(prefix, sides, radius, z, h, parent, skip_front=False):
    for i, (a, ap, w) in enumerate(face_frames(sides, radius)):
        if skip_front and i == 0:
            continue
        box(f"{prefix}{i}", (w * 0.12, 0.02, h), (math.cos(a) * (ap + 0.02), math.sin(a) * (ap + 0.02), z),
            a + math.pi / 2, "rune", parent, bevel=0)


# ------------------------------------------------------------ octagon kit --

def build_octagon_base(x=0.0):
    root = _root("base_octagon")
    n, r = 8, 0.50
    body_z, body_h = 0.06, BASE_H - 0.10
    prism("lip", n, r * 1.16, 0.0, 0.06, "stone_lite", root)
    prism("body", n, r, body_z, body_h, "stone", root)
    prism("cap", n, r * 1.04, BASE_H - 0.04, 0.04, "stone_lite", root)
    prism("cap_inset", n, r * 0.86, BASE_H - 0.005, 0.01, "stone", root, bevel=0)
    for i, (a, ap, w) in enumerate(face_frames(n, r)):
        panel_on_face(f"pan{i}", a, ap, w, body_z + body_h / 2, body_h * 0.7, root)
    for i, (a, rad) in enumerate(corners(n, r)):
        box(f"trim{i}", (0.035, 0.035, body_h), (math.cos(a) * rad, math.sin(a) * rad, body_z + body_h / 2), a, "brass", root)
    empty("Seat", root, (0, 0, BASE_H))
    t = tier_groups(root)
    # T2: iron hoop round the lip, studs on every brass trim
    ring_band("t2_hoop", n, r * 1.17, 0.045, 0.02, "iron", t[2])
    studs_on_corners("t2_stud", n, r * 1.02, body_z + body_h * 0.75, "iron", t[2])
    studs_on_corners("t2_studlo", n, r * 1.02, body_z + body_h * 0.25, "iron", t[2])
    # T3: corner buttresses and a crenellated rim round the cap
    buttresses("t3_butt", n, r * 1.12, BASE_H - 0.02, "stone_lite", t[3])
    merlons("t3_merlon", n, r * 1.04, BASE_H, 0.06, "stone_lite", t[3])
    # T4: gold cornice and glowing runes on every panel
    ring_band("t4_cornice", n, r * 1.06, BASE_H - 0.045, 0.012, "gold", t[4])
    runes_on_faces("t4_rune", n, r, body_z + body_h / 2, body_h * 0.4, t[4])
    root.location.x = x
    return root


def build_octagon_shaft(x=0.0):
    root = _root("shaft_octagon")
    n, r = 8, 0.40
    band = 0.07
    body_mid = SHAFT_H / 2
    prism("foot", n, r * 1.08, 0.0, band, "stone_lite", root)
    prism("body", n, r, band, SHAFT_H - 2 * band, "stone", root)
    prism("collar", n, r * 1.08, SHAFT_H - band, band, "stone_lite", root)
    for i, (a, ap, w) in enumerate(face_frames(n, r)):
        panel_on_face(f"pan{i}", a, ap, w, body_mid, (SHAFT_H - 2 * band) * 0.78, root,
                      frame_mat="stone_lite", fill_mat="stone_dark", slit=(i == 0))
    for i, (a, rad) in enumerate(corners(n, r)):
        box(f"pil{i}", (0.05, 0.05, SHAFT_H - 2 * band), (math.cos(a) * rad, math.sin(a) * rad, body_mid), a, "stone_lite", root)
    empty("Seat", root, (0, 0, SHAFT_H))
    t = tier_groups(root)
    # T2: two iron hoops and studs on the pilasters
    for k, z in enumerate((SHAFT_H * 0.33, SHAFT_H * 0.66)):
        ring_band(f"t2_hoop{k}", n, r * 1.03, z, 0.022, "iron", t[2])
    studs_on_corners("t2_stud", n, r * 1.05, SHAFT_H - band - 0.04, "iron", t[2])
    # T3: tall corner buttresses and corbels under the collar
    buttresses("t3_butt", n, r * 1.06, SHAFT_H * 0.55, "stone_lite", t[3], depth=0.07)
    for i, (a, ap, w) in enumerate(face_frames(n, r)):
        box(f"t3_corbel{i}", (w * 0.3, 0.06, 0.05),
            (math.cos(a) * (ap + 0.03), math.sin(a) * (ap + 0.03), SHAFT_H - band - 0.025),
            a + math.pi / 2, "stone_lite", t[3])
    # T4: gold collar band and glowing runes up every face but the slit
    ring_band("t4_collar", n, r * 1.10, SHAFT_H - band * 0.5, 0.015, "gold", t[4])
    runes_on_faces("t4_rune", n, r, body_mid, (SHAFT_H - 2 * band) * 0.5, t[4], skip_front=True)
    root.location.x = x
    return root


def build_octagon_top(x=0.0):
    root = _root("top_octagon")
    crown = empty("Crown", root)
    n, r = 8, 0.52
    prism("deck", n, r, 0.0, 0.08, "stone", crown)
    prism("rim", n, r * 1.02, 0.08, 0.05, "stone_lite", crown)
    prism("well", n, r * 0.84, 0.08, 0.051, "stone", crown, bevel=0)  # recessed floor inside the rim
    for i, (a, rad) in enumerate(corners(n, r * 0.84)):
        mid = rad * 0.55
        box(f"rib{i}", (rad * 0.62, 0.05, 0.035), (math.cos(a) * mid, math.sin(a) * mid, 0.145), a, "stone_lite", crown)
        box(f"stud{i}", (0.05, 0.05, 0.03), (math.cos(a) * r * 0.93, math.sin(a) * r * 0.93, 0.145), a, "brass", crown)
    prism("dish_ring", 16, 0.16, 0.13, 0.04, "brass", crown)
    prism("dish", 16, 0.13, 0.15, 0.035, "gold", crown, top_radius=0.10)
    t = tier_groups(crown)
    # T2: iron band round the deck, iron studs round the dish
    ring_band("t2_band", n, r * 1.01, 0.03, 0.02, "iron", t[2])
    studs_on_corners("t2_dishstud", 8, 0.19, 0.15, "iron", t[2], size=0.025)
    # T3: crenellated rim
    merlons("t3_merlon", n, r * 1.02, 0.13, 0.07, "stone_lite", t[3])
    # T4: gold filigree on the ribs, a glowing rune ring and a gold finial
    for i, (a, rad) in enumerate(corners(n, r * 0.84)):
        mid = rad * 0.55
        box(f"t4_filigree{i}", (rad * 0.5, 0.018, 0.012), (math.cos(a) * mid, math.sin(a) * mid, 0.168), a, "gold", t[4], bevel=0)
    prism("t4_runering", 24, 0.22, 0.132, 0.012, "rune", t[4], bevel=0)
    prism("t4_finial", 8, 0.03, 0.185, 0.14, "gold", t[4], top_radius=0.005)
    root.location.x = x
    return root


# ------------------------------------------------------------ weapons -------

def build_weapon_siege(x=0.0):
    root = _root("weapon_siege")
    crown = empty("Crown", root)
    n, r = 8, 0.50
    prism("platform_rim", n, r * 1.03, 0.0, 0.025, "iron", crown)  # iron foot band under the deck
    prism("platform", n, r, 0.025, 0.07, "wood", crown)
    prism("turntable", 16, 0.30, 0.095, 0.04, "wood", crown)
    for s in (-1, 1):
        box(f"cheek{s}", (0.06, 0.40, 0.18), (s * 0.15, 0.02, 0.225), 0.0, "wood", crown)
        box(f"cheek_band{s}", (0.065, 0.05, 0.185), (s * 0.15, -0.14, 0.225), 0.0, "iron", crown)
        cylinder(f"wheel{s}", 0.11, 0.05, (s * 0.22, -0.06, 0.20), (0, math.pi / 2, 0), "wood", crown, verts=12)
        cylinder(f"hub{s}", 0.035, 0.07, (s * 0.22, -0.06, 0.20), (0, math.pi / 2, 0), "iron", crown, verts=8)
    # barrel, pitched up, muzzle toward -Y (glTF +Z: the crown's front)
    pitch = math.radians(14)
    length = 0.62
    centre = Vector((0.0, -0.02, 0.34))
    rot = (math.pi / 2 - pitch, 0, 0)  # cylinder axis Z -> -Y, tilted up by pitch
    dirv = Vector((0, -math.cos(pitch), math.sin(pitch)))
    cylinder("barrel", 0.085, length, tuple(centre), rot, "iron", crown, verts=16)
    for k, tt in enumerate((-0.24, 0.0, 0.22)):
        cylinder(f"band{k}", 0.097, 0.04, tuple(centre + dirv * tt), rot, "brass", crown, verts=16)
    muzzle = centre + dirv * (length / 2)
    cylinder("muzzle", 0.105, 0.06, tuple(muzzle), rot, "iron", crown, verts=16)
    cylinder("bore", 0.055, 0.065, tuple(muzzle + dirv * 0.004), rot, "stone_dark", crown, verts=12, bevel=0)
    breech = centre - dirv * (length / 2)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.09, location=tuple(breech))
    _finish(bpy.context.active_object, "iron", 0, crown).name = "cascabel"
    t = tier_groups(crown)
    # T2: iron plates on the cheeks, studs round the platform
    for s in (-1, 1):
        box(f"t2_plate{s}", (0.066, 0.12, 0.10), (s * 0.15, 0.12, 0.23), 0.0, "iron", t[2])
    studs_on_corners("t2_stud", n, r * 0.97, 0.097, "iron", t[2])
    # T3: extra barrel hoops and iron spikes round the platform edge
    for k, tt in enumerate((-0.12, 0.11)):
        cylinder(f"t3_band{k}", 0.093, 0.025, tuple(centre + dirv * tt), rot, "iron", t[3], verts=16)
    for i, (a, rad) in enumerate(corners(n, r)):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.025, radius2=0.0, depth=0.09,
                                        location=(math.cos(a) * rad, math.sin(a) * rad, 0.14))
        _finish(bpy.context.active_object, "iron", 0, t[3]).name = f"t3_spike{i}"
    # T4: gold muzzle crown, gold breech ring, glowing runes on the cheeks
    cylinder("t4_muzzlecrown", 0.116, 0.03, tuple(muzzle - dirv * 0.045), rot, "gold", t[4], verts=16)  # collar behind the muzzle lip
    cylinder("t4_breechring", 0.1, 0.03, tuple(breech + dirv * 0.06), rot, "gold", t[4], verts=16)
    for s in (-1, 1):
        box(f"t4_rune{s}", (0.068, 0.2, 0.025), (s * 0.15, 0.02, 0.29), 0.0, "rune", t[4], bevel=0)
    root.location.x = x
    return root


FAMILIES = {"octagon": (build_octagon_base, build_octagon_shaft, build_octagon_top)}
WEAPONS = {"siege": build_weapon_siege}


def build_family(name, x=0.0):
    b, s, t = FAMILIES[name]
    return b(x), s(x + 1.4), t(x + 2.8)


def build_weapon(name, x=4.2):
    return WEAPONS[name](x)


def stack(base, shaft, top, x=-2.0):
    """Assembled preview: duplicate-free, just re-positions the roots."""
    base.location = (x, 0, 0)
    shaft.location = (x, 0, BASE_H)
    top.location = (x, 0, BASE_H + SHAFT_H)


# ------------------------------------------------------------ output --------

def setup_render_camera(target_height=1.3, ortho=2.0, pitch_deg=SPRITE_PITCH_DEG):
    scene = bpy.context.scene
    cam = bpy.data.objects.get("Camera")
    pitch = math.radians(pitch_deg)
    dist = 10.0
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    cam.location = (0, -dist * math.cos(pitch), target_height / 2 + dist * math.sin(pitch))
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"  # AgX/Filmic wash out the painted palette
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    sun = bpy.data.objects.get("Light")
    sun.data.type = "SUN"
    sun.data.energy = 2.6
    sun.rotation_euler = (math.radians(45), 0, math.radians(-35))
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.55, 0.58, 0.65, 1)
    bg.inputs[1].default_value = 0.6
    return cam


def render_piece(root, out_path, ortho=None, pitch_deg=SPRITE_PITCH_DEG, yaw_deg=0.0):
    """Render one root alone, centred, through the game-pitch camera."""
    scene = bpy.context.scene
    roots = [o for o in scene.objects if o.parent is None and o.type == "EMPTY"]
    saved = {o.name: (o.hide_render, tuple(o.location)) for o in roots}
    for o in roots:
        for c in [o] + list(o.children_recursive):
            c.hide_render = o is not root
    loc, yaw = tuple(root.location), root.rotation_euler.z
    root.location = (0, 0, 0)
    root.rotation_euler.z = math.radians(yaw_deg)
    bpy.context.view_layer.update()  # matrix_world is stale after moving the root
    pts = [c.matrix_world @ Vector(v) for c in root.children_recursive if c.type == "MESH" for v in c.bound_box]
    h = max(p.z for p in pts)
    w = max(max(abs(p.x) for p in pts), max(abs(p.y) for p in pts)) * 2
    cam = setup_render_camera(h, ortho or max(w, h) * 1.15, pitch_deg)
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    root.location, root.rotation_euler.z = loc, yaw
    for o in roots:
        for c in [o] + list(o.children_recursive):
            c.hide_render = saved[o.name][0]
    return out_path


def export_glb(root, out_path):
    bpy.ops.object.select_all(action="DESELECT")
    for c in [root] + list(root.children_recursive):
        c.select_set(True)
    loc = tuple(root.location)
    root.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=out_path, use_selection=True, export_apply=True, export_yup=True)
    root.location = loc
    bpy.ops.object.select_all(action="DESELECT")
    return out_path


def build_stack(name, base, shaft, crown, crown_yaw_deg=0.0):
    """Parent a Base/Shaft/crown triple under one root at the shared seat heights.

    The kit's fixed heights replace the 2D pipeline's per-texture seat table:
    every Shaft starts at BASE_H and every crown at BASE_H + SHAFT_H.
    """
    root = _root(name)
    for piece, z in ((base, 0.0), (shaft, BASE_H), (crown, BASE_H + SHAFT_H)):
        piece.parent = root
        piece.location = (0, 0, z)
        piece.rotation_euler = (0, 0, 0)
    # Weapons turn to aim; a 3/4 yaw keeps a barrel readable instead of end-on.
    crown.rotation_euler.z = math.radians(crown_yaw_deg)
    return root


def unstack(root, spacing=1.4):
    """Undo build_stack(): lay the pieces back out in a row and drop the root."""
    for i, piece in enumerate(list(root.children)):
        piece.parent = None
        piece.location = (i * spacing, 0, 0)
    bpy.data.objects.remove(root, do_unlink=True)


# ------------------------------------------------------------ engine export --
# Engine assets (ADR-0043): one .gltf (+ .bin) per piece, textures shared in textures/, in assets/art/towers3d/ plus a
# static icon render in assets/art/towers3d/icons/ for the menu galleries.

ART_DIR = r"G:/TDef/assets/art/towers3d"
CONTAINER_NAMES = ("Crown", "Tier2", "Tier3", "Tier4")


def clear_scene_objects():
    """Remove every mesh and empty so marker names (Seat, Crown, TierN) stay
    exact: Blender suffixes duplicates (Seat.001), which would break the
    engine's lookups by name."""
    for o in list(bpy.data.objects):
        if o.type in ("MESH", "EMPTY"):
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def _join_children_by_material(container):
    meshes = [c for c in container.children if c.type == "MESH"]
    groups = {}
    for m in meshes:
        groups.setdefault(m.active_material.name if m.active_material else "", []).append(m)
    for mat_name, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        objs[0].name = f"{container.name}_{mat_name.removeprefix('tk_')}"


def bake_piece(root):
    """Apply modifiers and join meshes per material inside every container
    (root, Crown, Tier2..4), keeping the container empties."""
    bpy.ops.object.select_all(action="DESELECT")
    for c in root.children_recursive:
        if c.type == "MESH":
            c.select_set(True)
    if bpy.context.selected_objects:
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.convert(target="MESH")
    containers = [root] + [c for c in root.children_recursive if c.type == "EMPTY" and c.name in CONTAINER_NAMES]
    for container in containers:
        _join_children_by_material(container)
    bpy.ops.object.select_all(action="DESELECT")


def export_gltf_shared(root, out_path):
    """Export as .gltf + .bin with images in ART_DIR/textures/, shared by every
    piece (a .glb embeds its own copies, which Godot then extracts per piece)."""
    bpy.ops.object.select_all(action="DESELECT")
    for c in [root] + list(root.children_recursive):
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out_path, use_selection=True, export_apply=True, export_yup=True,
                              export_format="GLTF_SEPARATE", export_texture_dir="textures")
    bpy.ops.object.select_all(action="DESELECT")
    return out_path


def export_piece(builder):
    """Build one piece alone, bake it, export glb + icon. Returns the root name."""
    clear_scene_objects()
    root = builder(0.0)
    bake_piece(root)
    name = root.name
    os.makedirs(os.path.join(ART_DIR, "icons"), exist_ok=True)
    export_gltf_shared(root, os.path.join(ART_DIR, name + ".gltf"))
    scene = bpy.context.scene
    scene.render.resolution_percentage = 50  # 256 px icons
    try:
        # weapons turn 3/4 so the barrel reads instead of facing the camera end-on
        render_piece(root, os.path.join(ART_DIR, "icons", name + ".png"), yaw_deg=-40.0 if name.startswith("weapon_") else 0.0)
    finally:
        scene.render.resolution_percentage = 100
    return name


PILOT_PIECES = (build_octagon_base, build_octagon_shaft, build_octagon_top, build_weapon_siege)


def export_pieces(builders=PILOT_PIECES):
    import contextlib
    import io
    import logging
    logging.disable(logging.INFO)
    done = []
    for b in builders:
        with contextlib.redirect_stdout(io.StringIO()):
            done.append(export_piece(b))
    return done
