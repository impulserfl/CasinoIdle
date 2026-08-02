extends Node

## Registers an emoji fallback font.
##
## The entire UI is emoji-driven (reels, dice faces, property icons, scratch
## symbols). On desktop Godot resolves those glyphs through the OS font stack,
## but a browser gives the engine no system fonts at all, so an unbundled web
## build renders the whole game as tofu boxes.
##
## The font is fetched by CI into assets/fonts/ at build time rather than
## committed, so this degrades gracefully: if the file is absent (a normal
## desktop checkout) we simply leave the default font alone and let the OS
## handle it.

const EMOJI_FONT_PATH := "res://assets/fonts/NotoEmoji-Regular.ttf"


func _ready() -> void:
	var emoji := _load_emoji_font()
	if emoji == null:
		return
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return
	var chain: Array[Font] = base.fallbacks.duplicate()
	chain.append(emoji)
	base.fallbacks = chain


func _load_emoji_font() -> Font:
	if not ResourceLoader.exists(EMOJI_FONT_PATH):
		return null
	var res := ResourceLoader.load(EMOJI_FONT_PATH)
	return res as Font
