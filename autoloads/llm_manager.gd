extends Node
## Async HTTP queue to Ollama with primary/fallback backend support.
## Primary: remote big model. Fallback: local small model. Last resort: heuristic.

signal ollama_status_changed(available: bool)
signal active_backend_changed(backend_name: String)

const CHAT_ENDPOINT := "/api/chat"
const TIMEOUT_SEC := 30.0
const HEALTH_RETRY_INTERVAL := 30.0

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2 }

# Backend definitions: tried in order (first available wins)
# Default: tiny local model (~1GB RAM) so anyone can run it
var backends: Array[Dictionary] = [
	{
		"name": "local",
		"url": "http://localhost:11434",
		"model": "smollm2:1.7b",  # ~1GB RAM, fast, good enough for personality
		"available": false,
		"temperature": 0.7,
		"num_predict": 150,
	},
]

var is_available: bool = false
var active_backend: Dictionary = {}
var active_backend_name: String = "none"

var _queue: Array[Dictionary] = []
var _processing: bool = false
var _http: HTTPRequest
var _health_timer: float = 0.0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_check_all_backends()


func _process(delta: float) -> void:
	# Periodically re-check backends that are down
	_health_timer += delta
	if _health_timer >= HEALTH_RETRY_INTERVAL:
		_health_timer = 0.0
		_check_all_backends()


func request_chat(messages: Array, format: Dictionary, callback: Callable, priority: int = Priority.NORMAL, metadata: Dictionary = {}) -> void:
	var entry := {
		"messages": messages,
		"format": format,
		"callback": callback,
		"priority": priority,
		"metadata": metadata,
	}
	var inserted := false
	for i in range(_queue.size()):
		if _queue[i]["priority"] < priority:
			_queue.insert(i, entry)
			inserted = true
			break
	if not inserted:
		_queue.append(entry)
	_process_next()


func get_queue_size() -> int:
	return _queue.size()


func get_status_text() -> String:
	if not is_available:
		return "LLM: Offline"
	return "LLM: %s (%s)" % [active_backend_name.capitalize(), active_backend.get("model", "?")]


func _check_all_backends() -> void:
	for backend in backends:
		_check_backend_health(backend)


func _check_backend_health(backend: Dictionary) -> void:
	var check_http := HTTPRequest.new()
	check_http.timeout = 5.0
	add_child(check_http)
	var backend_name: String = backend["name"]
	check_http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		backend["available"] = (code == 200)
		check_http.queue_free()
		_update_active_backend()
	)
	check_http.request(str(backend["url"]), [], HTTPClient.METHOD_GET)


func _update_active_backend() -> void:
	var was_available := is_available
	var old_name := active_backend_name

	# Pick the first available backend (priority order)
	active_backend = {}
	active_backend_name = "none"
	is_available = false
	for backend in backends:
		if backend["available"]:
			active_backend = backend
			active_backend_name = backend["name"]
			is_available = true
			break

	if is_available != was_available:
		ollama_status_changed.emit(is_available)
	if active_backend_name != old_name:
		active_backend_changed.emit(active_backend_name)
		if is_available:
			print("[LLMManager] Using %s backend: %s @ %s" % [
				active_backend_name, active_backend["model"], active_backend["url"]
			])
		# Try to process queued requests now that we have a backend
		_process_next()


func _process_next() -> void:
	if _processing or _queue.is_empty():
		return
	if not is_available:
		while not _queue.is_empty():
			var entry: Dictionary = _queue.pop_front()
			entry["callback"].call(false, {}, "No LLM backend available")
		return
	_processing = true
	var entry: Dictionary = _queue.pop_front()
	var body := {
		"model": active_backend.get("model", "llama3.2:3b"),
		"messages": entry["messages"],
		"stream": false,
		"keep_alive": "30m",
		"options": {
			"temperature": active_backend.get("temperature", 0.7),
			"num_predict": active_backend.get("num_predict", 200),
		},
	}
	if not entry["format"].is_empty():
		body["format"] = entry["format"]
	var json_body := JSON.stringify(body)
	var headers := ["Content-Type: application/json"]
	var url: String = active_backend.get("url", "http://localhost:11434")
	_http.set_meta("current_callback", entry["callback"])
	_http.set_meta("current_backend", active_backend_name)
	_http.request(url + CHAT_ENDPOINT, headers, HTTPClient.METHOD_POST, json_body)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var callback: Callable = _http.get_meta("current_callback")
	var used_backend: String = _http.get_meta("current_backend")
	_processing = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_msg := "HTTP error on %s: result=%d, code=%d" % [used_backend, result, response_code]
		# Mark this backend as down and re-check
		for backend in backends:
			if backend["name"] == used_backend:
				backend["available"] = false
		_update_active_backend()
		# If another backend is now active, re-queue this request
		if is_available and used_backend != active_backend_name:
			# Re-submit to the new backend
			var messages: Array = []
			var format := {}
			# Can't recover original request data, so just fail gracefully
			callback.call(false, {}, error_msg)
		else:
			callback.call(false, {}, error_msg)
		_process_next()
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		callback.call(false, {}, "JSON parse error")
		_process_next()
		return

	var data: Dictionary = json.data
	var message: Dictionary = data.get("message", {})
	var content_str: String = message.get("content", "")

	var content_json := JSON.new()
	if content_json.parse(content_str) == OK:
		callback.call(true, content_json.data, "")
	else:
		callback.call(true, {"raw": content_str}, "")

	_process_next()


func retry_health_check() -> void:
	_check_all_backends()
