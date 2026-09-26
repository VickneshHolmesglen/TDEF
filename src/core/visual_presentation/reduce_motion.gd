class_name ReduceMotion
extends RefCounted

## Single reduced-motion accessor (wind-up presentation spec §6). Backed by a project-setting
## key that defaults to false, so it can be flipped by hand, by a test, or by a future settings
## screen with no code change. No UI and no persistence yet.
##
## Honored by: the big-hit screen shake (skipped), the low-HP vignette pulse (steady), the
## telegraph pulse (steady tint), and the death shockwave ring (skipped).
##
## Usage: if ReduceMotion.enabled(): return

const SETTING_KEY: String = "accessibility/reduce_motion"


## True when the player (or a test) has asked for reduced motion.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_KEY, false))
