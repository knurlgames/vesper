class_name TextTags
extends RefCounted
## Inline tags in dialogue text (ported from Nine Lives). Strips them and reports where they fire:
##   [wait=0.5]   pause typing for 0.5 s
##   [shake]      shake the box from here
##   [sfx=name]   play a sound (Audio, WO-022)
## Unknown [tags] are left in the text as written.

const KNOWN := ["wait", "shake", "sfx"]


## Returns {"text": plain text, "events": [{"at": char index, "kind", "value"}]}.
static func parse(text: String) -> Dictionary:
	var plain := ""
	var events: Array = []
	var i := 0
	while i < text.length():
		if text[i] == "[":
			var close := text.find("]", i)
			if close > i:
				var tag := text.substr(i + 1, close - i - 1)
				var kv := tag.split("=", true, 1)
				var kind := kv[0].strip_edges()
				if kind in KNOWN:
					var value: Variant = kv[1].strip_edges() if kv.size() > 1 else ""
					if kind == "wait":
						value = float(value) if str(value).is_valid_float() else 0.5
					events.append({"at": plain.length(), "kind": kind, "value": value})
					i = close + 1
					continue
		plain += text[i]
		i += 1
	return {"text": plain, "events": events}
