class_name Icons
extends RefCounted

## Texture registry for the sprite icon set in res://assets/sprites/.
##
## Every icon in the game is a real 256x256 PNG, not a font glyph. That is
## deliberate: the UI used to be built entirely from emoji, which meant a
## browser build (where Godot gets no system fonts) rendered the whole game as
## tofu boxes unless CI subset and bundled a Noto fallback at export time. A
## sprite sheet has none of that fragility and looks the same everywhere.
##
## Lookups are cached, so asking for the same icon in a hot refresh loop costs
## one dictionary hit rather than a ResourceLoader round trip.

const DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}


## Texture for `icon_name`, or null when the name is empty or unknown.
## A missing icon is never fatal: callers fall back to a text-only layout.
static func tex(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _cache.has(icon_name):
		return _cache[icon_name]
	var path := DIR + icon_name + ".png"
	var found: Texture2D = null
	if ResourceLoader.exists(path):
		found = ResourceLoader.load(path) as Texture2D
	else:
		push_warning("Icons: no sprite named '%s'" % icon_name)
	_cache[icon_name] = found
	return found


static func has(icon_name: String) -> bool:
	return tex(icon_name) != null


## Square TextureRect sized to `px`, kept aspect-correct and click-through.
static func rect(icon_name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(icon_name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r


## Icon that fills the space it is given rather than a fixed square.
static func fill(icon_name: String, tint: Color = Color.WHITE) -> TextureRect:
	var r := rect(icon_name, 0, tint)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r
