extends SceneTree
## Rewrites tests/golden/*.json. Only do this when a rules change is intended.


func _initialize() -> void:
	for seed in Golden.CASES:
		var f := FileAccess.open(Golden.path(seed), FileAccess.WRITE)
		f.store_string(JSON.stringify(Golden.record(seed), "  ", true))
		print("wrote %s" % Golden.path(seed))
	quit()
