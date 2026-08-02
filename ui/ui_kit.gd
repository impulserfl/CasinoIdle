class_name UIKit
extends RefCounted

## Palette and widget builders.
##
## The colours here are the same values the sprite icons were drawn with, so
## artwork and chrome stay in one visual system instead of drifting apart.

# --- palette ---------------------------------------------------------------
const BG := Color("0b1018")
const BG_DEEP := Color("070a10")
const PANEL := Color("16202f")
const PANEL_HI := Color("1e2b3e")
const PANEL_SUNK := Color("101724")
const PANEL_EDGE := Color("2c3b52")
const PANEL_GLOW := Color("3e5375")
const FELT := Color("14432f")
const FELT_EDGE := Color("1e6647")

const TEXT := Color("e6ecf5")
const DIM := Color("7c8aa3")
const FAINT := Color("4d5b73")

const GOLD := Color("e8b84b")
const GOLD_HI := Color("f7de9b")
const GOLD_LO := Color("a87b22")
const GREEN := Color("3fbf7f")
const RED := Color("d9455f")
const BLUE := Color("4a9ee8")
const PURPLE := Color("a06be0")
const ORANGE := Color("f0883e")
const CYAN := Color("47d6d6")

## Rarity ramp, used for prize tiers and win sizes so colour always means the
## same thing to the player regardless of which table they are sitting at.
const TIER_COLORS: Array[Color] = [DIM, GREEN, BLUE, PURPLE, ORANGE, GOLD]


static func tier_color(multiplier: float) -> Color:
	if multiplier >= 100.0:
		return GOLD
	if multiplier >= 25.0:
		return ORANGE
	if multiplier >= 8.0:
		return PURPLE
	if multiplier >= 3.0:
		return BLUE
	if multiplier > 0.0:
		return GREEN
	return DIM


# --- text ------------------------------------------------------------------
static func label(text: String, size: int = 16, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 24, color: Color = GOLD) -> Label:
	var l := label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func numeral(text: String, size: int = 28, color: Color = GOLD,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	## Big readable figure with an outline so it survives busy backgrounds.
	var l := label(text, size, color, align)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func wrapped(text: String, size: int = 14, color: Color = DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# --- icons -----------------------------------------------------------------
static func icon(icon_name: String, px: int = 28, tint: Color = Color.WHITE) -> TextureRect:
	return Icons.rect(icon_name, px, tint)


## Icon + text on one line, the standard way a label is introduced in this UI.
static func icon_row(icon_name: String, text: String, size: int = 16,
		color: Color = TEXT, px: int = 0) -> HBoxContainer:
	var row := hbox(8)
	row.add_child(icon(icon_name, px if px > 0 else int(size * 1.5)))
	var l := label(text, size, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## Icon sitting on a recessed rounded tile — used for property and table rows.
static func icon_tile(icon_name: String, tile_px: int = 56, icon_px: int = 34,
		bg: Color = PANEL_SUNK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stylebox(bg, 10, 1, PANEL_EDGE)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_size = 0
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(tile_px, tile_px)
	var r := icon(icon_name, icon_px)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(r)
	return p


# --- containers ------------------------------------------------------------
static func stylebox(bg: Color, radius: int = 12, border: int = 0,
		border_color: Color = PANEL_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func panel(bg: Color = PANEL, radius: int = 12, border: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	var edge := PANEL_GLOW if bg == PANEL_HI else PANEL_EDGE
	p.add_theme_stylebox_override("panel", stylebox(bg, radius, border, edge))
	return p


## Panel with a coloured left edge, for drawing the eye to a status block.
static func accent_panel(accent: Color, bg: Color = PANEL_HI, radius: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stylebox(bg, radius, 0)
	sb.border_width_left = 4
	sb.border_color = accent
	sb.content_margin_left = 16
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dark inset well — the felt/screen surface a game board sits on.
static func well(bg: Color = PANEL_SUNK, radius: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stylebox(bg, radius, 1, PANEL_EDGE)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, -2)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func grid(columns: int, h_sep: int = 10, v_sep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", h_sep)
	g.add_theme_constant_override("v_separation", v_sep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func separator(color: Color = PANEL_EDGE) -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


# --- buttons ---------------------------------------------------------------
static func button(text: String, size: int = 16, accent: Color = BLUE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE

	var normal := stylebox(PANEL_HI, 10, 1, PANEL_EDGE)
	normal.shadow_size = 2
	var hover := stylebox(PANEL_HI.lerp(accent, 0.26), 10, 1, accent)
	hover.shadow_size = 5
	var pressed := stylebox(PANEL_HI.lerp(accent, 0.44), 10, 1, accent.lightened(0.15))
	pressed.shadow_size = 0
	var disabled := stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.5), 10, 1, Color(PANEL_EDGE, 0.3))
	disabled.shadow_size = 0

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", stylebox(Color(0, 0, 0, 0), 10, 0))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.4))
	return b


static func primary_button(text: String, size: int = 20, accent: Color = GOLD) -> Button:
	var b := button(text, size, accent)
	var n := stylebox(accent.darkened(0.55), 12, 2, accent.darkened(0.12))
	n.shadow_color = Color(accent, 0.22)
	n.shadow_size = 8
	var h := stylebox(accent.darkened(0.38), 12, 2, accent)
	h.shadow_color = Color(accent, 0.34)
	h.shadow_size = 12
	var p := stylebox(accent.darkened(0.22), 12, 2, accent.lightened(0.12))
	p.shadow_size = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled",
		stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.55), 12, 1, Color(PANEL_EDGE, 0.35)))
	b.add_theme_color_override("font_color", accent.lightened(0.6))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


## Button carrying a sprite icon to the left of its label.
static func icon_button(icon_name: String, text: String, size: int = 16,
		accent: Color = BLUE, icon_px: int = 22) -> Button:
	var b := button(text, size, accent)
	b.icon = Icons.tex(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_constant_override("icon_max_width", icon_px)
	return b


## Small square button that is only an icon — used for toggles and steppers.
static func glyph_button(icon_name: String, px: int = 36, accent: Color = BLUE,
		icon_px: int = 20) -> Button:
	var b := button("", 14, accent)
	b.icon = Icons.tex(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", icon_px)
	b.custom_minimum_size = Vector2(px, px)
	return b


## Segmented control. Returns the container; `out_buttons` is filled id -> Button.
static func segmented(ids: Array, labels: Array, out_buttons: Dictionary,
		accent: Color = GOLD, min_width: int = 62, height: int = 34) -> HBoxContainer:
	var row := hbox(4)
	for i in range(ids.size()):
		var b := button(String(labels[i]), 14, accent)
		b.custom_minimum_size = Vector2(min_width, height)
		out_buttons[ids[i]] = b
		row.add_child(b)
	return row


## Paint a segmented control so `selected` reads as active.
static func segmented_select(buttons: Dictionary, selected: Variant, accent: Color = GOLD) -> void:
	for id in buttons:
		var b: Button = buttons[id]
		var on: bool = id == selected
		b.add_theme_color_override("font_color", accent if on else DIM)
		var sb := stylebox(PANEL_HI.lerp(accent, 0.30) if on else PANEL, 10, 1,
			accent if on else PANEL_EDGE)
		sb.shadow_size = 3 if on else 1
		b.add_theme_stylebox_override("normal", sb)


# --- readouts --------------------------------------------------------------
static func progress_bar(fill: Color = GOLD, height: int = 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.max_value = 1.0
	p.step = 0.0001
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_SUNK
	bg.set_corner_radius_all(int(height / 2.0))
	bg.set_border_width_all(1)
	bg.border_color = PANEL_EDGE
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(int(height / 2.0))
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


## Compact icon + value + caption block for the top bar and stat strips.
static func stat_tile(icon_name: String, value: String, caption: String,
		accent: Color = GOLD, value_size: int = 20) -> PanelContainer:
	var p := panel(PANEL_HI, 10, 1)
	var row := hbox(10)
	row.add_child(icon(icon_name, 26))
	var col := vbox(0)
	col.add_child(numeral(value, value_size, accent))
	col.add_child(label(caption, 11, DIM))
	row.add_child(col)
	p.add_child(row)
	return p


# --- playing cards ---------------------------------------------------------
const CARD_FACE := Color("e8eef7")
const CARD_EDGE := Color("aebbd0")
const CARD_INK := Color("121a28")

const SUIT_NAMES: Array[String] = ["suit_spade", "suit_heart", "suit_diamond", "suit_club"]
const RANK_NAMES: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]


## A playing card built from an ASCII rank and a suit sprite.
##
## Cards used to be text like "A@" using Unicode suit glyphs, which is the same
## trap the emoji UI fell into: a browser gives Godot no system fonts, so those
## glyphs render as tofu. Ranks here are plain ASCII and suits are sprites.
static func card(width: int = 62, height: int = 86) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, height)
	var sb := stylebox(CARD_FACE, 8, 2, CARD_EDGE)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)

	var col := vbox(0)
	var rank := label("", int(height * 0.30), CARD_INK, HORIZONTAL_ALIGNMENT_CENTER)
	rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(rank)
	var suit := Icons.rect("", int(height * 0.34))
	suit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(suit)
	p.add_child(col)

	p.set_meta("rank_label", rank)
	p.set_meta("suit_icon", suit)
	p.set_meta("face", sb)
	return p


static func set_card(p: PanelContainer, rank_index: int, suit_index: int) -> void:
	if p == null or not p.has_meta("rank_label"):
		return
	var rank: Label = p.get_meta("rank_label")
	var suit: TextureRect = p.get_meta("suit_icon")
	var suit_name := SUIT_NAMES[clampi(suit_index, 0, 3)]
	rank.text = RANK_NAMES[clampi(rank_index, 0, 12)]
	rank.add_theme_color_override("font_color",
		RED if suit_name in ["suit_heart", "suit_diamond"] else CARD_INK)
	rank.visible = true
	suit.texture = Icons.tex(suit_name)
	suit.visible = true
	p.add_theme_stylebox_override("panel", p.get_meta("face"))


static func set_card_back(p: PanelContainer) -> void:
	if p == null or not p.has_meta("rank_label"):
		return
	var rank: Label = p.get_meta("rank_label")
	var suit: TextureRect = p.get_meta("suit_icon")
	rank.visible = false
	suit.texture = Icons.tex("card_back")
	suit.visible = true


static func slider(min_value: float, max_value: float, step: float = 0.01) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 24)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = GOLD
	grabber.set_corner_radius_all(8)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = PANEL_SUNK
	slider_bg.set_corner_radius_all(4)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", slider_bg)
	s.add_theme_stylebox_override("grabber_area", grabber)
	s.add_theme_stylebox_override("grabber_area_highlight", grabber)
	return s
