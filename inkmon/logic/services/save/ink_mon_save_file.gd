class_name InkMonSaveFile
extends RefCounted
## 主世界存档 IO helper(P7):JSON 读写 user:// 槽。
##
## 职责单一 = 字节层(open/store/parse)。序列化(to_dict/from_dict)是 InkMonWorldGI 的事 (adr/0001);
## 本类只管文件 —— 收/吐 Dictionary。返回 {ok, message, data?} —— 调用方据 ok 决定提示,不靠异常。


## 把存档 Dictionary 写到 path (gi.to_dict() 的产物)。返回 {ok, message}。
static func write(path: String, data: Dictionary) -> Dictionary:
	if data == null or data.is_empty():
		return {"ok": false, "message": "no save data to write"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "save open failed: %s" % str(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return {"ok": true, "message": "saved"}


## 从 path 读 JSON。返回 {ok, message, data}(data = 存档 Dictionary,供 gi.from_dict)。
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "save not found: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "load open failed: %s" % str(FileAccess.get_open_error())}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	var data := parsed as Dictionary
	if data == null:
		return {"ok": false, "message": "save json is not an object"}
	return {"ok": true, "message": "loaded", "data": data}
