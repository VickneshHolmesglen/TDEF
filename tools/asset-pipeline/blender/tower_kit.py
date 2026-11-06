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
}


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


# ------------------------------------------------------------ octagon kit --

def build_octagon_base(x=0.0):
    root = _root("base_octagon")
    n, r = 8, 0.50
    prism("lip", n, r * 1.16, 0.0, 0.06, "stone_lite", root)
    prism("body", n, r, 0.06, BASE_H - 0.10, "stone", root)
    prism("cap", n, r * 1.04, BASE_H - 0.04, 0.04, "stone_lite", root)
    prism("cap_inset", n, r * 0.86, BASE_H - 0.005, 0.01, "stone", root, bevel=0)
    for i, (a, ap, w) in enumerate(face_frames(n, r)):
        panel_on_face(f"pan{i}", a, ap, w, 0.06 + (BASE_H - 0.10) / 2, (BASE_H - 0.10) * 0.7, root)
    for i, (a, rad) in enumerate(corners(n, r)):
        box(f"trim{i}", (0.035, 0.035, BASE_H - 0.10), (math.cos(a) * rad, math.sin(a) * rad, 0.06 + (BASE_H - 0.10) / 2), a, "brass", root)
    root.location.x = x
    return root


def build_octagon_shaft(x=0.0):
    root = _root("shaft_octagon")
    n, r = 8, 0.40
    band = 0.07
    prism("foot", n, r * 1.08, 0.0, band, "stone_lite", root)
    prism("body", n, r, band, SHAFT_H - 2 * band, "stone", root)
    prism("collar", n, r * 1.08, SHAFT_H - band, band, "stone_lite", root)
    body_mid = SHAFT_H / 2
    for i, (a, ap, w) in enumerate(face_frames(n, r)):
        panel_on_face(f"pan{i}", a, ap, w, body_mid, (SHAFT_H - 2 * band) * 0.78, root,
                      frame_mat="stone_lite", fill_mat="stone_dark", slit=(i == 0))
    for i, (a, rad) in enumerate(corners(n, r)):
        box(f"pil{i}", (0.05, 0.05, SHAFT_H - 2 * band), (math.cos(a) * rad, math.sin(a) * rad, body_mid), a, "stone_lite", root)
    root.location.x = x
    return root


def build_octagon_top(x=0.0):
    root = _root("top_octagon")
    n, r = 8, 0.52
    prism("deck", n, r, 0.0, 0.08, "stone", root)
    prism("rim", n, r * 1.02, 0.08, 0.05, "stone_lite", root)
    prism("well", n, r * 0.84, 0.08, 0.051, "stone", root, bevel=0)  # recessed floor inside the rim
    for i, (a, rad) in enumerate(corners(n, r * 0.84)):
        mid = rad * 0.55
        box(f"rib{i}", (rad * 0.62, 0.05, 0.035), (math.cos(a) * mid, math.sin(a) * mid, 0.145), a, "stone_lite", root)
        box(f"stud{i}", (0.05, 0.05, 0.03), (math.cos(a) * r * 0.93, math.sin(a) * r * 0.93, 0.145), a, "brass", root)
    prism("dish_ring", 16, 0.16, 0.13, 0.04, "brass", root)
    prism("dish", 16, 0.13, 0.15, 0.035, "gold", root, top_radius=0.10)
    root.location.x = x
    return root


# ------------------------------------------------------------ weapons -------

def build_weapon_siege(x=0.0):
    root = _root("weapon_siege")
    n, r = 8, 0.50
    prism("platform_rim", n, r * 1.03, 0.0, 0.025, "iron", root)  # iron foot band under the deck
    prism("platform", n, r, 0.025, 0.07, "wood", root)
    prism("turntable", 16, 0.30, 0.095, 0.04, "wood", root)
    # carriage cheeks
    for s in (-1, 1):
        box(f"cheek{s}", (0.06, 0.40, 0.18), (s * 0.15, 0.02, 0.225), 0.0, "wood", root)
        box(f"cheek_band{s}", (0.065, 0.05, 0.185), (s * 0.15, -0.14, 0.225), 0.0, "iron", root)
        cylinder(f"wheel{s}", 0.11, 0.05, (s * 0.22, -0.06, 0.20), (0, math.pi / 2, 0), "wood", root, verts=12)
        cylinder(f"hub{s}", 0.035, 0.07, (s * 0.22, -0.06, 0.20), (0, math.pi / 2, 0), "iron", root, verts=8)
    # barrel, pitched up, muzzle toward -Y (the camera) and slightly up
    pitch = math.radians(14)
    length = 0.62
    cx, cy, cz = 0.0, -0.02, 0.34
    rot = (math.pi / 2 - pitch, 0, 0)  # cylinder axis Z -> -Y, tilted up by pitch
    cylinder("barrel", 0.085, length, (cx, cy, cz), rot, "iron", root, verts=16)
    dirv = Vector((0, -math.cos(pitch), math.sin(pitch)))
    for k, t in enumerate((-0.24, 0.0, 0.22)):
        p = Vector((cx, cy, cz)) + dirv * t
        cylinder(f"band{k}", 0.097, 0.04, tuple(p), rot, "brass", root, verts=16)
    muzzle = Vector((cx, cy, cz)) + dirv * (length / 2)
    cylinder("muzzle", 0.105, 0.06, tuple(muzzle), rot, "iron", root, verts=16)
    cylinder("bore", 0.055, 0.065, tuple(muzzle + dirv * 0.004), rot, "stone_dark", root, verts=12, bevel=0)
    breech = Vector((cx, cy, cz)) - dirv * (length / 2)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.09, location=tuple(breech))
    _finish(bpy.context.active_object, "iron", 0, root).name = "cascabel"
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
