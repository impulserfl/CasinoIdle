extends Node

## Registers bundled fallback fonts for glyphs the default font lacks.
##
## The UI is built from emoji and symbol literals (reels, dice faces, property
## icons, scratch symbols). On desktop Godot resolves those through the OS font
## stack, but a browser gives the engine no system fonts at all, so an unbundled
## web build renders the whole game as tofu boxes.
##
## Two fonts are needed, not one: the dice faces (U+2680-2685) and playing-card
## glyphs live in Noto Sans Symbols, not Noto Color Emoji.
##
## CI builds these into assets/fonts/ at export time, subset to just the
## codepoints the project uses (see tools/emoji_codepoints.py); they are not
## committed. Everything here no-ops when the files are absent, so a plain
## desktop checkout is unaffected and keeps using the OS fonts.

const FALLBACK_FONTS: Array[String] = [
	"res://assets/fonts/emoji_fallback.ttf",
	"res://assets/fonts/symbols_fallback.ttf",
]


func _ready() -> void:
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return

	var chain: Array[Font] = base.fallbacks.duplicate()
	var added := 0
	for path in FALLBACK_FONTS:
		var font := _load_font(path)
		if font != null:
			chain.append(font)
			added += 1

	if added > 0:
		base.fallbacks = chain
		print("FontSetup: registered %d fallback font(s)" % added)


## Uses ResourceLoader.exists() rather than DirAccess so this works identically
## in an exported build, where res:// listings go through the pck remap table.
func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as Font
