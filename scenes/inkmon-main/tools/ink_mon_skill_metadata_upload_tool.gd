@tool
class_name InkMonSkillMetadataUploadTool
extends EditorScript
## Dev-time upload tool for the godot→server skill metadata path (ADR-0009).
## Uploads metadata only. Skill `.gd` source stays in the Godot project and is
## compiled into the export; runtime never fetches or dynamically loads skills.

const DEFAULT_URL := "https://lomo.inkmon.cloud/inkmon/skills"


func _run() -> void:
	var result: Dictionary = await upload_from_environment(EditorInterface.get_base_control())
	if not bool(result.get("ok", false)):
		push_error("[inkmon-skill-upload] %s" % str(result.get("error", "upload failed")))
		return
	print(format_result_message(result))


static func upload_from_environment(parent: Node) -> Dictionary:
	var auth := configured_auth()
	if auth == "":
		return {
			"ok": false,
			"error": "INKMON_CONTRACT_AUTH env var not set (expected 'user:pass'); aborting.",
		}
	return await upload_skill_metadata(
		parent,
		configured_url(),
		auth,
		InkMonL2ContentContract.skill_metadata_exports()
	)


static func configured_url() -> String:
	var env_url := OS.get_environment("INKMON_SKILL_UPLOAD_URL")
	if env_url != "":
		return env_url
	var local_url := InkMonContentImportTool.local_env_value("INKMON_SKILL_UPLOAD_URL", "")
	if local_url != "":
		return local_url
	var contract_url := InkMonContentImportTool.configured_url()
	if contract_url.ends_with("/contract"):
		return contract_url.substr(0, contract_url.length() - "/contract".length()) + "/skills"
	return DEFAULT_URL


static func configured_auth() -> String:
	return InkMonContentImportTool.configured_auth()


static func build_payload(skills: Array[Dictionary]) -> Dictionary:
	return {"skills": skills}


static func format_result_message(result: Dictionary) -> String:
	var ids := result.get("ids", PackedStringArray()) as PackedStringArray
	return "[inkmon-skill-upload] uploaded %d skill(s): %s" % [
		int(result.get("count", ids.size())),
		", ".join(ids),
	]


static func upload_skill_metadata(
	parent: Node,
	url: String,
	auth: String,
	skills: Array[Dictionary]
) -> Dictionary:
	var payload := build_payload(skills)
	var body := JSON.stringify(payload)
	var http := HTTPRequest.new()
	http.timeout = 30.0
	parent.add_child(http)

	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(auth),
		"Accept: application/json",
		"Content-Type: application/json",
	])
	var start_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if start_err != OK:
		http.queue_free()
		return {"ok": false, "error": "HTTPRequest.request() failed to start: %d" % start_err}

	var response: Array = await http.request_completed
	http.queue_free()

	var net_result := int(response[0])
	var http_code := int(response[1])
	var response_body: PackedByteArray = response[3]
	var response_text := response_body.get_string_from_utf8()
	if net_result != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		return {
			"ok": false,
			"error": "upload failed: result=%d http=%d body=%s" % [net_result, http_code, response_text],
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "server response is not a JSON object"}
	var data: Dictionary = parsed
	if not bool(data.get("ok", false)):
		return {"ok": false, "error": str(data.get("error", "server rejected upload"))}

	var ids := PackedStringArray()
	var ids_value: Variant = data.get("ids", [])
	if ids_value is Array:
		for id_value in (ids_value as Array):
			ids.append(str(id_value))
	return {
		"ok": true,
		"count": int(data.get("count", ids.size())),
		"ids": ids,
	}
