extends SceneTree
func _initialize() -> void:
	print(ProjectSettings.get_setting("autoload/Audio"))
	print(Game.money)
	print(Events)
	quit(0)
