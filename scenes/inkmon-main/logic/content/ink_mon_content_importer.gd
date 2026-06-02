class_name InkMonContentImporter
## Pure parse+validate for a server creature-base contract (the canon→godot bridge
## projection). Shared by the editor import tool (dev-time fetch→write) and the
## local static content loader (runtime read-only file load) so both gate content
## the same way.
##
## No file/network/runtime side effects — give it text, get a verdict back.


## Parse `json_text` and validate it as a creature-base contract.
## Returns {ok: bool, errors: Array[String], data: Dictionary}.
## - JSON parse failure or a non-object top level → ok=false (data={}).
## - Otherwise ok = (validate_creature_base returned no errors).
static func parse_and_validate(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"errors": ["content is not a JSON object"],
			"data": {},
		}
	var data: Dictionary = parsed
	var errors := InkMonL2ContentContract.validate_creature_base(data)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"data": data,
	}
