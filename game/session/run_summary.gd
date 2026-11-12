class_name RunSummary
extends RefCounted
## Short text of a game for the testers (spec S-009, Q7, T-081): copied from
## the end screen and pasted in the questionnaire. Pure logic, testable.


## Version of the game: the commit the web build was made from (set by the
## CI in application/config/version), "dev" otherwise.
static func build_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if not version.is_empty() else "dev"


## One line per figure, in French, from the counters of a finished game.
static func format(role: GameSession.Role, game_loop: GameLoop, fps: float) -> String:
	var lines: Array[String] = [
		TranslationServer.translate("SUMMARY_HEADER") % build_version(),
		(
			TranslationServer.translate("SUMMARY_ROLE")
			% TranslationServer.translate(
				"MENU_PLAY_MONSTER" if role == GameSession.Role.MONSTER else "MENU_PLAY_HUNTED"
			)
		),
		TranslationServer.translate(EndScreen.title_key(role, game_loop.hunted_won)),
		(
			TranslationServer.translate("END_DURATION")
			% EndScreen.format_duration(game_loop.get_duration())
		),
		(
			TranslationServer.translate("END_FUSES")
			% [game_loop.rules.placed, game_loop.rules.fuse_count]
		),
		TranslationServer.translate("END_NOISES") % game_loop.noise_count,
		TranslationServer.translate("END_SCANS") % game_loop.scan_count,
		TranslationServer.translate("END_RUSES") % game_loop.ruse_count,
		TranslationServer.translate("SUMMARY_FPS") % roundi(fps),
	]
	return "\n".join(lines)
