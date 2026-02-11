class_name PromptBuilder
## Loads prompt templates and fills {token} placeholders.

static var _cache: Dictionary = {}


static func build(template_name: String, tokens: Dictionary) -> String:
	var template := _load_template(template_name)
	for key in tokens:
		template = template.replace("{%s}" % key, str(tokens[key]))
	return template


static func _load_template(template_name: String) -> String:
	if _cache.has(template_name):
		return _cache[template_name]
	var path := "res://resources/prompts/%s.txt" % template_name
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("PromptBuilder: Failed to load template '%s'" % template_name)
		return ""
	var content := file.get_as_text()
	_cache[template_name] = content
	return content
