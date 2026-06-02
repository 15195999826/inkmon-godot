extends Node


func _ready() -> void:
	var failure := _run()
	if failure != "":
		push_error(failure)
		print("SMOKE_TEST_RESULT: FAIL - %s" % failure)
		get_tree().quit(1)
		return
	print("SMOKE_TEST_RESULT: PASS - skill metadata export/upload payload is metadata-only")
	get_tree().quit(0)


func _run() -> String:
	var skills := InkMonL2ContentContract.skill_metadata_exports()
	if skills.is_empty():
		return "skill metadata exports should not be empty"
	var ids := {}
	for i in range(skills.size()):
		var skill := skills[i]
		for key in ["id", "implementation_key", "display_name", "element", "channel"]:
			if str(skill.get(key, "")) == "":
				return "skills[%d].%s must be non-empty" % [i, key]
		for forbidden_key in ["source", "gdscript", "gdscript_source", "code"]:
			if skill.has(forbidden_key):
				return "skills[%d] must not include %s" % [i, forbidden_key]
		var skill_id := str(skill.get("id", ""))
		if ids.has(skill_id):
			return "duplicate skill id: %s" % skill_id
		ids[skill_id] = true
		if not str(skill.get("element", "")) in InkMonElementChart.all_elements():
			return "skills[%d].element invalid: %s" % [i, str(skill.get("element", ""))]
		if not str(skill.get("channel", "")) in InkMonL2ContentContract.VALID_SKILL_CHANNELS:
			return "skills[%d].channel invalid: %s" % [i, str(skill.get("channel", ""))]

	var payload := InkMonSkillMetadataUploadTool.build_payload(skills)
	if not (payload.get("skills", []) is Array):
		return "upload payload must contain skills array"
	if JSON.stringify(payload).contains(".gd"):
		return "upload payload must not mention .gd source"
	return ""
