@tool
class_name InkMonContentImportTool
extends EditorScript
## Dev-time import tool for the canon→godot bridge. Fetches the server creature-base
## contract, validates it through the shared importer, and writes it to
## res://data/inkmon_content.json — the file InkMonContentLoader applies at boot.
##
## Run it from the editor: open this script, then Tools → Run (autoloads are live,
## so the validator's dependency graph compiles). Auth + URL come from the
## environment so no secret is ever committed:
##   INKMON_CONTRACT_AUTH = "user:pass"   (Basic Auth credentials — REQUIRED)
##   INKMON_CONTRACT_URL  = full contract URL (OPTIONAL; defaults to the public one)
##
## The fetch/validate/write core is exposed as the static `import_contract()` so it
## can run from any Node host (the editor base control here, or a scene for headless
## verification) — and so item/skill server-sync tools can reuse the same mechanism.

const DEFAULT_URL := "https://lomo.inkmon.cloud/inkmon/contract"
const OUTPUT_DIR := "res://data"
const OUTPUT_PATH := "res://data/inkmon_content.json"


func _run() -> void:
	var auth := OS.get_environment("INKMON_CONTRACT_AUTH")
	if auth == "":
		push_error("[inkmon-import] INKMON_CONTRACT_AUTH env var not set (expected 'user:pass'); aborting.")
		return
	var url := OS.get_environment("INKMON_CONTRACT_URL")
	if url == "":
		url = DEFAULT_URL

	var result: Dictionary = await import_contract(EditorInterface.get_base_control(), url, auth)
	if not bool(result.get("ok", false)):
		push_error("[inkmon-import] %s" % str(result.get("error", "import failed")))
		return
	var species := result.get("species", PackedStringArray()) as PackedStringArray
	print(
		"[inkmon-import] wrote %s (%d unit(s): %s)"
			% [str(result.get("path", OUTPUT_PATH)), species.size(), ", ".join(species)]
	)


## Fetch the contract from `url` (Basic `auth` = "user:pass"), validate it, and write
## it to res://data/inkmon_content.json. `parent` hosts the transient HTTPRequest —
## EditorInterface.get_base_control() at dev time, or a scene Node for verification.
## Coroutine: await it. Returns {ok, path, species, error}.
static func import_contract(parent: Node, url: String, auth: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 30.0  # bound the await — a dead/hung server must not block forever
	parent.add_child(http)

	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(auth),
		"Accept: application/json",
	])
	var start_err := http.request(url, headers, HTTPClient.METHOD_GET)
	if start_err != OK:
		http.queue_free()
		return {"ok": false, "error": "HTTPRequest.request() failed to start: %d" % start_err}

	var response: Array = await http.request_completed
	http.queue_free()

	# response = [result, response_code, headers, body]
	var net_result := int(response[0])
	var http_code := int(response[1])
	var body: PackedByteArray = response[3]
	if net_result != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		return {"ok": false, "error": "fetch failed: result=%d http=%d" % [net_result, http_code]}

	var parsed := InkMonContentImporter.parse_and_validate(body.get_string_from_utf8())
	if not bool(parsed.get("ok", false)):
		return {
			"ok": false,
			"error": "contract failed validation: %s" % JSON.stringify(parsed.get("errors", [])),
		}

	var data: Dictionary = parsed.get("data", {})
	var write_err := _write_output(data)
	if write_err != "":
		return {"ok": false, "error": write_err}
	return {"ok": true, "path": OUTPUT_PATH, "species": _species_of(data)}


static func _write_output(data: Dictionary) -> String:
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		if mkdir_err != OK:
			return "could not create %s: %d" % [OUTPUT_DIR, mkdir_err]
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		return "could not open %s for write: %d" % [OUTPUT_PATH, FileAccess.get_open_error()]
	# Pretty-print so the res:// artifact is human-readable and diff-able.
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return ""


static func _species_of(data: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var units_value: Variant = data.get("units", [])
	if not (units_value is Array):
		return result
	for unit_value in (units_value as Array):
		if unit_value is Dictionary:
			# v2: identity = unit.id (= species_id). Reported for the dev import log.
			result.append(str((unit_value as Dictionary).get("id", "?")))
	return result
