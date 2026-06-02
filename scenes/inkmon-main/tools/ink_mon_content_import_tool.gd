@tool
class_name InkMonContentImportTool
extends EditorScript
## Dev-time import tool for the canon→godot bridge. Fetches the server creature-base
## contract, validates it through the shared importer, and writes it to
## res://data/inkmon_content.json — the local static content file read by
## InkMonSpeciesCatalog at runtime.
##
## Run it from the editor via Project → Tools → InkMon: 同步服务器内容. Auth + URL come from the
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
const LOCAL_ENV_PATHS := ["res://.env.local", "res://.env"]


func _run() -> void:
	var result: Dictionary = await import_from_environment(EditorInterface.get_base_control())
	if not bool(result.get("ok", false)):
		push_error("[inkmon-import] %s" % str(result.get("error", "import failed")))
		return
	InkMonSpeciesCatalog.clear_static_content_cache()
	print(format_result_message(result))


## Fetch the configured contract URL using credentials from environment variables.
## Coroutine: await it. Returns {ok, path, species, error}.
static func import_from_environment(parent: Node) -> Dictionary:
	var auth := configured_auth()
	if auth == "":
		return {
			"ok": false,
			"error": "INKMON_CONTRACT_AUTH env var not set (expected 'user:pass'); aborting.",
		}
	return await import_contract(parent, configured_url(), auth)


static func configured_url() -> String:
	var env_url := OS.get_environment("INKMON_CONTRACT_URL")
	if env_url != "":
		return env_url
	return local_env_value("INKMON_CONTRACT_URL", DEFAULT_URL)


static func configured_auth() -> String:
	var env_auth := OS.get_environment("INKMON_CONTRACT_AUTH")
	if env_auth != "":
		return env_auth
	return local_env_value("INKMON_CONTRACT_AUTH", "")


static func local_env_value(key: String, fallback: String = "") -> String:
	for path in LOCAL_ENV_PATHS:
		var value := _read_local_env_value(path, key)
		if value != "":
			return value
	return fallback


static func format_result_message(result: Dictionary) -> String:
	var species := result.get("species", PackedStringArray()) as PackedStringArray
	return "[inkmon-import] wrote %s (%d unit(s): %s)" % [
		str(result.get("path", OUTPUT_PATH)),
		species.size(),
		", ".join(species),
	]


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
	var non_finite_path := _first_non_finite_path(data, "$")
	if non_finite_path != "":
		return "contract contains NaN/INF at %s; refusing to write JSON" % non_finite_path
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


static func _first_non_finite_path(value: Variant, path: String) -> String:
	if value is float:
		var number := float(value)
		if is_nan(number) or is_inf(number):
			return path
		return ""
	if value is Dictionary:
		var dict_value: Dictionary = value
		for key in dict_value.keys():
			var found := _first_non_finite_path(dict_value[key], "%s.%s" % [path, str(key)])
			if found != "":
				return found
		return ""
	if value is Array:
		var array_value: Array = value
		for i in range(array_value.size()):
			var found := _first_non_finite_path(array_value[i], "%s[%d]" % [path, i])
			if found != "":
				return found
	return ""


static func _read_local_env_value(path: String, key: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var separator := line.find("=")
		if separator < 0:
			continue
		var line_key := line.substr(0, separator).strip_edges()
		if line_key != key:
			continue
		return _unquote_env_value(line.substr(separator + 1).strip_edges())
	return ""


static func _unquote_env_value(value: String) -> String:
	if value.length() < 2:
		return value
	var first := value.substr(0, 1)
	var last := value.substr(value.length() - 1, 1)
	if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
		return value.substr(1, value.length() - 2)
	return value


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
