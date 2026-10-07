extends SceneTree

var failed := false
var loaded_count := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: ", message)
	failed = failed or not condition

func scan(path: String) -> void:
	var directory := DirAccess.open(path)
	for file in directory.get_files():
		# Web exports keep original resources behind .remap files.
		file = file.trim_suffix(".remap")
		if file.get_extension() in ["gd", "tscn", "tres"]:
			var resource = load(path.path_join(file))
			check(resource != null, path.path_join(file) + " loads")
			loaded_count += 1
			if resource is PackedScene:
				var scene = resource.instantiate()
				check(scene != null, path.path_join(file) + " instantiates")
				if scene != null:
					scene.free()
	for child in directory.get_directories():
		if not child.begins_with(".") and child != "tests":
			scan(path.path_join(child))

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	scan("res://scenes")
	scan("res://scripts")
	scan("res://theme")
	var data = root.get_node("SectorQuestionsData")
	var questions_checked := 0
	for sector_id in data.sector_cards:
		var questions: Array = data.sector_cards[sector_id].get("questions", [])
		check(questions.size() == 2, "sector %d has two questions" % sector_id)
		for question in questions:
			var correct: String = str(question.get("correct", ""))
			check(question.get("answers", {}).has(correct), "sector %d has a valid correct answer" % sector_id)
			for image_key in ["image", "info_image"]:
				var image_path: String = str(question.get(image_key, ""))
				if image_path != "":
					check(ResourceLoader.exists(image_path) and load(image_path) != null, image_path + " exists and loads")
			questions_checked += 1
	var street_data = root.get_node("StreetCardsData")
	var ids := {}
	for card in street_data.all_cards:
		check(not ids.has(card["id"]), "street card IDs are unique")
		ids[card["id"]] = true
		check(card.has("effect") and card.has("type") and card.has("event"), "street card %d has required fields" % card["id"])
	print("RESULT: ", "FAIL" if failed else "PASS", " — ", loaded_count, " resources, ", questions_checked, " questions, ", ids.size(), " street cards")
	quit(1 if failed else 0)
