extends RefCounted
class_name SmokeUserdataGuard

## Fail-fast gate for headless smokes that may delete or write user:// saves.
## Requires BOTH:
##   RI_SMOKE_ISOLATED=1
##   RI_SMOKE_USER_DATA_DIR=<exact OS.get_user_data_dir() of a dedicated temp tree>
## The expected dir must contain the marker "ri-smoke" so normal RunInfinity
## userdata (e.g. ~/.local/share/godot/app_userdata/RunInfinity) is never accepted.
##
## Do not assume XDG_DATA_HOME alone isolates every OS — verify the live path.

const ENV_FLAG := "RI_SMOKE_ISOLATED"
const ENV_DIR := "RI_SMOKE_USER_DATA_DIR"
const PATH_MARKER := "ri-smoke"


static func require_isolated(tree: SceneTree, label: String) -> bool:
	if OS.get_environment(ENV_FLAG) != "1":
		push_error(
			"%s: refuse — %s=1 required before any save delete/reset/write."
			% [label, ENV_FLAG]
		)
		tree.quit(1)
		return false

	var expected_raw := OS.get_environment(ENV_DIR).strip_edges()
	if expected_raw.is_empty():
		push_error(
			"%s: refuse — %s must be set to the dedicated smoke user data dir."
			% [label, ENV_DIR]
		)
		tree.quit(1)
		return false

	var user_dir := _norm_path(OS.get_user_data_dir())
	var expected := _norm_path(expected_raw)

	if user_dir.is_empty() or expected.is_empty():
		push_error("%s: refuse — empty user data path (user=%s expected=%s)." % [label, user_dir, expected])
		tree.quit(1)
		return false

	if user_dir != expected:
		push_error(
			"%s: refuse — OS.get_user_data_dir()=%s does not match %s=%s (isolation not verified)."
			% [label, user_dir, ENV_DIR, expected]
		)
		tree.quit(1)
		return false

	if not _is_dedicated_smoke_temp(user_dir):
		push_error(
			"%s: refuse — user data dir is not a dedicated ri-smoke temp path: %s"
			% [label, user_dir]
		)
		tree.quit(1)
		return false

	print("%s: userdata isolation OK (%s)" % [label, user_dir])
	return true


static func _norm_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path()


static func _is_dedicated_smoke_temp(user_dir: String) -> bool:
	var lower := user_dir.to_lower()
	if PATH_MARKER not in lower:
		return false
	# Must live under a temp-like root (Linux/macOS/Windows common forms).
	if lower.begins_with("/tmp/") or lower.begins_with("/var/tmp/"):
		return true
	if "/temp/" in lower or lower.begins_with("/temp/"):
		return true
	# GitHub Actions / custom runners sometimes use /tmp via symlink already covered;
	# also allow explicit /home/*/tmp/ri-smoke* only if marker present and path contains /tmp/
	if "/tmp/" in lower:
		return true
	return false
