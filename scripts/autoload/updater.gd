extends Node
## In-game updater. Must be the FIRST autoload: its _init() mounts downloaded patch packs
## (user://patches/*.pck) before any other game script or resource is loaded.
##
## Release layout (one rolling GitHub release tagged "updates"):
##   manifest.json            {"base": "m1.3", "full": {...}, "patches": [{"id","file","sha256","size","notes"}]}
##   MoiBanRaDay-<base>-windows.zip / -linux.tar.gz   full game (download once)
##   patch-0001.pck ...       small diffs exported with `godot --export-patch`

signal status(text: String)
signal update_ready(restart_needed: bool)

const PATCH_DIR := "user://patches"
const STATE := "user://patches/applied.json"

var base_id: String = ProjectSettings.get_setting("game/version_base", "dev")
var manifest_url: String = ProjectSettings.get_setting("game/update_manifest_url", "")
var applied: Array = []          ## patch ids mounted this run, in order
var busy := false

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="):
			manifest_url = a.trim_prefix("--update-url=")
	var st := _read_state()
	if st.get("base", "") != base_id:
		return  # patches belong to an older full build; ignore them
	for p in st.get("patches", []):
		var path := "%s/%s" % [PATCH_DIR, p.file]
		if FileAccess.file_exists(path) and ProjectSettings.load_resource_pack(path, true):
			applied.append(p.id)

func _ready() -> void:
	if "--print-version" in OS.get_cmdline_user_args():
		print("VERSION ", version_label(), " patches=", applied)
		if "--check" in OS.get_cmdline_user_args():
			status.connect(func(t): print("STATUS ", t))
			await check_for_updates()
		get_tree().quit()

func version_label() -> String:
	return base_id + ("" if applied.is_empty() else "+" + str(applied.back()))

func check_for_updates(quiet := false) -> void:
	if busy or manifest_url == "":
		if not quiet and manifest_url == "":
			status.emit("Chưa cấu hình máy chủ cập nhật.")
		return
	busy = true
	if not quiet:
		status.emit("Đang kiểm tra cập nhật…")
	var m = await _get_json(manifest_url)
	if m == null:
		busy = false
		if not quiet:
			status.emit("Không kết nối được máy chủ cập nhật.")
		return
	if m.get("base", "") != base_id:
		busy = false
		status.emit("Có bản đầy đủ mới (%s) — cần tải lại bản game đầy đủ một lần." % m.get("base", "?"))
		return
	var st := _read_state()
	var have: Array = st.get("patches", []).map(func(p): return p.id)
	var todo: Array = m.get("patches", []).filter(func(p): return not (p.id in have))
	if todo.is_empty():
		busy = false
		if not quiet:
			status.emit("Bạn đang dùng bản mới nhất (%s)." % version_label())
		return
	DirAccess.make_dir_recursive_absolute(PATCH_DIR)
	var base_url := manifest_url.get_base_dir()
	var total_kb := 0
	for p in todo:
		total_kb += int(p.get("size", 0)) / 1024
	status.emit("Đang tải %d bản vá (%d KB)…" % [todo.size(), total_kb])
	var list: Array = st.get("patches", [])
	for p in todo:
		var path := "%s/%s" % [PATCH_DIR, p.file]
		var ok := await _download(base_url + "/" + p.file, path)
		if not ok or _sha256(path) != p.sha256:
			DirAccess.remove_absolute(path)
			busy = false
			status.emit("Tải bản vá %s lỗi, thử lại sau." % p.id)
			return
		list.append({"id": p.id, "file": p.file})
	_write_state({"base": base_id, "patches": list})
	busy = false
	status.emit("Đã cập nhật xong — bấm F9 lần nữa để khởi động lại game.")
	update_ready.emit(true)

func restart() -> void:
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()

# ------------------------------------------------------------------ helpers
func _get_json(url: String):
	var http := HTTPRequest.new()
	http.max_redirects = 8
	http.timeout = 20.0
	add_child(http)
	if http.request(url) != OK:
		http.queue_free(); return null
	var r = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return null
	return JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())

func _download(url: String, path: String) -> bool:
	var http := HTTPRequest.new()
	http.max_redirects = 8
	http.timeout = 300.0
	http.download_file = path
	add_child(http)
	if http.request(url) != OK:
		http.queue_free(); return false
	var r = await http.request_completed
	http.queue_free()
	return r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200

static func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	while not f.eof_reached():
		h.update(f.get_buffer(1 << 20))
	return h.finish().hex_encode()

func _read_state() -> Dictionary:
	if not FileAccess.file_exists(STATE):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	return d if d is Dictionary else {}

func _write_state(d: Dictionary) -> void:
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))
