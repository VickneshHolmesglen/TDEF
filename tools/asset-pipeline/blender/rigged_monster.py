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


# ---------------------------------------------------------------- skin graph
# A body is a graph of shaped nodes, denser than the rig (2026-11-08 rebuild):
# calves, elbows, a belly, palms with fingers, heel/ball/toes, a skull with
# brow, snout and jaw. One Skin hull wraps it all, so hands, ears and face
# are one closed mesh. nodes: name -> (position, radius); radius is a float
# or (rx, ry). Names ending ".L" are mirrored to ".R" (y negated), and so are
# edges touching them. The creature faces +X, Y is its left, Z is up.

def _mirror(nodes, edges):
    out = dict(nodes)
    for k, (p, r) in nodes.items():
        if k.endswith(".L"):
            out[k[:-2] + ".R"] = ((p[0], -p[1], p[2]), r)
    e = list(edges)
    for a, b in edges:
        if a.endswith(".L") or b.endswith(".L"):
            e.append((a.replace(".L", ".R"), b.replace(".L", ".R")))
    return out, e


def skin_body(nodes, edges, key, root, levels=2):
    """The Skin hull over the node graph, subdivided and applied: one smooth
    closed mesh named "body"."""
    nodes, edges = _mirror(nodes, edges)
    names = list(nodes)
    idx = {k: i for i, k in enumerate(names)}
    me = bpy.data.meshes.new("body")
    me.from_pydata([nodes[k][0] for k in names], [(idx[a], idx[b]) for a, b in edges], [])
    o = bpy.data.objects.new("body", me)
    _COLL.objects.link(o)
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.5
    for k in names:
        r = nodes[k][1]
        me.skin_vertices[0].data[idx[k]].radius = (r, r) if isinstance(r, (int, float)) else r
    me.skin_vertices[0].data[idx[root]].use_root = True
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = levels
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
        bpy.ops.object.modifier_apply(modifier="skin")
        bpy.ops.object.modifier_apply(modifier="sub")
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(mat(key))
    return o


# ---------------------------------------------------------------- sculpt brushes
# Scripted stand-ins for sculpt mode: each moves the body's vertices within
# `radius` of `center` with a smooth falloff. mask(co, side) limits which
# vertices a brush may touch; mirror=True repeats it on the right side
# (side = -1 there, so masks and directions can flip y).

def _falloff(d, radius):
    t = max(0.0, 1.0 - d / radius)
    return t * t * (3.0 - 2.0 * t)


def _brush(o, center, radius, mask, mirror, move):
    centers = [(Vector(center), 1.0)]
    if mirror:
        centers.append((Vector((center[0], -center[1], center[2])), -1.0))
    for c, side in centers:
        for v in o.data.vertices:
            if mask is not None and not mask(v.co, side):
                continue
            w = _falloff((v.co - c).length, radius)
            if w > 0.0:
                v.co = move(v.co.copy(), c, w, side)


def brush_scale(o, center, radius, scale, mask=None, mirror=False):
    """Scales around `center` per axis (x, y, z), fading out to `radius`."""
    s = Vector(scale)

    def move(co, c, w, side):
        d = co - c
        return co + Vector((d.x * (s.x - 1.0), d.y * (s.y - 1.0), d.z * (s.z - 1.0))) * w
    _brush(o, center, radius, mask, mirror, move)


def brush_flatten(o, center, radius, normal, keep, mask=None, mirror=False):
    """Squashes toward the plane through `center` with `normal`, keeping
    `keep` of the thickness (ears, feet, palms)."""
    def move(co, c, w, side):
        n = Vector((normal[0], normal[1] * side, normal[2])).normalized()
        return co - n * (co - c).dot(n) * (1.0 - keep) * w
    _brush(o, center, radius, mask, mirror, move)


def brush_move(o, center, radius, offset, mask=None, mirror=False):
    """Pushes by `offset` (a belly forward, a hunch up)."""
    def move(co, c, w, side):
        return co + Vector((offset[0], offset[1] * side, offset[2])) * w
    _brush(o, center, radius, mask, mirror, move)


def surface_point(o, origin, direction):
    """First hit on `o` from `origin` along `direction` (object space)."""
    hit, loc, normal, _ = o.ray_cast(Vector(origin), Vector(direction).normalized())
    return (loc, normal) if hit else (Vector(origin), -Vector(direction))


# ---------------------------------------------------------------- fitted clothes
def shell(body, arm, name, keep_face, key, push=0.012, thick=0.018):
    """A garment cut from the body's own faces (keep_face(center, normal)),
    pushed out along the normals and given thickness. It copies the body's
    weights, so it moves with the rig instead of clipping through it."""
    import bmesh
    me = body.data.copy()
    me.name = name
    o = bpy.data.objects.new(name, me)
    _COLL.objects.link(o)
    for g in body.vertex_groups:
        o.vertex_groups.new(name=g.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    kill = [f for f in bm.faces if not keep_face(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co += v.normal * push
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(mat(key))
    sol = o.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
        bpy.ops.object.modifier_apply(modifier="solid")
    o.parent = arm
    o.modifiers.new("rig", "ARMATURE").object = arm
    return o


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


# ---------------------------------------------------------------- goblin runner
GOBLIN_SKIN = "#9fb84a"

GOBLIN_NODES = {
    "pelvis": ((0.0, 0, 0.5), 0.15),
    "belly": ((0.15, 0, 0.6), 0.19),
    "chest": ((0.3, 0, 0.76), 0.16),
    "yoke": ((0.42, 0, 0.85), 0.12),
    "neck": ((0.53, 0, 0.89), 0.065),
    "skull": ((0.65, 0, 0.98), 0.17),
    "brow": ((0.77, 0, 0.99), 0.105),
    "snout": ((0.83, 0, 0.91), 0.07),
    "nose": ((0.92, 0, 0.86), 0.048),
    "jaw": ((0.71, 0, 0.85), 0.095),
    "chin": ((0.81, 0, 0.8), 0.06),
    "ear_root.L": ((0.64, 0.14, 1.0), 0.05),
    "ear_mid.L": ((0.52, 0.3, 1.05), 0.075),
    "ear_tip.L": ((0.36, 0.48, 1.1), 0.02),
    "shoulder.L": ((0.42, 0.17, 0.84), 0.075),
    "bicep.L": ((0.46, 0.22, 0.72), 0.055),
    "elbow.L": ((0.5, 0.25, 0.61), 0.042),
    "forearm.L": ((0.6, 0.25, 0.53), 0.052),
    "wrist.L": ((0.69, 0.24, 0.47), 0.032),
    "palm.L": ((0.75, 0.24, 0.44), 0.048),
    "finger1.L": ((0.83, 0.205, 0.41), 0.02), "tip1.L": ((0.88, 0.2, 0.38), 0.012),
    "finger2.L": ((0.84, 0.24, 0.4), 0.021), "tip2.L": ((0.9, 0.24, 0.37), 0.012),
    "finger3.L": ((0.83, 0.275, 0.41), 0.02), "tip3.L": ((0.88, 0.28, 0.38), 0.012),
    "thumb.L": ((0.77, 0.195, 0.48), 0.02), "thumbtip.L": ((0.82, 0.185, 0.49), 0.012),
    "hip.L": ((0.02, 0.11, 0.46), 0.09),
    "thigh.L": ((0.1, 0.14, 0.37), 0.085),
    "knee.L": ((0.17, 0.15, 0.28), 0.05),
    "calf.L": ((0.12, 0.15, 0.19), 0.062),
    "ankle.L": ((0.05, 0.15, 0.09), 0.034),
    "heel.L": ((0.01, 0.15, 0.045), 0.04),
    "ball.L": ((0.14, 0.15, 0.035), 0.045),
    "toe1.L": ((0.22, 0.115, 0.03), 0.022),
    "toe2.L": ((0.24, 0.15, 0.03), 0.024),
    "toe3.L": ((0.22, 0.185, 0.03), 0.022),
}
GOBLIN_EDGES = [
    ("pelvis", "belly"), ("belly", "chest"), ("chest", "yoke"), ("yoke", "neck"),
    ("neck", "skull"), ("skull", "brow"), ("brow", "snout"), ("snout", "nose"),
    ("neck", "jaw"), ("jaw", "chin"),
    ("skull", "ear_root.L"), ("ear_root.L", "ear_mid.L"), ("ear_mid.L", "ear_tip.L"),
    ("yoke", "shoulder.L"), ("shoulder.L", "bicep.L"), ("bicep.L", "elbow.L"),
    ("elbow.L", "forearm.L"), ("forearm.L", "wrist.L"), ("wrist.L", "palm.L"),
    ("palm.L", "finger1.L"), ("finger1.L", "tip1.L"), ("palm.L", "finger2.L"), ("finger2.L", "tip2.L"),
    ("palm.L", "finger3.L"), ("finger3.L", "tip3.L"), ("palm.L", "thumb.L"), ("thumb.L", "thumbtip.L"),
    ("pelvis", "hip.L"), ("hip.L", "thigh.L"), ("thigh.L", "knee.L"), ("knee.L", "calf.L"),
    ("calf.L", "ankle.L"), ("ankle.L", "heel.L"), ("heel.L", "ball.L"),
    ("ball.L", "toe1.L"), ("ball.L", "toe2.L"), ("ball.L", "toe3.L"),
]
# rig: (name, parent, head, tail); the pose functions below use these names
GOBLIN_BONES = [
    ("hips", None, (0.0, 0, 0.5), (0.15, 0, 0.6)),
    ("spine", "hips", (0.15, 0, 0.6), (0.3, 0, 0.76)),
    ("chest", "spine", (0.3, 0, 0.76), (0.42, 0, 0.85)),
    ("neck", "chest", (0.42, 0, 0.85), (0.53, 0, 0.89)),
    ("head", "neck", (0.53, 0, 0.89), (0.82, 0, 0.95)),
    ("ear.L", "head", (0.64, 0.14, 1.0), (0.36, 0.48, 1.1)),
    ("ear.R", "head", (0.64, -0.14, 1.0), (0.36, -0.48, 1.1)),
    ("thigh.L", "hips", (0.02, 0.11, 0.46), (0.17, 0.15, 0.28)),
    ("shin.L", "thigh.L", (0.17, 0.15, 0.28), (0.05, 0.15, 0.09)),
    ("foot.L", "shin.L", (0.05, 0.15, 0.09), (0.24, 0.15, 0.03)),
    ("thigh.R", "hips", (0.02, -0.11, 0.46), (0.17, -0.15, 0.28)),
    ("shin.R", "thigh.R", (0.17, -0.15, 0.28), (0.05, -0.15, 0.09)),
    ("foot.R", "shin.R", (0.05, -0.15, 0.09), (0.24, -0.15, 0.03)),
    ("upper_arm.L", "chest", (0.42, 0.17, 0.84), (0.5, 0.25, 0.61)),
    ("forearm.L", "upper_arm.L", (0.5, 0.25, 0.61), (0.69, 0.24, 0.47)),
    ("hand.L", "forearm.L", (0.69, 0.24, 0.47), (0.9, 0.24, 0.37)),
    ("upper_arm.R", "chest", (0.42, -0.17, 0.84), (0.5, -0.25, 0.61)),
    ("forearm.R", "upper_arm.R", (0.5, -0.25, 0.61), (0.69, -0.24, 0.47)),
    ("hand.R", "forearm.R", (0.69, -0.24, 0.47), (0.9, -0.24, 0.37)),
]


def goblin_sculpt(o):
    lateral = lambda co, side: co.y * side > 0.12
    # leaf ears, flattened in a plane tilted between level and upright so
    # they read broad from the game's high camera and from the side
    brush_flatten(o, (0.52, 0.3, 1.05), 0.26, (0.35, 0.2, -0.9), 0.3, mask=lateral, mirror=True)
    # hooked nose: tip pulled down
    brush_move(o, (0.95, 0, 0.86), 0.06, (0.0, 0.0, -0.02))
    # wide skull, slightly low brow
    brush_scale(o, (0.66, 0, 0.97), 0.22, (1.0, 1.15, 0.95))
    # pot belly, hunched back
    brush_move(o, (0.17, 0, 0.56), 0.2, (0.035, 0.0, -0.02))
    brush_move(o, (0.3, 0, 0.86), 0.16, (-0.02, 0.0, 0.03))
    # flat feet and palms
    brush_flatten(o, (0.13, 0.15, 0.035), 0.14, (0, 0, 1), 0.55,
                  mask=lambda co, side: co.z < 0.08 and co.y * side > 0.05, mirror=True)
    brush_flatten(o, (0.8, 0.24, 0.42), 0.09, (0, 1, 0), 0.6,
                  mask=lambda co, side: co.x > 0.72 and co.y * side > 0.15, mirror=True)


def goblin_dress(body, arm):
    # ragged leather vest over the back and shoulders, open at the front
    shell(body, arm, "vest", lambda c, n: c.z > 0.74 and c.x < 0.47 and abs(c.y) < 0.2
          and not (c.x > 0.2 and n.x > 0.3), "#7a4a26", push=0.012, thick=0.02)
    # shorts over the pelvis and the tops of the thighs, and a belt
    shell(body, arm, "shorts", lambda c, n: 0.36 < c.z < 0.57 and c.x < 0.3, "#5a3a26", push=0.01, thick=0.016)
    shell(body, arm, "belt", lambda c, n: 0.53 < c.z < 0.585 and c.x < 0.34, "#3b3245", push=0.026, thick=0.012)


def goblin_props(arm):
    """Face, buckle and dagger, each rigid on one bone. Placed by casting rays
    at the finished body so they sit on its surface."""
    body = bpy.data.objects["body"]
    for s in (-1, 1):
        p, _ = surface_point(body, (1.4, s * 0.08, 0.955), (-1, 0, 0))
        on_bone(arm, "head", lambda p=p: ellipsoid(p.x - 0.02, p.y, p.z, 0.046, 0.048, 0.044, "#ffe36a", glow=True))
        on_bone(arm, "head", lambda p=p: ellipsoid(p.x + 0.02, p.y, p.z, 0.012, 0.018, 0.024, "eye"))
        t, _ = surface_point(body, (1.4, s * 0.04, 0.83), (-1, 0, 0))
        on_bone(arm, "head", lambda t=t: cone_at(t + Vector((-0.012, 0, -0.005)), 0.014, 0.05, "white", (0.35, 0, 1), n=8))
    m, _ = surface_point(body, (1.4, 0.0, 0.865), (-1, 0, 0))
    on_bone(arm, "head", lambda: ellipsoid(m.x - 0.004, 0, m.z, 0.012, 0.06, 0.008, "eye"))
    b, _ = surface_point(body, (1.4, 0.0, 0.557), (-1, 0, 0))
    on_bone(arm, "hips", lambda: box(b.x + 0.02, 0, b.z - 0.03, 0.02, 0.07, 0.06, "gold"))
    # loincloth flap hanging from the belt front
    on_bone(arm, "hips", lambda: poly([(b.x + 0.022, -0.06, b.z - 0.01), (b.x + 0.022, 0.06, b.z - 0.01),
                                       (b.x + 0.05, 0.045, b.z - 0.2), (b.x + 0.05, -0.045, b.z - 0.2)], "#5a3a26"))
    # dagger in the far hand, held low
    h1 = arm.data.bones["hand.L"].tail_local.copy()
    on_bone(arm, "hand.L", lambda: limb(h1 + Vector((-0.04, 0, 0.0)), h1 + Vector((0.22, 0, 0.0)), 0.026, 0.006, "steel"))
    on_bone(arm, "hand.L", lambda: box(h1.x - 0.07, h1.y, h1.z - 0.03, 0.04, 0.03, 0.06, "#5a3a26"))


SPECS = {
    "goblin_runner": dict(nodes=GOBLIN_NODES, edges=GOBLIN_EDGES, root="pelvis", bones=GOBLIN_BONES,
                          skin=GOBLIN_SKIN, sculpt=goblin_sculpt, dress=goblin_dress, props=goblin_props, size=2.0),
}


# ---------------------------------------------------------------- build
def _armature(bones):
    ad = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", ad)
    _COLL.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, h, t in bones:
        eb = ad.edit_bones.new(name)
        eb.head, eb.tail = Vector(h), Vector(t)
        eb.roll = 0.0
        if parent:
            eb.parent = ad.edit_bones[parent]
            eb.use_connect = (Vector(h) - ad.edit_bones[parent].tail).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def build_rigged(mid):
    """Skin hull -> sculpt brushes -> rig with heat weights -> fitted clothes
    -> rigid props."""
    spec = SPECS[mid]
    clear_collection(COLL)
    solo_collections([COLL])
    for a in list(bpy.data.armatures):
        if a.users == 0:
            bpy.data.armatures.remove(a)
    body = skin_body(spec["nodes"], spec["edges"], spec["skin"], spec["root"])
    spec["sculpt"](body)
    body.data.update()
    arm = _armature(spec["bones"])
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    spec["dress"](body, arm)
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
