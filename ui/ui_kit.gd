class_name UIKit
extends RefCounted

## Widget builders + the game's colour palette.
##
## The whole UI is constructed in code rather than in .tscn files. That keeps
## node paths impossible to typo and makes the layout diffable in review.

# --- palette ---------------------------------------------------------------
const BG := Color("0b0d15")
const PANEL := Color("161b2b")
const PANEL_HI := Color("1e2539")
const PANEL_EDGE := Color("2b3450")
const TEXT := Color("e6eaf4")
const DIM := Color("8891a8")
const GOLD := Color("ffd24a")
const GREEN := Color("5fe0a0")
const RED := Color("ff6b7a")
const BLUE := Color("62c8ff")
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
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func wrapped(text: String, size: int = 14, color: Color = DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# --- containers ------------------------------------------------------------
static func stylebox(bg: Color, radius: int = 10, border: int = 0,
		border_color: Color = PANEL_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border > 0:
		sb.border_width_left = border
		sb.border_width_right = border
		sb.border_width_top = border
		sb.border_width_bottom = border
		sb.border_color = border_color
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func panel(bg: Color = PANEL, radius: int = 10, border: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(bg, radius, border))
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

	var normal := stylebox(PANEL_HI, 8, 1, PANEL_EDGE)
	var hover := stylebox(PANEL_HI.lerp(accent, 0.22), 8, 1, accent)
	var pressed := stylebox(PANEL_HI.lerp(accent, 0.4), 8, 1, accent)
	var disabled := stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.55), 8, 1, Color(PANEL_EDGE, 0.4))

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", stylebox(Color(0, 0, 0, 0), 8, 0))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	return b


static func primary_button(text: String, size: int = 20, accent: Color = GOLD) -> Button:
	var b := button(text, size, accent)
	b.add_theme_stylebox_override("normal", stylebox(accent.darkened(0.55), 10, 2, accent.darkened(0.2)))
	b.add_theme_stylebox_override("hover", stylebox(accent.darkened(0.4), 10, 2, accent))
	b.add_theme_stylebox_override("pressed", stylebox(accent.darkened(0.25), 10, 2, accent))
	b.add_theme_stylebox_override("disabled", stylebox(Color(PANEL.r, PANEL.g, PANEL.b, 0.6), 10, 1, Color(PANEL_EDGE, 0.4)))
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
