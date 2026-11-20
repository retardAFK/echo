class_name RunSummary
extends RefCounted
## Short text of a game for the testers (spec S-009, Q7, T-081): copied from
## the end screen and pasted in the questionnaire. Pure logic, testable.


## Version of the game: the commit the web build was made from (set by the
## CI in application/config/version), "dev" otherwise.
static func build_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if not version.is_empty() else "dev"


## One line per figure, in the current language, from the counters of a finished game.
static func format(role: GameSession.Role, game_loop: GameLoop, fps: float) -> String:
	var role_key := "MENU_PLAY_MONSTER" if role == GameSession.Role.MONSTER else "MENU_PLAY_HUNTED"
	var rules := game_loop.rules
	var lines: Array[String] = [
		Text.t("SUMMARY_HEADER", build_version()),
		Text.t("SUMMARY_ROLE", Text.t(role_key)),
		Text.t(EndScreen.title_key(role, game_loop.hunted_won)),
		Text.t("END_DURATION", EndScreen.format_duration(game_loop.get_duration())),
		Text.t("END_FUSES", [rules.placed, rules.fuse_count]),
		Text.t("END_NOISES", game_loop.noise_count),
		Text.t("END_SCANS", game_loop.scan_count),
		Text.t("END_RUSES", game_loop.ruse_count),
		Text.t("SUMMARY_FPS", roundi(fps)),
	]
	lines.append_array(EndScreen.chase_lines(game_loop.chases))
	return "\n".join(lines)
