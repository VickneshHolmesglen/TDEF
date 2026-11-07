"""Painted-vector unit sprites (ADR-0045 phase 2): monsters and the hero.

Monsters: each creature is built from primitives by a function of a pose (no
armature: joint positions are computed with simple forward kinematics, and the
creature is rebuilt per frame). Frames render side-on, facing +X (sheets face
right; MonsterInstance flips them). Strip layout matches the existing
CreatureAtlasMappingResource clips:
    standard/elite: 5 frames  = idle, walk x4
    bosses:        14 frames  = idle, walk x4, attack_prepare x4, attack x5
Hero: front-facing base body plus one full-canvas overlay per gear item,
rendered over the body as a holdout so every layer lines up with the base.

    exec(open(r"G:/TDef/tools/asset-pipeline/blender/unit_kit.py").read())
    render_monsters()            # or render_monsters(["rift_hound"])
    render_hero()                # base body + every gear overlay
Then: python tools/asset-pipeline/blender/compose_units.py
"""
import bpy, math
from mathutils import Vector

exec(open(r"G:/TDef/tools/asset-pipeline/blender/painted_kit.py").read())

RAW = r"G:/TDef/assets/source/3d/units/"
MONSTER_PITCH = 16.0
MONSTER_YAW = 18.0
FRAME_PX = 360            # raw frame render (square); composed down later
STILL_PX = 900
WALK_PHASES = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]
TAU = math.tau


def _v(x, y, z):
    return Vector((x, y, z))


def _dir(a):
    """Unit vector in the XZ plane, `a` radians from straight down toward +X."""
    return _v(math.sin(a), 0.0, -math.cos(a))


# ================================================================ rigs
def biped(P, pose):
    """Two legs, torso, two arms, head. Returns joint positions for extras.
    P keys: hip_h thigh shin leg_r hip_w torso_len torso_rx torso_ry torso_rz lean
            sh_w upper lower arm_r head_r head_fwd head_up leg tor arm head foot
            optional: stride arm_swing knee bob blocky foot_len arm_rest
    pose: {"phase": float|None, "near_arm": (b, e)|None, "far_arm": (b, e)|None}"""
    ph = pose.get("phase")
    walking = ph is not None
    stride = P.get("stride", 0.42)
    bob = P.get("bob", 0.05) * abs(math.cos(ph)) if walking else 0.0
    blocky = P.get("blocky", False)
    n = 6 if blocky else 12
    hip = _v(0, 0, P["hip_h"] + bob)
    J = {"hip": hip}
    for side, sgn, off in (("near", -1, 0.0), ("far", 1, math.pi)):
        psi = (ph + off) if walking else 0.0
        a = stride * math.sin(psi) if walking else (0.08 * -sgn)
        k = (0.12 + P.get("knee", 0.7) * max(0.0, math.cos(psi))) if walking else 0.12
        hs = hip + _v(0, sgn * P["hip_w"], 0)
        knee = hs + _dir(a) * P["thigh"]
        ankle = knee + _dir(a - k) * P["shin"]
        r = P["leg_r"]
        limb(hs, knee, r, r * 0.85, P["leg"], n=n, smooth=not blocky)
        limb(knee, ankle, r * 0.85, r * 0.7, P["leg"], n=n, smooth=not blocky)
        fl = P.get("foot_len", r * 2.6)
        if blocky:
            box(ankle.x + fl * 0.25, ankle.y, ankle.z - r * 0.7, fl, r * 1.8, r * 1.1, P["foot"])
        else:
            ellipsoid(ankle.x + fl * 0.3, ankle.y, ankle.z - r * 0.25, fl * 0.55, r * 0.8, r * 0.55, P["foot"])
        J["ankle_" + side] = ankle
        J["knee_" + side] = knee
    lean = P["lean"]
    up = _v(math.sin(lean), 0, math.cos(lean))
    sh = hip + up * P["torso_len"]
    mid = hip + up * (P["torso_len"] * 0.5)
    if blocky:
        o = box(0, 0, -P["torso_rz"], P["torso_rx"] * 2, P["torso_ry"] * 2, P["torso_rz"] * 2, P["tor"])
        o.location = mid
        o.rotation_euler = (0, lean, 0)
    else:
        rot_obj(ellipsoid(mid.x, mid.y, mid.z, P["torso_rx"], P["torso_ry"], P["torso_rz"], P["tor"]), ry=lean)
    J.update(sh=sh, mid=mid, up=up)
    swing = P.get("arm_swing", 0.5)
    for side, sgn, off in (("near", -1, math.pi), ("far", 1, 0.0)):
        given = pose.get(side + "_arm")
        if given is not None:
            b, e = given
        elif walking:
            b, e = swing * math.sin(ph + off), P.get("arm_rest", 0.5)
        else:
            b, e = 0.1, P.get("arm_rest", 0.5)
        ss = sh + _v(0, sgn * P["sh_w"], 0)
        elbow = ss + _dir(b) * P["upper"]
        hand = elbow + _dir(b + e) * P["lower"]
        r = P["arm_r"]
        limb(ss, elbow, r, r * 0.85, P["arm"], n=n, smooth=not blocky)
        limb(elbow, hand, r * 0.85, r * 0.75, P["arm"], n=n, smooth=not blocky)
        hk = P.get("hand", P["arm"])
        if blocky:
            box(hand.x, hand.y, hand.z - r, r * 2, r * 2, r * 1.8, hk)
        else:
            ellipsoid(hand.x, hand.y, hand.z, r * 1.15, r * 1.1, r * 1.15, hk)
        J["hand_" + side] = hand
        J["elbow_" + side] = elbow
        J["shoulder_" + side] = ss
        J["arm_" + side] = (b, e)
    head = sh + _v(P["head_fwd"], 0, P["head_up"])
    hr = P["head_r"]
    if blocky:
        box(head.x, head.y, head.z - hr, hr * 2, hr * 1.8, hr * 1.7, P["head"])
    else:
        ellipsoid(head.x, head.y, head.z, hr * 1.05, hr * 0.95, hr, P["head"])
    J["head"] = head
    return J


def eyes(J, P, key="eye", glow=False, size=0.06, spread=0.32, fwd=0.85, up=0.15):
    h, hr = J["head"], P["head_r"]
    for s in (-1, 1):
        ellipsoid(h.x + hr * fwd, h.y + s * hr * spread, h.z + hr * up, size, size, size * 1.2, key, 8, 6, glow=glow)


def quadruped(P, pose):
    """Horizontal body with four 2-segment legs, neck/head, tail."""
    ph = pose.get("phase")
    walking = ph is not None
    bob = P.get("bob", 0.04) * abs(math.sin(2 * ph)) if walking else 0.0
    body = _v(0, 0, P["leg_h"] + P["body_rz"] * 0.6 + bob)
    J = {"body": body}
    rot_obj(ellipsoid(body.x, body.y, body.z, P["body_rx"], P["body_ry"], P["body_rz"], P["body"]), ry=-0.08)
    legs = [("front", P["body_rx"] * 0.6, 0.0), ("back", -P["body_rx"] * 0.6, math.pi)]
    for name, lx, off in legs:
        for side, sgn, soff in (("near", -1, 0.0), ("far", 1, math.pi)):
            psi = (ph + off + soff) if walking else 0.0
            a = P.get("stride", 0.5) * math.sin(psi) if walking else 0.0
            k = (0.1 + 0.8 * max(0.0, math.cos(psi))) if walking else 0.1
            if name == "back":
                k = -k
            top = body + _v(lx, sgn * P["body_ry"] * 0.65, -P["body_rz"] * 0.3)
            L = top.z / 2.0
            mid = top + _dir(a) * L
            end = mid + _dir(a - k) * L
            limb(top, mid, P["leg_r"], P["leg_r"] * 0.8, P["leg"])
            limb(mid, end, P["leg_r"] * 0.8, P["leg_r"] * 0.6, P["leg"])
            ellipsoid(end.x + P["leg_r"] * 0.5, end.y, end.z, P["leg_r"] * 1.3, P["leg_r"] * 0.8, P["leg_r"] * 0.55, P["paw"])
    neck = body + _v(P["body_rx"] * 0.85, 0, P["body_rz"] * 0.6)
    head = neck + _v(P["head_r"] * 0.8, 0, P["head_r"] * 0.5 + bob * 0.5)
    limb(body + _v(P["body_rx"] * 0.5, 0, P["body_rz"] * 0.2), neck, P["body_rz"] * 0.6, P["head_r"] * 0.7, P["body"])
    ellipsoid(head.x, head.y, head.z, P["head_r"] * 1.1, P["head_r"] * 0.85, P["head_r"] * 0.85, P["body"])
    snout = head + _v(P["head_r"] * 1.2, 0, -P["head_r"] * 0.25)
    limb(head, snout, P["head_r"] * 0.6, P["head_r"] * 0.35, P["body"])
    ellipsoid(snout.x + P["head_r"] * 0.1, snout.y, snout.z + P["head_r"] * 0.08, P["head_r"] * 0.2, P["head_r"] * 0.2, P["head_r"] * 0.15, "eye")
    J.update(head=head, neck=neck, snout=snout)
    tail0 = body + _v(-P["body_rx"] * 0.9, 0, P["body_rz"] * 0.3)
    wag = 0.25 * math.sin(ph * 2) if walking else 0.0
    limb(tail0, tail0 + _v(-P["tail"] * math.cos(0.6 + wag), 0, P["tail"] * math.sin(0.6 + wag)), P["leg_r"] * 0.7, 0.02, P["body"])
    return J


def crawler_legs(center, n, spread_x, reach, height, r, key, pose, lift=0.12):
    ph = pose.get("phase")
    for i in range(n):
        x = center.x - spread_x / 2 + spread_x * i / max(1, n - 1)
        for side, sgn in (("near", -1), ("far", 1)):
            psi = (ph or 0.0) + (i + (0 if side == "near" else 1)) * math.pi
            dz = lift * max(0.0, math.sin(psi)) if ph is not None else 0.0
            dx = 0.12 * math.cos(psi) if ph is not None else 0.0
            root = _v(x, center.y + sgn * reach * 0.3, center.z)
            knee = _v(x + dx * 0.5, center.y + sgn * reach * 0.8, center.z + height * 0.35 + dz)
            foot = _v(x + dx, center.y + sgn * reach * 1.05, dz * 0.4)
            limb(root, knee, r, r * 0.8, key, n=8)
            limb(knee, foot, r * 0.8, r * 0.35, key, n=8)


# ================================================================ creatures
def _goblin(pose, skin, tunic, scale=1.0):
    s = scale
    P = dict(hip_h=0.55 * s, thigh=0.3 * s, shin=0.3 * s, leg_r=0.08 * s, hip_w=0.12 * s,
             torso_len=0.5 * s, torso_rx=0.22 * s, torso_ry=0.2 * s, torso_rz=0.3 * s, lean=0.38,
             sh_w=0.2 * s, upper=0.26 * s, lower=0.26 * s, arm_r=0.065 * s, head_r=0.25 * s,
             head_fwd=0.14 * s, head_up=0.16 * s, leg=skin, tor=tunic, arm=skin, head=skin, foot="leather",
             stride=0.55, arm_swing=0.7, bob=0.06 * s)
    J = biped(P, pose)
    h, hr = J["head"], P["head_r"]
    for sgn in (-1, 1):  # ears
        cone_at(h + _v(-hr * 0.1, sgn * hr * 0.8, hr * 0.25), hr * 0.28, hr * 1.1, skin, (-0.4, sgn * 1.0, 0.45), n=6)
    cone_at(h + _v(hr * 0.9, 0, -hr * 0.05), hr * 0.18, hr * 0.5, skin, (1, 0, -0.2), n=8)  # nose
    eyes(J, P, "#ffe36a", glow=True, size=0.045 * s, spread=0.38, fwd=0.82, up=0.25)
    ellipsoid(J["hip"].x, 0, J["hip"].z - 0.02, 0.22 * s, 0.2 * s, 0.1 * s, "leather")  # belt/loin
    return J, P


def goblin_runner(pose):
    J, P = _goblin(pose, "#82b44c", "#8a5a36")
    hd = J["hand_near"]
    limb(hd, hd + _v(0.26, 0, 0.05), 0.025, 0.006, "steel")  # dagger
    ellipsoid(J["sh"].x, 0, J["sh"].z - 0.04, 0.17, 0.2, 0.08, "#c0463a")  # scarf


def goblin_mender(pose):
    J, P = _goblin(pose, "#93c562", "#3f8f86")
    hf = J["hand_far"]
    limb(hf + _v(0, 0, -0.45), hf + _v(0.04, 0, 0.42), 0.025, 0.025, "wood")  # staff
    ellipsoid(hf.x + 0.04, hf.y, hf.z + 0.5, 0.09, 0.09, 0.09, "#9dff7a", glow=True)
    h = J["head"]
    ellipsoid(h.x - 0.04, h.y, h.z + 0.08, 0.27, 0.26, 0.22, "#e9ddc0")  # hood
    cone_at(J["hip"] + _v(0, 0, 0.05), 0.26, -0.3, "#3f8f86", (0, 0, 1), n=12)  # robe skirt


def goblin_drummer(pose):
    J, P = _goblin(pose, "#7aa94a", "#b9573d")
    c = J["mid"] + _v(0.22, -0.02, -0.04)
    o = prism(c.x, c.y, c.z - 0.0, 0.17, 0.17, 0.14, "#d9a066", n=14)
    o.rotation_euler = (0, math.pi / 2, 0)
    for dx in (-0.005, 0.135):
        o = prism(c.x + dx, c.y, c.z, 0.175, 0.175, 0.012, "#7d5034", n=14)
        o.rotation_euler = (0, math.pi / 2, 0)
    for hd in (J["hand_near"], J["hand_far"]):
        limb(hd, hd + _v(0.12, 0, 0.16), 0.014, 0.014, "wood")
        ellipsoid(hd.x + 0.12, hd.y, hd.z + 0.17, 0.03, 0.03, 0.03, "cloth")


def shade_stalker(pose):
    P = dict(hip_h=0.75, thigh=0.38, shin=0.38, leg_r=0.06, hip_w=0.1, torso_len=0.62, torso_rx=0.17,
             torso_ry=0.16, torso_rz=0.34, lean=0.42, sh_w=0.18, upper=0.34, lower=0.34, arm_r=0.05,
             head_r=0.19, head_fwd=0.16, head_up=0.14, leg="#2f2846", tor="#4b3c74", arm="#2f2846",
             head="#2a2340", foot="#2f2846", stride=0.6, arm_swing=0.4, arm_rest=0.9)
    J = biped(P, pose)
    sh = J["sh"]
    flow = 0.12 * math.sin(pose["phase"] * 2) if pose.get("phase") is not None else 0.0
    poly([sh + _v(-0.05, -0.2, 0.05), sh + _v(-0.05, 0.2, 0.05), J["hip"] + _v(-0.55 + flow, 0.25, -0.45),
          J["hip"] + _v(-0.7 + flow, 0, -0.35), J["hip"] + _v(-0.55 + flow, -0.25, -0.45)], "#3b2f5e")
    h = J["head"]
    cone_at(h + _v(-0.05, 0, 0.0), 0.24, 0.42, "#3b2f5e", (-0.6, 0, 1), n=10)  # hood
    eyes(J, P, "#d6b0ff", glow=True, size=0.035, spread=0.35, fwd=0.95, up=0.05)
    for hd in (J["hand_near"], J["hand_far"]):
        for k in range(3):
            cone_at(hd + _v(0.03, (k - 1) * 0.03, -0.02), 0.012, 0.16, "#d6b0ff", (0.6, 0, -1), n=4, glow=True)


def armored_brute(pose):
    P = dict(hip_h=0.6, thigh=0.32, shin=0.3, leg_r=0.14, hip_w=0.2, torso_len=0.72, torso_rx=0.42,
             torso_ry=0.36, torso_rz=0.45, lean=0.25, sh_w=0.4, upper=0.36, lower=0.36, arm_r=0.12,
             head_r=0.2, head_fwd=0.2, head_up=0.1, leg="#8c9a68", tor="#8c9a68", arm="#8c9a68",
             head="#8c9a68", foot="#5a4a3a", stride=0.4, arm_swing=0.35, bob=0.04)
    J = biped(P, pose)
    m = J["mid"]
    rot_obj(ellipsoid(m.x + 0.06, m.y, m.z + 0.05, 0.44, 0.39, 0.38, "#7a8290"), ry=P["lean"])  # breastplate
    for side in ("near", "far"):
        s = J["shoulder_" + side]
        ellipsoid(s.x, s.y, s.z + 0.04, 0.2, 0.2, 0.15, "#6a7280")
        for k in range(2):
            cone_at(s + _v(-0.05 + k * 0.1, 0, 0.13), 0.04, 0.14, "#d8d2c4", (0, 0, 1), n=6)
    h = J["head"]
    ellipsoid(h.x - 0.02, h.y, h.z + 0.06, 0.23, 0.22, 0.17, "#6a7280")  # helm
    eyes(J, P, "#ffcf5a", glow=True, size=0.03, spread=0.35, fwd=0.95, up=0.0)
    for sgn in (-1, 1):
        cone_at(h + _v(0.15, sgn * 0.08, -0.12), 0.025, 0.1, "white", (0, 0, 1), n=5)  # tusks
    hd = J["hand_near"]
    limb(hd + _v(-0.1, 0, -0.08), hd + _v(0.35, 0, 0.3), 0.04, 0.05, "timber")  # mace
    ellipsoid(hd.x + 0.38, hd.y, hd.z + 0.33, 0.12, 0.12, 0.12, "#6a7280")


def forest_troll_elite(pose):
    P = dict(hip_h=0.7, thigh=0.38, shin=0.36, leg_r=0.12, hip_w=0.17, torso_len=0.85, torso_rx=0.34,
             torso_ry=0.3, torso_rz=0.5, lean=0.45, sh_w=0.32, upper=0.5, lower=0.5, arm_r=0.1,
             head_r=0.2, head_fwd=0.24, head_up=0.0, leg="#6f8f4a", tor="#6f8f4a", arm="#6f8f4a",
             head="#6f8f4a", foot="#4c5f33", stride=0.4, arm_swing=0.3, arm_rest=0.35)
    J = biped(P, pose)
    for p, r in ((J["sh"] + _v(-0.1, 0, 0.12), 0.24), (J["head"] + _v(-0.05, 0, 0.16), 0.15),
                 (J["mid"] + _v(-0.25, 0, 0.1), 0.2)):
        ellipsoid(p.x, p.y, p.z, r, r * 1.1, r * 0.7, "#4f7a35")  # moss
    h = J["head"]
    cone_at(h + _v(0.17, 0, -0.04), 0.07, 0.18, "#6f8f4a", (1, 0, -0.5), n=8)  # nose
    eyes(J, P, "#ffe36a", glow=True, size=0.03, spread=0.4, fwd=0.85, up=0.2)
    hd = J["hand_near"]
    limb(hd + _v(-0.05, 0, 0.05), hd + _v(0.5, 0, -0.35), 0.06, 0.13, "#7d5034")  # log club
    ellipsoid(hd.x + 0.5, hd.y, hd.z - 0.35, 0.14, 0.14, 0.14, "#7d5034")


def iron_colossus_elite(pose):
    P = dict(hip_h=0.62, thigh=0.32, shin=0.3, leg_r=0.15, hip_w=0.22, torso_len=0.8, torso_rx=0.36,
             torso_ry=0.32, torso_rz=0.4, lean=0.1, sh_w=0.46, upper=0.36, lower=0.38, arm_r=0.15,
             head_r=0.17, head_fwd=0.06, head_up=0.16, leg="#7d8794", tor="#7d8794", arm="#7d8794",
             head="#6a7380", foot="#5c636e", stride=0.3, arm_swing=0.25, bob=0.02, blocky=True)
    J = biped(P, pose)
    m = J["mid"]
    o = ellipsoid(m.x + 0.37, m.y, m.z + 0.08, 0.05, 0.13, 0.13, "glow")
    for p in (m + _v(0.36, -0.2, -0.25), J["shoulder_near"] + _v(0.05, -0.1, -0.05)):
        box(p.x, p.y, p.z, 0.14, 0.04, 0.12, "#a0623a")  # rust
    h = J["head"]
    box(h.x + 0.17, h.y, h.z - 0.02, 0.03, 0.22, 0.05, "glow")  # eye slit
    for side in ("near", "far"):
        s = J["shoulder_" + side]
        box(s.x, s.y, s.z - 0.05, 0.42, 0.34, 0.2, "#6a7380")


def goblin_warlord_boss(pose):
    J, P = _goblin(pose, "#79a648", "#4a4652", scale=1.7)
    m = J["mid"]
    rot_obj(ellipsoid(m.x + 0.04, m.y, m.z + 0.05, 0.4, 0.37, 0.45, "#4a4652"), ry=P["lean"])
    rot_obj(ellipsoid(m.x + 0.05, m.y, m.z - 0.1, 0.41, 0.38, 0.07, "gold"), ry=P["lean"])
    for side in ("near", "far"):
        s = J["shoulder_" + side]
        ellipsoid(s.x, s.y, s.z + 0.04, 0.17, 0.17, 0.13, "#4a4652")
        cone_at(s + _v(0, 0, 0.1), 0.05, 0.18, "gold", (0, 0, 1), n=6)
    h = J["head"]
    ellipsoid(h.x - 0.03, h.y, h.z + 0.12, 0.4, 0.38, 0.27, "#4a4652")  # helm
    for sgn in (-1, 1):
        cone_at(h + _v(0, sgn * 0.33, 0.24), 0.08, 0.42, "#efe2c4", (0.2, sgn * 0.7, 1), n=8)  # horns
    # banner on the back
    b0 = J["sh"] + _v(-0.35, 0.1, -0.3)
    limb(b0, b0 + _v(-0.1, 0, 1.5), 0.025, 0.025, "timber")
    t = b0 + _v(-0.1, 0, 1.45)
    poly([t, t + _v(-0.5, 0, 0), t + _v(-0.45, 0, -0.45), t + _v(-0.25, 0, -0.32), t + _v(0, 0, -0.5)], "#c0463a")
    # greataxe in the near hand
    hd = J["hand_near"]
    b, e = J["arm_near"]
    d = _dir(b + e + math.pi)  # haft continues past the hand, away from the elbow
    tip = hd + d * 0.75
    limb(hd - d * 0.35, tip, 0.035, 0.035, "timber")
    side_v = _v(d.z, 0, -d.x)
    poly([tip - d * 0.05, tip + side_v * 0.38 - d * 0.18, tip + side_v * 0.42 + d * 0.1,
          tip + side_v * 0.3 + d * 0.22, tip + d * 0.08], "steel")


def rift_sentinel_boss(pose):
    ph = pose.get("phase")
    hover = 0.08 * math.sin(ph) if ph is not None else 0.0
    base = _v(0, 0, 0.9 + hover)
    cone_at(base + _v(0, 0, 0.05), 0.28, -0.75, "#8a6ad6", (0, 0, 1), n=6, glow=False)  # shard tail
    cone_at(base + _v(0, 0, -0.55), 0.1, -0.3, "crystal", (0, 0, 1), n=6, glow=True)
    lean = 0.12
    up = _v(math.sin(lean), 0, math.cos(lean))
    mid = base + up * 0.45
    rot_obj(ellipsoid(mid.x, mid.y, mid.z, 0.36, 0.32, 0.48, "#d6a93e"), ry=lean)
    rot_obj(ellipsoid(mid.x + 0.1, mid.y, mid.z + 0.05, 0.3, 0.28, 0.3, "#5b3f9a"), ry=lean)
    ellipsoid(mid.x + 0.38, mid.y, mid.z + 0.1, 0.08, 0.08, 0.08, "crystal", glow=True)
    sh = base + up * 0.85
    head = sh + _v(0.08, 0, 0.25)
    ellipsoid(head.x, head.y, head.z, 0.2, 0.18, 0.24, "#d6a93e")
    box(head.x + 0.19, head.y, head.z - 0.01, 0.03, 0.22, 0.04, "crystal").data.materials[0] = mat("crystal", True)
    cone_at(head + _v(-0.05, 0, 0.2), 0.08, 0.35, "#5b3f9a", (-0.3, 0, 1), n=6)  # crest
    # halo ring behind
    for i in range(14):
        a = TAU * i / 14
        p = sh + _v(-0.35, 0.15, 0.1) + _v(0, 0.55 * math.cos(a), 0.55 * math.sin(a))
        ellipsoid(p.x, p.y, p.z, 0.05, 0.05, 0.05, "gold")
    # arms + lance
    near_arm = pose.get("near_arm") or (0.6, 0.9)
    far_arm = pose.get("far_arm") or (0.3, 0.5)
    for side, sgn, (b, e) in (("near", -1, near_arm), ("far", 1, far_arm)):
        ss = sh + _v(0, sgn * 0.38, -0.05)
        ellipsoid(ss.x, ss.y, ss.z + 0.03, 0.17, 0.16, 0.14, "#d6a93e")
        el = ss + _dir(b) * 0.32
        hd = el + _dir(b + e) * 0.32
        limb(ss, el, 0.08, 0.07, "#5b3f9a")
        limb(el, hd, 0.07, 0.06, "#d6a93e")
        ellipsoid(hd.x, hd.y, hd.z, 0.08, 0.08, 0.08, "#d6a93e")
        if side == "near":
            d = _v(1.0, 0, pose.get("lance_tilt", 0.15)).normalized()
            limb(hd - d * 0.5, hd + d * 0.9, 0.03, 0.03, "#5b3f9a")
            cone_at(hd + d * 0.9, 0.07, 0.4, "crystal", tuple(d), n=6, glow=True)


def rift_hound(pose):
    P = dict(leg_h=0.42, body_rx=0.5, body_ry=0.22, body_rz=0.22, leg_r=0.06, head_r=0.18,
             body="#3d3f5c", leg="#34364f", paw="#2a2b40", tail=0.4, stride=0.6, bob=0.04)
    J = quadruped(P, pose)
    b = J["body"]
    for k in range(4):  # rift cracks
        x = b.x - 0.3 + k * 0.18
        box(x, b.y - 0.21, b.z - 0.05 + 0.05 * (k % 2), 0.04, 0.02, 0.2, "#e05cff").data.materials[0] = mat("#e05cff", True)
    h = J["head"]
    for sgn in (-1, 1):
        cone_at(h + _v(-0.05, sgn * 0.1, 0.12), 0.06, 0.2, "#3d3f5c", (-0.3, sgn * 0.2, 1), n=5)  # ears
    ellipsoid(h.x + 0.1, h.y - 0.13, h.z + 0.05, 0.035, 0.03, 0.035, "#ff7af0", glow=True)
    for k in range(4):  # back spines
        cone_at(b + _v(-0.25 + k * 0.17, 0, 0.18), 0.04, 0.16, "#e05cff", (-0.3, 0, 1), n=5, glow=True)


def spore_skitterling(pose):
    ph = pose.get("phase")
    bob = 0.03 * abs(math.sin(ph * 2)) if ph is not None else 0.0
    c = _v(0, 0, 0.3 + bob)
    ellipsoid(c.x, c.y, c.z, 0.22, 0.18, 0.14, "#e9ddc0")  # body
    crawler_legs(c, 3, 0.3, 0.32, 0.25, 0.03, "#c9b48a", pose)
    cap = c + _v(-0.02, 0, 0.14)
    ellipsoid(cap.x, cap.y, cap.z, 0.38, 0.34, 0.18, "#d98c4a")
    for p in ((0.1, -0.2, 0.08), (-0.15, -0.18, 0.1), (0.0, -0.05, 0.17), (0.2, 0.05, 0.12), (-0.2, 0.1, 0.12)):
        ellipsoid(cap.x + p[0], cap.y + p[1], cap.z + p[2], 0.05, 0.05, 0.025, "white")
    for sgn in (-1, 1):
        ellipsoid(c.x + 0.2, c.y + sgn * 0.07, c.z, 0.035, 0.035, 0.04, "eye")


def brood_sac(pose):
    ph = pose.get("phase")
    pulse = 1.0 + 0.05 * math.sin(ph * 2) if ph is not None else 1.0
    c = _v(0, 0, 0.42)
    crawler_legs(c + _v(0, 0, -0.12), 3, 0.5, 0.42, 0.2, 0.045, "#9a4f7a", pose, lift=0.08)
    ellipsoid(c.x, c.y, c.z, 0.45 * pulse, 0.36 * pulse, 0.32 * pulse, "#d77fb0")
    for p, r in (((0.25, -0.2, 0.12), 0.14), ((-0.2, -0.22, 0.18), 0.12), ((0.0, -0.1, 0.28), 0.13)):
        ellipsoid(c.x + p[0], c.y + p[1], c.z + p[2], r * pulse, r * pulse, r * pulse, "#e9a6cf")
        ellipsoid(c.x + p[0] + r * 0.4, c.y + p[1] - r * 0.6, c.z + p[2] + r * 0.2, r * 0.3, r * 0.3, r * 0.3, "#ffe0f2", glow=True)
    for k in range(3):  # veins
        a = -0.6 + k * 0.6
        limb(c + _v(0.4 * math.cos(a), -0.3, 0.05), c + _v(0.1 * math.cos(a), -0.25, 0.3), 0.012, 0.008, "#9a4f7a")


def bog_lurker_elite(pose):
    ph = pose.get("phase")
    sway = 0.05 * math.sin(ph) if ph is not None else 0.0
    c = _v(0, sway, 0.36)
    rot_obj(ellipsoid(c.x, c.y, c.z, 0.62, 0.34, 0.22, "#6b7a3a"), rz=sway)
    ellipsoid(c.x + 0.05, c.y - 0.05, c.z - 0.08, 0.55, 0.3, 0.13, "#a8b26a")  # belly
    crawler_legs(c + _v(0, 0, -0.08), 2, 0.75, 0.42, 0.25, 0.07, "#5c6a32", pose, lift=0.1)
    h = c + _v(0.62, 0, 0.04)
    ellipsoid(h.x, h.y, h.z, 0.3, 0.26, 0.15, "#6b7a3a")
    ellipsoid(h.x + 0.08, h.y, h.z - 0.09, 0.28, 0.24, 0.07, "#a8b26a")  # jaw
    for k in range(5):
        cone_at(h + _v(0.05 + k * 0.05, -0.2, -0.05), 0.02, -0.07, "white", (0, 0, 1), n=4)
    for sgn in (-1, 1):
        ellipsoid(h.x - 0.05, h.y + sgn * 0.14, h.z + 0.14, 0.07, 0.07, 0.07, "#ffd84a", glow=True)
    for k in range(5):  # back fins
        cone_at(c + _v(-0.4 + k * 0.2, 0, 0.18), 0.06, 0.2, "#4f5c2a", (-0.4, 0, 1), n=4)
    limb(c + _v(-0.55, 0, 0), c + _v(-1.0, -sway * 2, -0.1), 0.12, 0.02, "#6b7a3a")  # tail


def ashwing_moth(pose):
    ph = pose.get("phase")
    flap = math.sin(ph) * 0.9 if ph is not None else 0.35
    bob = 0.06 * math.cos(ph) if ph is not None else 0.0
    c = _v(0, 0, 0.75 + bob)
    rot_obj(ellipsoid(c.x - 0.1, c.y, c.z, 0.3, 0.12, 0.12, "#b88a5c"), ry=0.15)
    ellipsoid(c.x + 0.2, c.y, c.z + 0.02, 0.12, 0.12, 0.12, "#e3c39a")  # fuzzy head
    for sgn in (-1, 1):
        ellipsoid(c.x + 0.3, c.y + sgn * 0.06, c.z + 0.05, 0.04, 0.04, 0.04, "eye")
        limb(c + _v(0.27, sgn * 0.04, 0.1), c + _v(0.45, sgn * 0.12, 0.35), 0.01, 0.006, "#7d5034")
    for sgn, depth in ((-1, -0.1), (1, 0.1)):
        a = flap if sgn < 0 else -flap * 0.8
        for k, (span, sweep, key) in enumerate(((0.75, 0.3, "#d79a5a"), (0.5, -0.25, "#b9744a"))):
            root = c + _v(0.0 - k * 0.12, depth, 0.05)
            tip_dir = _v(sweep * 0.5, sgn * math.cos(a), math.sin(abs(a)) * 0.9 + 0.15)
            tip = root + tip_dir * span
            side = _v(1, 0, 0) * (0.3 if k == 0 else 0.22)
            poly([root + side * 0.6, tip + side * 0.4, tip - side * 0.6, root - side * 0.8], key)
            if k == 0:
                e = root + tip_dir * span * 0.6
                ellipsoid(e.x, e.y + sgn * 0.01, e.z, 0.07, 0.03, 0.07, "#3b3245")


MONSTERS = {
    # id: (builder, boss, world frame size)
    "goblin_runner": (goblin_runner, False, 2.2),
    "goblin_mender": (goblin_mender, False, 2.2),
    "goblin_drummer": (goblin_drummer, False, 2.2),
    "shade_stalker": (shade_stalker, False, 2.6),
    "armored_brute": (armored_brute, False, 2.8),
    "forest_troll_elite": (forest_troll_elite, False, 3.2),
    "iron_colossus_elite": (iron_colossus_elite, False, 3.0),
    "goblin_warlord_boss": (goblin_warlord_boss, True, 4.4),
    "rift_sentinel_boss": (rift_sentinel_boss, True, 3.6),
    "rift_hound": (rift_hound, False, 2.4),
    "spore_skitterling": (spore_skitterling, False, 1.6),
    "brood_sac": (brood_sac, False, 2.0),
    "bog_lurker_elite": (bog_lurker_elite, False, 3.0),
    "ashwing_moth": (ashwing_moth, False, 2.4),
}


def monster_poses(boss, builder):
    poses = [{"phase": None}] + [{"phase": p} for p in WALK_PHASES]
    if boss:
        if builder is rift_sentinel_boss:
            prep = [{"phase": None, "near_arm": (0.9 + 0.15 * i, 1.2), "lance_tilt": 0.3} for i in range(4)]
            atk = [{"phase": None, "near_arm": (1.6 - 0.15 * i, 0.4 - 0.08 * i), "lance_tilt": 0.05} for i in range(5)]
        else:
            prep = [{"phase": None, "near_arm": (2.4 + 0.12 * i, 0.5), "far_arm": (0.6, 0.6)} for i in range(4)]
            atk = [{"phase": None, "near_arm": (2.6 - 0.55 * i, 0.4 - 0.08 * i), "far_arm": (0.3, 0.6)} for i in range(5)]
        poses += prep + atk
    return poses


def render_monsters(ids=None, stills=True):
    import os
    os.makedirs(RAW + "monsters", exist_ok=True)
    out = []
    for mid in ids or MONSTERS:
        builder, boss, size = MONSTERS[mid]
        setup_render(FRAME_PX, FRAME_PX, line_px=2.0, sun_rot=(48, -10, -40))
        use_collection("Unit")
        solo_collections(["Unit"])
        ortho_camera(MONSTER_PITCH, MONSTER_YAW, (0.0, 0.0, size * 0.42), size)
        for i, pose in enumerate(monster_poses(boss, builder)):
            clear_collection("Unit")
            builder(pose)
            out.append(render_to(RAW + "monsters/%s_f%02d.png" % (mid, i)))
        if stills:
            setup_render(STILL_PX, STILL_PX, line_px=4.0, sun_rot=(48, -10, -40))
            clear_collection("Unit")
            builder({"phase": None})
            out.append(render_to(RAW + "monsters/%s_still.png" % mid))
    return out


# ================================================================ hero
HERO_W, HERO_H = 1024, 1536
HERO_ORTHO = 5.6          # world units across the canvas height
HERO_PITCH = 8.0
SKIN = "skin"

# hero joints (front view, hero faces -Y; +X is image right = hero's left)
HJ = {
    "hip": _v(0, 0, 2.15), "chest": _v(0, 0, 3.0), "neck": _v(0, 0, 3.7), "head": _v(0, -0.02, 4.25),
    "sh_r": _v(-0.62, 0, 3.45), "el_r": _v(-0.9, -0.12, 2.75), "hd_r": _v(-0.95, -0.42, 2.25),
    "sh_l": _v(0.62, 0, 3.45), "el_l": _v(0.92, -0.05, 2.78), "hd_l": _v(0.8, -0.5, 2.55),
    "hip_r": _v(-0.3, 0, 2.05), "kn_r": _v(-0.36, -0.05, 1.1), "an_r": _v(-0.4, 0, 0.22),
    "hip_l": _v(0.3, 0, 2.05), "kn_l": _v(0.36, -0.05, 1.1), "an_l": _v(0.4, 0, 0.22),
}


def hero_body():
    """Base body: skin, linen shirt, brown trousers, plain shoes."""
    j = HJ
    for s in ("r", "l"):
        limb(j["hip_" + s], j["kn_" + s], 0.22, 0.18, "#7a5236")
        limb(j["kn_" + s], j["an_" + s], 0.18, 0.14, "#7a5236")
        a = j["an_" + s]
        ellipsoid(a.x, a.y - 0.12, a.z - 0.1, 0.17, 0.28, 0.13, "#5a3a26")
        limb(j["sh_" + s], j["el_" + s], 0.15, 0.13, "#e9ddc0")
        limb(j["el_" + s], j["hd_" + s], 0.12, 0.1, SKIN)
        h = j["hd_" + s]
        ellipsoid(h.x, h.y, h.z, 0.14, 0.13, 0.15, SKIN)
    ellipsoid(0, 0, 2.2, 0.48, 0.3, 0.3, "#7a5236")          # pelvis
    ellipsoid(0, 0, 2.95, 0.58, 0.34, 0.72, "#e9ddc0")       # shirt
    box(0, 0, 2.3, 1.0, 0.62, 0.12, "#5a3a26")               # belt
    limb(j["chest"] + _v(0, 0, 0.5), j["neck"], 0.17, 0.15, SKIN)
    h = j["head"]
    ellipsoid(h.x, h.y, h.z, 0.42, 0.4, 0.48, SKIN)
    ellipsoid(h.x, h.y + 0.05, h.z + 0.18, 0.45, 0.42, 0.38, "hair")  # hair cap
    for s in (-1, 1):
        ellipsoid(h.x + s * 0.16, h.y - 0.38, h.z, 0.05, 0.03, 0.07, "eye")
        ellipsoid(h.x + s * 0.42, h.y, h.z - 0.02, 0.07, 0.05, 0.1, SKIN)  # ears
    ellipsoid(h.x, h.y - 0.42, h.z - 0.1, 0.06, 0.05, 0.06, "#d8a07a")  # nose


# Set look: main colour, trim, accent, glow, material family
SETS = {
    "ascendant": dict(main="#f2ead8", trim="gold", acc="#7fd9ff", glow="#9fe8ff", fam="metal"),
    "brute": dict(main="#5c5f6b", trim="#8a3a2e", acc="#d8d2c4", fam="metal", spikes=True),
    "goblin": dict(main="#6f8a3a", trim="#efe2c4", acc="#8a5a36", fam="leather", fangs=True),
    "iron": dict(main="#8a929e", trim="#5c636e", acc="leather", fam="metal"),
    "leather": dict(main="#8a5a36", trim="#5a3a26", acc="gold", fam="leather"),
    "lurker": dict(main="#6b7a3a", trim="#a8b26a", acc="white", fam="leather", fangs=True),
    "reinforced": dict(main="#a3acb8", trim="#7a5236", acc="#5a3a26", fam="metal"),
    "riftrunner": dict(main="#3a4f86", trim="#2a2f50", acc="#c9a6ff", glow="#d6b0ff", fam="cloth"),
    "sentinel": dict(main="#d6a93e", trim="#5b3f9a", acc="#a6e6ff", glow="#a6e6ff", fam="metal"),
    "steel": dict(main="#b8c6d6", trim="#3e70bc", acc="gold", fam="metal"),
    "steelwrought": dict(main="#b8c6d6", trim="#3e70bc", acc="gold", fam="metal"),
    "traveler": dict(main="#9c6a40", trim="#5a3a26", acc="#c0463a", fam="leather"),
    "troll": dict(main="#6f8f4a", trim="#5a3a26", acc="#cdbfa3", fam="hide", fur="#8a7a5a"),
    "trollhide": dict(main="#6f8f4a", trim="#5a3a26", acc="#cdbfa3", fam="hide", fur="#8a7a5a"),
    "warlord": dict(main="#3f3c48", trim="gold", acc="#c0463a", fam="metal", spikes=True),
    "wooden": dict(main="#b07a43", trim="#7d5034", acc="iron", fam="wood"),
}


def set_of(item_id):
    head = item_id.split("_")[0]
    if head.endswith("s") and head[:-1] in SETS:
        head = head[:-1]
    return SETS.get(head, SETS["iron"])


def _studs(points, key, r=0.05):
    for p in points:
        ellipsoid(p.x, p.y, p.z, r, r, r, key, 8, 6)


def gear_helmet(item, S):
    h = HJ["head"]
    name = item
    if "circlet" in name or "crown" in name:
        prism(h.x, h.y, h.z + 0.18, 0.47, 0.47, 0.12, S["main"] if "circlet" in name else S["trim"], n=20, smooth=True)
        for k in range(7):
            a = math.pi * (0.15 + 0.7 * k / 6) + math.pi
            p = h + _v(0.46 * math.cos(a), 0.46 * math.sin(a), 0.3)
            cone_at(p, 0.06, 0.22 if "crown" in name else 0.16, S["trim"] if "circlet" in name else S["main"], (0, 0, 1), n=5)
        if S.get("glow"):
            ellipsoid(h.x, h.y - 0.46, h.z + 0.25, 0.07, 0.04, 0.08, S["glow"], glow=True)
        return
    if "hood" in name:
        ellipsoid(h.x, h.y + 0.06, h.z + 0.1, 0.52, 0.5, 0.56, S["main"])
        cone_at(h + _v(0, 0.25, 0.3), 0.3, 0.6, S["main"], (0, 1, 0.4), n=12)
        prism(h.x, h.y - 0.1, h.z - 0.45, 0.55, 0.62, 0.25, S["trim"], n=16, smooth=True)
        if S.get("glow"):
            for s in (-1, 1):
                ellipsoid(h.x + s * 0.16, h.y - 0.42, h.z, 0.05, 0.03, 0.06, S["glow"], glow=True)
        return
    # metal or leather helm
    full = "visor" in name or "war_helm" in name or "steelwrought" in name
    ellipsoid(h.x, h.y + 0.02, h.z + 0.12, 0.5, 0.48, 0.48, S["main"])
    prism(h.x, h.y, h.z - 0.02, 0.53, 0.53, 0.1, S["trim"], n=20, smooth=True)
    if full:
        box(h.x, h.y - 0.36, h.z - 0.38, 0.62, 0.2, 0.42, S["main"])
        box(h.x, h.y - 0.47, h.z - 0.02, 0.5, 0.04, 0.06, S.get("glow", "dark")).data.materials[0] = mat(S.get("glow", "dark"), bool(S.get("glow")))
    else:
        box(h.x, h.y - 0.48, h.z - 0.2, 0.08, 0.06, 0.32, S["trim"])  # nose guard
    if S.get("spikes") or "war_helm" in name:
        for s in (-1, 1):
            cone_at(h + _v(s * 0.42, 0, 0.3), 0.1, 0.45, S["acc"], (s * 0.8, 0, 1), n=8)
    if "steelwrought" in name or "visor" in name:
        cone_at(h + _v(0, 0.05, 0.55), 0.06, 0.4, S["acc"] if "visor" not in name else S["trim"], (0, 0.4, 1), n=6)
    if S.get("fangs"):
        for k in range(4):
            cone_at(h + _v(-0.3 + k * 0.2, -0.42, 0.05), 0.04, -0.15, S["trim"], (0, 0, 1), n=4)


def gear_chest(item, S):
    c = HJ["chest"]
    fam = S["fam"]
    if "coat" in item or "mantle" in item:
        ellipsoid(c.x, c.y, c.z, 0.64, 0.4, 0.76, S["main"])
        cone_at(_v(0, 0, 2.35), 0.62, -0.75, S["main"], (0, 0, 1), n=16)  # skirt
        box(0, -0.38, 1.7, 0.08, 0.04, 1.6, S["trim"])
        if "mantle" in item:
            for s in (-1, 1):
                ellipsoid(s * 0.45, 0.02, 3.45, 0.42, 0.42, 0.26, S.get("fur", S["trim"]))
            ellipsoid(0, -0.05, 3.55, 0.5, 0.4, 0.2, S.get("fur", S["trim"]))
        else:
            for s in (-1, 1):
                ellipsoid(s * 0.55, 0, 3.42, 0.24, 0.26, 0.2, S["trim"])
            ellipsoid(0, -0.36, 3.0, 0.08, 0.03, 0.08, S["glow"], glow=True)
        box(0, 0, 2.3, 1.06, 0.66, 0.13, S["trim"])
        return
    ellipsoid(c.x, c.y - 0.02, c.z, 0.63, 0.39, 0.74, S["main"])
    box(0, 0, 2.3, 1.06, 0.66, 0.13, S["trim"] if fam != "metal" else "#5a3a26")
    if fam == "leather":
        for k in range(3):
            box(0.12, -0.38, 2.6 + k * 0.28, 0.12, 0.03, 0.05, S["trim"])
        return
    # metal plate: pauldrons, centre ridge, rim
    ridge = box(0, -0.4, 2.45, 0.06, 0.04, 1.05, S["trim"])
    big = "bulwark" in item or "battleplate" in item
    for s in (-1, 1):
        r = 0.34 if big else 0.27
        ellipsoid(s * 0.62, 0, 3.5, r, r, r * 0.8, S["main"])
        prism(s * 0.62, 0, 3.32, r * 1.02, r * 1.02, 0.06, S["trim"], n=16, smooth=True)
        if S.get("spikes"):
            for k in range(2):
                cone_at(_v(s * (0.55 + 0.15 * k), 0, 3.66), 0.06, 0.28, S["acc"], (s * 0.5, 0, 1), n=6)
    if S.get("glow"):
        ellipsoid(0, -0.4, 3.05, 0.1, 0.04, 0.12, S["glow"], glow=True)
    if "battleplate" in item:
        poly([_v(-0.2, -0.42, 3.3), _v(0.2, -0.42, 3.3), _v(0, -0.42, 2.85)], S["trim"])


def gear_gloves(item, S):
    for s in ("r", "l"):
        el, hd = HJ["el_" + s], HJ["hd_" + s]
        cuff = el + (hd - el) * 0.35
        flare = 0.16 if S["fam"] == "metal" else 0.14
        limb(cuff, hd, flare, 0.13, S["main"])
        prism(cuff.x, cuff.y, cuff.z, flare * 1.08, flare * 1.08, 0.06, S["trim"], n=12, smooth=True)
        ellipsoid(hd.x, hd.y - 0.02, hd.z, 0.17, 0.16, 0.18, S["main"])
        if "claw" in item:
            for k in range(3):
                cone_at(hd + _v((k - 1) * 0.07, -0.12, -0.08), 0.03, 0.2, S["acc"], (0, -0.6, -1), n=4)
        if S.get("spikes"):
            cone_at(cuff + _v(0, 0, -0.05), 0.05, 0.18, S["acc"], (1 if s == "l" else -1, 0, 0), n=5)
        if S.get("glow"):
            ellipsoid(hd.x, hd.y - 0.17, hd.z + 0.03, 0.05, 0.02, 0.05, S["glow"], glow=True)


def gear_pants(item, S):
    for s in ("r", "l"):
        hp, kn, an = HJ["hip_" + s], HJ["kn_" + s], HJ["an_" + s]
        low = kn + (an - kn) * 0.45
        limb(hp, kn, 0.25, 0.21, S["main"])
        limb(kn, low, 0.21, 0.18, S["main"])
        if S["fam"] == "metal":
            ellipsoid(kn.x, kn.y - 0.12, kn.z, 0.16, 0.12, 0.15, S["trim"])  # knee cop
            if S.get("spikes"):
                cone_at(kn + _v(0, -0.2, 0), 0.05, 0.16, S["acc"], (0, -1, 0.2), n=5)
    ellipsoid(0, 0, 2.2, 0.52, 0.33, 0.32, S["main"])
    if S["fam"] == "metal":
        for s in (-1, 1):  # tassets
            box(s * 0.3, -0.3, 1.65, 0.36, 0.06, 0.45, S["main"])
            box(s * 0.3, -0.33, 1.65, 0.38, 0.04, 0.06, S["trim"])
    if S.get("fangs"):
        for k in range(5):
            cone_at(_v(-0.4 + k * 0.2, -0.3, 2.0), 0.035, -0.14, S["acc"], (0, 0, 1), n=4)


def gear_boots(item, S):
    for s in ("r", "l"):
        kn, an = HJ["kn_" + s], HJ["an_" + s]
        top = an + (kn - an) * 0.5
        limb(an, top, 0.19, 0.2, S["main"])
        prism(top.x, top.y, top.z - 0.03, 0.22, 0.22, 0.08, S["trim"], n=14, smooth=True)
        ellipsoid(an.x, an.y - 0.13, an.z - 0.1, 0.2, 0.32, 0.15, S["main"])
        if S["fam"] == "metal":
            ellipsoid(an.x, an.y - 0.3, an.z - 0.03, 0.15, 0.12, 0.09, S["trim"])
        if S.get("fur") or "striders" in item:
            prism(top.x, top.y, top.z - 0.08, 0.25, 0.25, 0.12, S.get("fur", S["trim"]), n=14, smooth=True)
        if S.get("glow"):
            ellipsoid(an.x, an.y - 0.42, an.z, 0.05, 0.03, 0.05, S["glow"], glow=True)
        if S.get("spikes"):
            cone_at(kn + _v(0, -0.12, -0.25), 0.05, 0.16, S["acc"], (0, -1, 0.3), n=5)


def gear_weapon(item, S):
    hd = HJ["hd_r"]
    up = _v(-0.18, -0.05, 1.0).normalized()
    if "lance" in item:
        limb(hd - up * 0.9, hd + up * 2.1, 0.05, 0.05, S["trim"])
        cone_at(hd + up * 2.1, 0.12, 0.7, S["main"], tuple(up), n=6)
        ellipsoid(hd.x + up.x * 2.1, hd.y + up.y * 2.1, hd.z + up.z * 2.1, 0.14, 0.1, 0.08, S["glow"], glow=True)
        return
    great = "great" in item
    length = 1.9 if great else 1.35
    width = 0.2 if great else 0.13
    if "fang" in item:
        length, width = 1.05, 0.12
    guard = hd + up * 0.15
    limb(hd - up * 0.28, guard, 0.05, 0.05, "#5a3a26")  # grip
    ellipsoid(*(hd - up * 0.32), 0.08, 0.08, 0.08, S["trim"])
    gx = _v(1, 0, 0.18).normalized()
    limb(guard - gx * (0.32 if great else 0.25), guard + gx * (0.32 if great else 0.25), 0.05, 0.05, S["trim"])
    tip = guard + up * length
    bend = _v(0.25, 0, 0) if "fang" in item else _v(0, 0, 0)
    blade = S["main"] if S["fam"] == "metal" else "steel"
    if "fang" in item:
        blade = "#efe2c4"
    poly([guard - gx * width, guard + gx * width, tip - up * 0.25 + gx * width * 0.8 + bend * 0.6,
          tip + bend, tip - up * 0.25 - gx * width * 0.8 + bend * 0.6], blade)
    limb(guard + up * 0.05, tip - up * 0.3 + bend * 0.5, 0.015, 0.01, S["trim"] if S["fam"] == "metal" else "#cdbfa3")
    if S.get("glow"):
        ellipsoid(*(guard), 0.06, 0.05, 0.06, S["glow"], glow=True)


def gear_offhand(item, S):
    hd = HJ["hd_l"]
    c = hd + _v(0.05, -0.18, 0.15)
    face = "#b07a43" if "wooden" in item else S["main"]
    if "kite" in item:
        pts = [_v(-0.45, 0, 0.55), _v(0.45, 0, 0.55), _v(0.5, 0, 0.1), _v(0, 0, -0.85), _v(-0.5, 0, 0.1)]
        poly([c + p for p in pts], face)
        poly([c + p * 0.82 + _v(0, -0.02, 0.02) for p in pts], S["trim"])
        poly([c + p * 0.6 + _v(0, -0.04, 0.03) for p in pts], face)
        box(c.x, c.y - 0.06, c.z - 0.45, 0.08, 0.02, 0.85, S["acc"])
        box(c.x, c.y - 0.06, c.z + 0.08, 0.6, 0.02, 0.08, S["acc"])
        return
    big = "aegis" in item or "ward" in item
    r = 0.62 if big else 0.45
    o = prism(c.x, c.y, c.z, r, r, 0.08, S["trim"], n=24)
    o.rotation_euler = (math.pi / 2, 0, 0)
    o = prism(c.x, c.y - 0.02, c.z, r * 0.86, r * 0.86, 0.08, face, n=24)
    o.rotation_euler = (math.pi / 2, 0, 0)
    ellipsoid(c.x, c.y - 0.12, c.z, r * 0.25, 0.1, r * 0.25, S["acc"] if not S.get("glow") else S["glow"],
              glow=bool(S.get("glow")))
    if "wooden" in item or S["fam"] in ("wood", "hide"):
        for dx in (-0.2, 0.2):
            box(c.x + dx, c.y - 0.11, c.z - r * 0.8, 0.06, 0.02, r * 1.6, "#7d5034" if "wooden" in item else S.get("fur", S["trim"]))
    if big:
        for k in range(8):
            a = TAU * k / 8
            ellipsoid(c.x + math.cos(a) * r * 0.93, c.y - 0.05, c.z + math.sin(a) * r * 0.93, 0.05, 0.04, 0.05, S["acc"] if "ward" in item else "gold")


GEAR_BUILDERS = {"helmet": gear_helmet, "chest": gear_chest, "gloves": gear_gloves, "pants": gear_pants,
                 "boots": gear_boots, "weapon": gear_weapon, "offhand": gear_offhand}

GEAR = {
    "ascendant_aegis": "offhand", "ascendant_blade": "weapon", "ascendant_crown": "helmet",
    "ascendant_cuirass": "chest", "ascendant_greaves": "pants", "ascendant_grips": "gloves",
    "ascendant_treads": "boots", "brute_gauntlets": "gloves", "brute_legguards": "pants",
    "brutes_bulwark_plate": "chest", "brutes_war_helm": "helmet", "goblin_claw_gauntlets": "gloves",
    "goblin_fang_circlet": "helmet", "goblin_raider_leggings": "pants", "iron_buckler": "offhand",
    "iron_greaves": "pants", "iron_helm": "helmet", "iron_sword": "weapon", "leather_gloves": "gloves",
    "leather_jerkin": "chest", "leather_leggings": "pants", "lurker_claw_gauntlets": "gloves",
    "lurker_fang_blade": "weapon", "reinforced_boots": "boots", "reinforced_gauntlets": "gloves",
    "reinforced_helm": "helmet", "reinforced_plate": "chest", "riftrunner_coat": "chest",
    "riftrunner_hood": "helmet", "riftrunner_striders": "boots", "sentinel_visor": "helmet",
    "sentinel_ward": "offhand", "sentinels_aegis": "offhand", "sentinels_lance": "weapon",
    "sentinels_striders": "boots", "steel_greatsword": "weapon", "steelwrought_cuirass": "chest",
    "steelwrought_gauntlets": "gloves", "steelwrought_helm": "helmet", "steelwrought_kite_shield": "offhand",
    "steelwrought_legplates": "pants", "steelwrought_longsword": "weapon", "steelwrought_sabatons": "boots",
    "traveler_boots": "boots", "troll_hide_mantle": "chest", "trollhide_buckler": "offhand",
    "trollhide_striders": "boots", "warlords_battleplate": "chest", "warlords_greatblade": "weapon",
    "warlords_greaves": "boots", "warlords_legguards": "pants", "wooden_buckler": "offhand",
}


def _hero_camera():
    setup_render(HERO_W, HERO_H, line_px=3.0, sun_rot=(50, 18, -30))
    ortho_camera(HERO_PITCH, 0.0, (0.0, 0.0, HERO_ORTHO * 0.5 - 0.2), HERO_ORTHO)


def render_hero(items=None, body=True):
    """Base body (outlined) and each gear item over a holdout body."""
    import os
    os.makedirs(RAW + "hero", exist_ok=True)
    out = []
    _hero_camera()
    clear_collection("Gear")
    use_collection("Unit")
    solo_collections(["Unit", "Gear"])
    clear_collection("Unit")
    hero_body()
    if body:
        out.append(render_to(RAW + "hero/hero_base_body.png"))
    # body as holdout: hides what it covers, draws nothing itself, no outline
    for o in use_collection("Unit").objects:
        if o.type == "MESH":
            o.data.materials[0] = mat("holdout")
    ls = bpy.context.scene.view_layers[0].freestyle_settings.linesets[0]
    ls.select_by_collection = True
    ls.collection = use_collection("Gear")
    for item in items or GEAR:
        clear_collection("Gear")
        GEAR_BUILDERS[GEAR[item]](item, set_of(item))
        out.append(render_to(RAW + "hero/%s_worn.png" % item))
    ls.select_by_collection = False
    return out
