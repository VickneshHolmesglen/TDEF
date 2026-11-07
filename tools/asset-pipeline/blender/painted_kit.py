"""Shared painted-vector Blender kit (ADR-0045): materials, primitives and
render setup used by sanctuary_buildings.py and unit_kit.py.

Load it into a script's namespace before use:
    exec(open(r"G:/TDef/tools/asset-pipeline/blender/painted_kit.py").read())

Look: flat fill x faint brush grain, banded diffuse light (3-4 tones, the
same bands as painted_prop.gdshader), emitted so the bands stay crisp, and a
thin dark Freestyle outline. Colours are palette keys (PAL) or hex strings.
"""
import bpy, math

PAL = {
    "wall": "#f1e4c6", "stone": "#cdbfa3", "stone_dark": "#9e917b", "timber": "#7d5034",
    "wood": "#b07a43", "dark": "#3b3245", "gold": "#e9bb4c", "dirt": "#cfae80",
    "cobble": "#c2b69c", "grass": "#86c25b", "iron": "#6f7784", "hay": "#e6c86a",
    "cloth": "#e9ddc0", "water": "#5ab4e0", "steel": "#aab6c4", "leather": "#8a5a36",
    "skin": "#e9b98f", "hair": "#5a3a26", "eye": "#2a2230", "white": "#f6f1e6",
    "glow": "#ffb44a", "crystal": "#a6e6ff",
}
GLOWING = {"glow", "crystal"}
OUTLINE_COLOR = (0.16, 0.12, 0.17)


# ---------------------------------------------------------------- materials
def _hex(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def _ramp(nt, stops, interp):
    r = nt.nodes.new("ShaderNodeValToRGB")
    cr = r.color_ramp
    cr.interpolation = interp
    while len(cr.elements) > 1:
        cr.elements.remove(cr.elements[-1])
    cr.elements[0].position = stops[0][0]
    cr.elements[0].color = (*stops[0][1], 1)
    for p, c in stops[1:]:
        cr.elements.new(p).color = (*c, 1)
    return r


def _mix_mul(nt, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = "MULTIPLY"
    m.inputs["Factor"].default_value = 1.0
    nt.links.new(a, m.inputs[6])
    nt.links.new(b, m.inputs[7])
    return m.outputs[2]


_MATS = {}


def mat(key, glow=False):
    """Painted material for a palette key or hex colour ("holdout" cuts alpha)."""
    cache_key = key + ("*" if glow else "")
    if cache_key in _MATS and _MATS[cache_key].name in bpy.data.materials:
        return _MATS[cache_key]
    m = bpy.data.materials.new("pk_" + cache_key.lstrip("#"))
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if key == "holdout":
        h = nt.nodes.new("ShaderNodeHoldout")
        nt.links.new(h.outputs[0], out.inputs["Surface"])
        _MATS[cache_key] = m
        return m
    hexcol = PAL.get(key, key)
    col = nt.nodes.new("ShaderNodeRGB")
    col.outputs[0].default_value = (*_hex(hexcol), 1)
    if glow or key in GLOWING:
        em = _node(nt, "ShaderNodeEmission", Strength=1.6)
        nt.links.new(col.outputs[0], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        _MATS[cache_key] = m
        return m
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.0, 2.0, 9.0)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    nz = _node(nt, "ShaderNodeTexNoise", Scale=4.0, Detail=3.0)
    nt.links.new(mp.outputs[0], nz.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.93
    mr.inputs["To Max"].default_value = 1.07
    nt.links.new(nz.outputs["Fac"], mr.inputs[0])
    albedo = _mix_mul(nt, col.outputs[0], mr.outputs[0])
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    nt.links.new(albedo, diff.inputs["Color"])
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs["Color"], bw.inputs[0])
    lum = _node(nt, "ShaderNodeMath")
    lum.operation = "DIVIDE"
    lum.inputs[1].default_value = max(0.05, sum(_hex(hexcol)) / 3.0)
    nt.links.new(bw.outputs[0], lum.inputs[0])
    r = _ramp(nt, [(0.0, (0.55, 0.55, 0.68)), (0.3, (0.74, 0.73, 0.82)),
                   (0.55, (0.97, 0.96, 0.93)), (0.85, (1.08, 1.05, 0.98))], "CONSTANT")
    nt.links.new(lum.outputs[0], r.inputs[0])
    shaded = _mix_mul(nt, albedo, r.outputs[0])
    em = _node(nt, "ShaderNodeEmission", Strength=1.0)
    nt.links.new(shaded, em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    _MATS[cache_key] = m
    return m


# ---------------------------------------------------------------- geometry
_COLL = None
PARENT = None  # objects made while set are parented to it (keep world placement)


def use_collection(name):
    """Makes `name` the target collection (created and linked if missing)."""
    global _COLL
    _COLL = bpy.data.collections.get(name)
    if _COLL is None:
        _COLL = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(_COLL)
    return _COLL


def clear_collection(name):
    c = use_collection(name)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    return c


def _obj(name, verts, faces, key, smooth=False, glow=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    o.data.materials.append(mat(key, glow))
    _COLL.objects.link(o)
    return o


def _attach(o):
    if PARENT is not None:
        mw = o.matrix_world.copy()
        o.parent = PARENT
        o.matrix_parent_inverse = PARENT.matrix_world.inverted()
        o.matrix_world = mw
    return o


def _rot(x, y, a):
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c


def box(x, y, z, w, d, h, key, rot=0.0):
    """Box with its base centre at (x, y, z)."""
    pts = [_rot(px, py, rot) for px, py in [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]]
    v = [(x + px, y + py, z) for px, py in pts] + [(x + px, y + py, z + h) for px, py in pts]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return _attach(_obj("box", v, f, key))


def prism(x, y, z, r0, r1, h, key, n=16, rot=0.0, smooth=False):
    """n-sided frustum standing on (x, y, z); cone when r1 == 0."""
    v = []
    for ring, r in ((0, r0), (1, r1)):
        for i in range(n):
            a = rot + math.tau * i / n
            v.append((r * math.cos(a), r * math.sin(a), h * ring))
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if h < 0:
        f = [tuple(reversed(face)) for face in f]
    o = _obj("prism", v, f, key, smooth)
    o.location = (x, y, z)
    return _attach(o)


def ellipsoid(x, y, z, rx, ry, rz, key, seg=16, rings=10, glow=False):
    """Smooth-shaded ellipsoid centred at (x, y, z)."""
    v = [(0, 0, -rz)]
    for j in range(1, rings):
        t = math.pi * j / rings - math.pi / 2
        for i in range(seg):
            a = math.tau * i / seg
            v.append((rx * math.cos(t) * math.cos(a), ry * math.cos(t) * math.sin(a), rz * math.sin(t)))
    v.append((0, 0, rz))
    f = [(0, 1 + (i + 1) % seg, 1 + i) for i in range(seg)]
    for j in range(rings - 2):
        a0, b0 = 1 + j * seg, 1 + (j + 1) * seg
        f += [(a0 + i, a0 + (i + 1) % seg, b0 + (i + 1) % seg, b0 + i) for i in range(seg)]
    top, last = len(v) - 1, 1 + (rings - 2) * seg
    f += [(last + i, last + (i + 1) % seg, top) for i in range(seg)]
    o = _obj("ell", v, f, key, smooth=True, glow=glow)
    o.location = (x, y, z)
    return _attach(o)


def limb(p0, p1, r0, r1, key, n=12, smooth=True):
    """Tapered round segment from point p0 (radius r0) to p1 (radius r1),
    with ball caps so joints read as rounded."""
    from mathutils import Vector
    a, b = Vector(p0), Vector(p1)
    d = b - a
    o = _obj("limb", *_tube(d.length, r0, r1, n), key, smooth)
    o.location = a
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    _attach(o)
    ellipsoid(a.x, a.y, a.z, r0, r0, r0, key, 12, 8)
    ellipsoid(b.x, b.y, b.z, r1, r1, r1, key, 12, 8)
    return o


def _tube(length, r0, r1, n):
    v = [(r0 * math.cos(math.tau * i / n), r0 * math.sin(math.tau * i / n), 0) for i in range(n)]
    v += [(r1 * math.cos(math.tau * i / n), r1 * math.sin(math.tau * i / n), length) for i in range(n)]
    f = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return v, f


def pivot(name, loc, parent=None):
    """Empty used as an animation joint; later parts attach to it via PARENT."""
    e = bpy.data.objects.new(name, None)
    e.location = loc
    _COLL.objects.link(e)
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
    bpy.context.view_layer.update()
    return e


def poly(points, key, glow=False):
    """Flat polygon (two-sided)."""
    o = _obj("poly", [tuple(p) for p in points], [tuple(range(len(points)))], key, glow=glow)
    return _attach(o)


def rot_obj(o, rx=0.0, ry=0.0, rz=0.0):
    o.rotation_euler = (rx, ry, rz)
    return o


def cone_at(p, r, h, key, axis=(0, 0, 1), n=8, glow=False):
    """Cone from base centre p along `axis` (any direction)."""
    o = prism(p[0], p[1], p[2], r, 0.0, h, key, n=n)
    if glow:
        o.data.materials[0] = mat(key, True)
    o.rotation_mode = "QUATERNION"
    from mathutils import Vector
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    return o


# ---------------------------------------------------------------- render
def setup_render(res_x, res_y, line_px=2.4, collection=None, sun_rot=(42, -14, -28)):
    """Eevee, transparent film, banded-look world, sun and Freestyle outline.
    `collection` limits outlines to one collection (holdout bodies stay unlined)."""
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = res_x, res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = line_px
    vl = sc.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    if not fs.linesets:
        fs.linesets.new("outline")
    ls = fs.linesets[0]
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_by_collection = collection is not None
    if collection is not None:
        ls.collection = bpy.data.collections.get(collection)
    ls.linestyle.color = OUTLINE_COLOR
    ls.linestyle.thickness = line_px
    fs.crease_angle = math.radians(120)
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.45, 0.47, 0.55, 1)
    bg.inputs["Strength"].default_value = 0.6
    sun = bpy.data.objects.get("pk_sun")
    if sun is None:
        sun = bpy.data.objects.new("pk_sun", bpy.data.lights.new("pk_sun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 3.0
    sun.data.angle = math.radians(2)
    sun.rotation_euler = tuple(math.radians(a) for a in sun_rot)
    return sc


def ortho_camera(pitch_deg, yaw_deg, target, ortho_scale, dist=30.0):
    """Orthographic camera looking at `target` from yaw (0 = from -Y) and pitch."""
    sc = bpy.context.scene
    cam = bpy.data.objects.get("pk_cam")
    if cam is None:
        cam = bpy.data.objects.new("pk_cam", bpy.data.cameras.new("pk_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho_scale
    p, y = math.radians(pitch_deg), math.radians(yaw_deg)
    tx, ty, tz = target
    cam.location = (tx + dist * math.cos(p) * math.sin(y), ty - dist * math.cos(p) * math.cos(y),
                    tz + dist * math.sin(p))
    cam.rotation_euler = (math.pi / 2 - p, 0, y)
    sc.camera = cam
    return cam


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def solo_collections(names):
    """Renders only these collections: every other child collection of the
    scene is excluded from the view layer (camera and sun live in the scene
    root collection and stay)."""
    for lc in bpy.context.view_layer.layer_collection.children:
        lc.exclude = lc.name not in names
