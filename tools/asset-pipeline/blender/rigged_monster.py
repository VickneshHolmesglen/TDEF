"""Rigged painted monsters (ADR-0045 phase 2), Blender built-ins only.

One bone list drives everything:
  1. the body mesh: a vertex at every bone end, joined by edges, with the
     Skin modifier wrapping a hull of the given radii, then Subdivision; both
     applied, so it is one smooth closed mesh;
  2. the armature: the same bones, parented as listed;
  3. skinning: the mesh is bound with automatic (heat) weights. Rigid props
     (eyes, dagger, belt) are parented to a single bone.
Poses are rotations about the world Y axis per bone (side view, the creature
faces +X), keyframed into one action ("idle" at frame 1, "walk" at 2-5), so
the same rig renders the sprite frames and exports as a rigged, animated glb
for a later 3D unit pass (ADR-0043 roadmap: towers -> terrain -> units).

    exec(open(r"G:/TDef/tools/asset-pipeline/blender/rigged_monster.py").read())
    build_rigged("goblin_runner")
    render_rigged("goblin_runner")        # frames to assets/source/3d/units/monsters
    export_rigged("goblin_runner")        # assets/source/3d/units/rigged/goblin_runner.glb
"""
import bpy, math
from mathutils import Vector, Matrix

exec(open(r"G:/TDef/tools/asset-pipeline/blender/painted_kit.py").read())

RAW = r"G:/TDef/assets/source/3d/units/"
COLL = "Rigged"


# ---------------------------------------------------------------- goblin runner
# bone: (name, parent, head, tail, head_radius, tail_radius)
GOBLIN_BONES = [
    ("hips", None, (0.0, 0, 0.5), (0.14, 0, 0.66), 0.15, 0.17),
    ("spine", "hips", (0.14, 0, 0.66), (0.32, 0, 0.8), 0.17, 0.21),
    ("chest", "spine", (0.32, 0, 0.8), (0.48, 0, 0.86), 0.21, 0.13),
    ("neck", "chest", (0.48, 0, 0.86), (0.58, 0, 0.88), 0.09, 0.1),
    ("head", "neck", (0.58, 0, 0.88), (0.8, 0, 0.94), 0.22, 0.17),
    ("nose", "head", (0.8, 0, 0.94), (0.94, 0, 0.86), 0.07, 0.03),
    ("ear.L", "head", (0.6, 0.16, 0.98), (0.38, 0.46, 1.1), 0.07, 0.01),
    ("ear.R", "head", (0.6, -0.16, 0.98), (0.38, -0.46, 1.1), 0.07, 0.01),
    ("thigh.L", "hips", (0.0, 0.13, 0.48), (0.17, 0.15, 0.28), 0.09, 0.075),
    ("shin.L", "thigh.L", (0.17, 0.15, 0.28), (0.04, 0.15, 0.07), 0.075, 0.058),
    ("foot.L", "shin.L", (0.04, 0.15, 0.07), (0.2, 0.15, 0.03), 0.065, 0.05),
    ("thigh.R", "hips", (0.0, -0.13, 0.48), (0.17, -0.15, 0.28), 0.09, 0.075),
    ("shin.R", "thigh.R", (0.17, -0.15, 0.28), (0.04, -0.15, 0.07), 0.075, 0.058),
    ("foot.R", "shin.R", (0.04, -0.15, 0.07), (0.2, -0.15, 0.03), 0.065, 0.05),
    ("upper_arm.L", "chest", (0.42, 0.2, 0.84), (0.5, 0.25, 0.6), 0.075, 0.062),
    ("forearm.L", "upper_arm.L", (0.5, 0.25, 0.6), (0.7, 0.23, 0.45), 0.062, 0.05),
    ("hand.L", "forearm.L", (0.7, 0.23, 0.45), (0.8, 0.22, 0.42), 0.07, 0.055),
    ("upper_arm.R", "chest", (0.42, -0.2, 0.84), (0.5, -0.25, 0.6), 0.075, 0.062),
    ("forearm.R", "upper_arm.R", (0.5, -0.25, 0.6), (0.7, -0.23, 0.45), 0.062, 0.05),
    ("hand.R", "forearm.R", (0.7, -0.23, 0.45), (0.8, -0.22, 0.42), 0.07, 0.055),
]

GOBLIN_SKIN = "#cdb24a"


def on_bone(arm, bone, make):
    """Runs `make()` and parents every object it created to `bone`, keeping
    world placement (a bone parent's frame is the bone's rest matrix moved
    to its tail, rotation included)."""
    before = set(_COLL.objects)
    make()
    b = arm.data.bones[bone]
    inv = (arm.matrix_world @ b.matrix_local @ Matrix.Translation((0.0, b.length, 0.0))).inverted()
    for o in set(_COLL.objects) - before:
        if o.parent is None:
            o.parent = arm
            o.parent_type = "BONE"
            o.parent_bone = bone
            o.matrix_parent_inverse = inv


def goblin_props(arm):
    """Rigid props placed from bone positions, each on one bone."""
    B = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}

    def mid(name, t=0.5):
        h, tl = B[name]
        return h.lerp(tl, t)
    c = mid("chest", 0.1)
    on_bone(arm, "spine", lambda: rot_obj(ellipsoid(c.x - 0.08, 0, c.z - 0.03, 0.24, 0.225, 0.2, "#7a4a26"), ry=1.0))
    hp = B["hips"][0]
    on_bone(arm, "hips", lambda: rot_obj(ellipsoid(hp.x + 0.04, 0, hp.z + 0.04, 0.2, 0.19, 0.11, "#5a3a26"), ry=0.5))
    on_bone(arm, "hips", lambda: box(hp.x + 0.2, -0.13, hp.z + 0.04, 0.06, 0.02, 0.05, "gold"))
    hd = mid("head", 0.35)
    on_bone(arm, "head", lambda: rot_obj(ellipsoid(hd.x - 0.09, 0, hd.z + 0.1, 0.17, 0.2, 0.12, "#6a4022"), ry=-0.35))
    on_bone(arm, "head", lambda: cone_at(hd + Vector((-0.22, 0, 0.1)), 0.1, 0.26, "#6a4022", (-1, 0, 0.35), n=10))
    for s in (-1, 1):
        e = mid("head", 0.8)
        on_bone(arm, "head", lambda s=s, e=e: ellipsoid(e.x + 0.03, s * 0.09, e.z + 0.04, 0.04, 0.04, 0.045, "#ffe36a", glow=True))
    sc = mid("chest", 0.6)
    on_bone(arm, "chest", lambda: rot_obj(ellipsoid(sc.x, 0, sc.z, 0.12, 0.22, 0.08, "#c0463a"), ry=1.2))
    # dagger in the far hand (held low, like the old art)
    h0, h1 = B["hand.L"]
    on_bone(arm, "hand.L", lambda: limb(h1, h1 + Vector((0.24, 0, 0.02)), 0.028, 0.006, "steel"))
    on_bone(arm, "hand.L", lambda: box(h1.x, h1.y, h1.z - 0.03, 0.03, 0.09, 0.06, "#5a3a26"))


SPECS = {
    "goblin_runner": dict(bones=GOBLIN_BONES, skin=GOBLIN_SKIN, props=goblin_props, size=2.0),
}


# ---------------------------------------------------------------- build
def _skin_mesh(bones, key):
    pts, radii, index = [], [], {}

    def vid(p, r):
        k = tuple(round(c, 4) for c in p)
        if k not in index:
            index[k] = len(pts)
            pts.append(p)
            radii.append(r)
        return index[k]

    edges = [(vid(h, rh), vid(t, rt)) for _, _, h, t, rh, rt in bones]
    # The Skin modifier needs one connected graph: a bone whose head doesn't
    # touch its parent gets a joining edge from the nearer end of the parent.
    by_name = {b[0]: b for b in bones}
    for name, parent, h, t, rh, rt in bones:
        if parent is None:
            continue
        _, _, ph, pt, prh, prt = by_name[parent]
        hv = Vector(h)
        if min((hv - Vector(ph)).length, (hv - Vector(pt)).length) < 1e-4:
            continue
        near, nr = (ph, prh) if (hv - Vector(ph)).length < (hv - Vector(pt)).length else (pt, prt)
        edges.append((vid(near, nr), vid(h, rh)))
    me = bpy.data.meshes.new("body")
    me.from_pydata(pts, edges, [])
    o = bpy.data.objects.new("body", me)
    _COLL.objects.link(o)
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for i, r in enumerate(radii):
        me.skin_vertices[0].data[i].radius = (r, r)
    me.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
        bpy.ops.object.modifier_apply(modifier="skin")
        bpy.ops.object.modifier_apply(modifier="sub")
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(mat(key))
    return o


def _armature(bones):
    ad = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", ad)
    _COLL.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, h, t, _, _ in bones:
        eb = ad.edit_bones.new(name)
        eb.head, eb.tail = Vector(h), Vector(t)
        eb.roll = 0.0
        if parent:
            eb.parent = ad.edit_bones[parent]
            eb.use_connect = (Vector(h) - ad.edit_bones[parent].tail).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def build_rigged(mid):
    spec = SPECS[mid]
    clear_collection(COLL)
    solo_collections([COLL])
    for a in list(bpy.data.armatures):
        if a.users == 0:
            bpy.data.armatures.remove(a)
    body = _skin_mesh(spec["bones"], spec["skin"])
    arm = _armature(spec["bones"])
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    spec["props"](arm)
    return arm, body


# ---------------------------------------------------------------- poses
def _rest(arm, name):
    return arm.data.bones[name].matrix_local.to_3x3()


def pose(arm, angles):
    """angles: {bone: radians about world Y; + swings the bone's tip toward +X
    when it points down}. Child angles are relative to the posed parent."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        a = angles.get(pb.name, 0.0)
        r = _rest(arm, pb.name)
        basis = r.inverted() @ Matrix.Rotation(-a, 3, "Y") @ r
        pb.rotation_quaternion = basis.to_quaternion()
    bpy.context.view_layer.update()


def goblin_pose(phase):
    """Low, hunched run (the old art's lunge). phase None = idle."""
    if phase is None:
        return {"thigh.L": -0.05, "thigh.R": 0.1, "shin.L": -0.15, "shin.R": -0.15,
                "upper_arm.L": -0.2, "upper_arm.R": 0.15, "forearm.L": 0.2, "forearm.R": 0.3}
    s = math.sin(phase)
    c = math.cos(phase)
    return {
        "spine": 0.04 * c,
        "thigh.R": 0.7 * s, "thigh.L": -0.7 * s,
        "shin.R": -(0.2 + 1.0 * max(0.0, c)), "shin.L": -(0.2 + 1.0 * max(0.0, -c)),
        "foot.R": 0.25 * s, "foot.L": -0.25 * s,
        "upper_arm.R": -0.8 * s, "upper_arm.L": 0.6 * s - 0.5,
        "forearm.R": 0.4, "forearm.L": 0.2,
        "head": -0.06 * c, "ear.L": 0.12 * c, "ear.R": 0.12 * c,
    }


POSES = {"goblin_runner": goblin_pose}
WALK = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]


def _bob(arm, phase):
    arm.location.z = 0.035 * abs(math.cos(phase)) if phase is not None else 0.0


# ---------------------------------------------------------------- render/export
def render_rigged(mid, frame_px=360, still_px=900):
    import os
    os.makedirs(RAW + "monsters", exist_ok=True)
    arm = bpy.data.objects["rig"]
    size = SPECS[mid]["size"]
    out = []
    for i, ph in enumerate([None] + WALK):
        setup_render(frame_px, frame_px, line_px=2.0, sun_rot=(48, -10, -40))
        ortho_camera(16.0, 18.0, (0.12, 0.0, size * 0.36), size)
        pose(arm, POSES[mid](ph))
        _bob(arm, ph)
        out.append(render_to(RAW + "monsters/%s_f%02d.png" % (mid, i)))
    setup_render(still_px, still_px, line_px=4.0, sun_rot=(48, -10, -40))
    pose(arm, POSES[mid](None))
    _bob(arm, None)
    out.append(render_to(RAW + "monsters/%s_still.png" % mid))
    return out


def export_rigged(mid):
    """Keyframes idle (1) and the walk (2-5, looping at 6) into one action and
    writes a rigged glb."""
    import os
    os.makedirs(RAW + "rigged", exist_ok=True)
    use_collection(COLL)
    bpy.data.objects["body"].data.validate()  # the skin hull can carry degenerate faces
    arm = bpy.data.objects["rig"]
    arm.animation_data_clear()
    arm.animation_data_create()
    act = bpy.data.actions.new(mid + "_walk")
    arm.animation_data.action = act
    for f, ph in zip(range(1, 7), [None] + WALK + [0.0]):
        pose(arm, POSES[mid](ph))
        _bob(arm, ph)
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
        arm.keyframe_insert("location", frame=f)
    objs = [o for o in _COLL.objects]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    path = RAW + "rigged/%s.glb" % mid
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_animations=True,
                              export_skins=True, export_apply=False)
    return path
