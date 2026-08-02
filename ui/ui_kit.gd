class_name UIKit
extends RefCounted

## Widget builders + casino colour palette.

# --- palette ---------------------------------------------------------------
const BG := Color("07090f")
const BG_TOP := Color("0e1320")
const PANEL := Color("12182a")
const PANEL_HI := Color("1a2238")
const PANEL_EDGE := Color("2e3a5c")
const PANEL_GLOW := Color("3d4f7a")
const TEXT := Color("eef1f8")
const DIM := Color("8b95ad")
const GOLD := Color("ffd24a")
const GOLD_DIM := Color("c9a227")
const GREEN := Color("4fef9e")
const RED := Color("ff6b7a")
const BLUE := Color("5ec8ff")
const PURPLE := Color("c792ea")
const ORANGE := Color("ff9f4a")
const CYAN := Color("4fe3d4")


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
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func wrapped(text: String, size: int = 14, color: Color = DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


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
	# Soft shadow for depth
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func panel(bg: Color = PANEL, radius: int = 12, border: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	var edge := PANEL_GLOW if bg == PANEL_HI else PANEL_EDGE
	p.add_theme_stylebox_override("panel", stylebox(bg, radius, border, edge))
	return p


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_EDGE
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
	var hover := stylebox(PANEL_HI.lerp(accent, 0.28), 10, 1, accent)
	hover.shadow_size = 4
	var pressed := stylebox(PANEL_HI.lerp(accent, 0.45), 10, 1, accent)
	var disabled := stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.55), 10, 1, Color(PANEL_EDGE, 0.35))
	disabled.shadow_size = 0

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", stylebox(Color(0, 0, 0, 0), 10, 0))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.45))
	return b


static func primary_button(text: String, size: int = 20, accent: Color = GOLD) -> Button:
	var b := button(text, size, accent)
	var n := stylebox(accent.darkened(0.52), 12, 2, accent.darkened(0.15))
	n.shadow_color = Color(accent, 0.25)
	n.shadow_size = 8
	var h := stylebox(accent.darkened(0.35), 12, 2, accent)
	h.shadow_color = Color(accent, 0.35)
	h.shadow_size = 10
	var p := stylebox(accent.darkened(0.2), 12, 2, accent.lightened(0.1))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.6), 12, 1, Color(PANEL_EDGE, 0.4)))
	b.add_theme_color_override("font_color", accent.lightened(0.55))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


# --- misc ------------------------------------------------------------------
static func progress_bar(fill: Color = GOLD, height: int = 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.max_value = 1.0
	p.step = 0.0001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0a0d16")
	bg.set_corner_radius_all(height / 2)
	bg.set_border_width_all(1)
	bg.border_color = PANEL_EDGE
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(height / 2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


static func icon_label(icon: String, size: int = 32) -> Label:
	var l := label(icon, size, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
