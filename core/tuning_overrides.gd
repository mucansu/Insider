class_name TuningOverrides
extends RefCounted
## Field-level tuning overrides (IS-106, KR-037 per-map tuning): a level may override single fields of a global tuning resource
## (`data/**/*_tuning.tres` default) without copying the whole file. Node-free and generic: works on any Resource and an override
## dictionary {field name (String/StringName): value}. The global resource is never modified: overrides go to a copy (`apply`); no
## overrides -> the base itself (identical behaviour). Unknown fields and type mismatches are errors (`errors`; `apply` reports them with
## push_error and skips them). An int value is accepted for a float field (and converted).

## Copy of `base` with `fields` applied; `base` itself if `fields` is empty (or base is null). `label` prefixes error messages.
static func apply(base: Resource, fields: Dictionary, label: String = "") -> Resource:
	if base == null or fields.is_empty():
		return base
	for e: String in errors(base, fields, label):
		push_error(e)
	var copy: Resource = base.duplicate()
	var props: Dictionary = _props(base)
	for key: Variant in fields:
		var field: String = str(key)
		if not props.has(field) or not _fits(int(props[field]), fields[key]):
			continue
		var value: Variant = _coerce(int(props[field]), fields[key])
		var current: Variant = copy.get(field)
		if current is Array and value is Array:
			var typed: Array = (current as Array).duplicate()  # keeps the element type of a typed array
			typed.assign(value as Array)
			value = typed
		copy.set(field, value)
	return copy


## Problems of `fields` against `base` (unknown field, wrong value type); empty = valid.
static func errors(base: Resource, fields: Dictionary, label: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	if base == null:
		out.append("%sayar kaynağı yok" % _prefix(label))
		return out
	var props: Dictionary = _props(base)
	for key: Variant in fields:
		var field: String = str(key)
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			out.append("%salan adı metin değil: %s" % [_prefix(label), var_to_str(key)])
		elif not props.has(field):
			out.append("%sbilinmeyen alan: %s" % [_prefix(label), field])
		elif not _fits(int(props[field]), fields[key]):
			out.append("%s%s alanı %s bekler, %s geldi" % [_prefix(label), field, type_string(int(props[field])),
				type_string(typeof(fields[key]))])
	return out


## Script variables of the resource: name -> Variant type.
static func _props(base: Resource) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in base.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[str(p["name"])] = int(p["type"])
	return out


static func _fits(want: int, value: Variant) -> bool:
	var got: int = typeof(value)
	if want == TYPE_NIL or got == want:
		return true
	if want == TYPE_FLOAT and got == TYPE_INT:
		return true
	return (want == TYPE_STRING_NAME and got == TYPE_STRING) or (want == TYPE_STRING and got == TYPE_STRING_NAME)


static func _coerce(want: int, value: Variant) -> Variant:
	if want == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return float(value)
	if want == TYPE_STRING_NAME and typeof(value) == TYPE_STRING:
		return StringName(value)
	if want == TYPE_STRING and typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return value


static func _prefix(label: String) -> String:
	return "" if label.is_empty() else label + ": "
