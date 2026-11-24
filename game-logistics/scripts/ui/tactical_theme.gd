class_name TacticalTheme
extends RefCounted

const COL_PANEL: Color = Color("#232720EB")
const COL_PANEL_SOLID: Color = Color("#232720")
const COL_PANEL_DARK: Color = Color("#1a1e18F2")
const COL_BORDER: Color = Color("#4c5442")
const COL_BORDER_HI: Color = Color("#748063")
const COL_TEXT: Color = Color("#e6e2d3")
const COL_MUTED: Color = Color("#9fa694")
const COL_ACCENT: Color = Color("#d9a441")
const COL_FUEL: Color = Color("#d9a441")
const COL_AMMO: Color = Color("#739e4c")
const COL_OK: Color = Color("#739e4c")
const COL_CRITICAL: Color = Color("#c94a38")
const COL_FRIENDLY: Color = Color("#4a86c8")

const FONT_REGULAR_PATH: String = "res://assets/fonts/PTSansNarrow-Regular.ttf"
const FONT_BOLD_PATH: String = "res://assets/fonts/PTSansNarrow-Bold.ttf"
const FONT_MONO_PATH: String = "res://assets/fonts/IBMPlexMono-Regular.ttf"
const FONT_MONO_MED_PATH: String = "res://assets/fonts/IBMPlexMono-Medium.ttf"

static var _cached_fonts: Dictionary[String, Font] = {}
static var _cached_icons: Dictionary[String, Texture2D] = {}


static func get_regular_font() -> Font:
	return _load_font(FONT_REGULAR_PATH)


static func get_bold_font() -> Font:
	return _load_font(FONT_BOLD_PATH)


static func get_mono_font() -> Font:
	return _load_font(FONT_MONO_PATH)


static func get_mono_medium_font() -> Font:
	return _load_font(FONT_MONO_MED_PATH)


static func load_icon(icon_name: String) -> Texture2D:
	if _cached_icons.has(icon_name):
		return _cached_icons[icon_name]
	var path: String = "res://assets/icons/%s.svg" % icon_name
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_cached_icons[icon_name] = tex
	return tex


static func make_panel_box(bg_col: Color = COL_PANEL, border_col: Color = COL_BORDER, radius: int = 2, pad: int = 8) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg_col
	box.border_color = border_col
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	return box


static func make_bar_bg() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#151812")
	bg.border_color = Color("#394032")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	return bg


static func make_bar_fill(fill_col: Color) -> StyleBoxFlat:
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(1)
	return fg


static func build_theme() -> Theme:
	var theme: Theme = Theme.new()
	var reg_font: Font = get_regular_font()
	if reg_font != null:
		theme.default_font = reg_font
		theme.default_font_size = 14

	theme.set_stylebox("panel", "PanelContainer", make_panel_box(COL_PANEL, COL_BORDER, 2, 8))

	var btn_normal: StyleBoxFlat = make_panel_box(Color("#2d3328"), COL_BORDER, 2, 6)
	var btn_hover: StyleBoxFlat = make_panel_box(Color("#384031"), COL_BORDER_HI, 2, 6)
	var btn_pressed: StyleBoxFlat = make_panel_box(Color("#3e4835"), COL_ACCENT, 2, 6)
	var btn_disabled: StyleBoxFlat = make_panel_box(Color("#1d201a"), Color("#32382c"), 2, 6)

	for cls_name: String in ["Button", "OptionButton", "CheckBox"]:
		theme.set_stylebox("normal", cls_name, btn_normal)
		theme.set_stylebox("hover", cls_name, btn_hover)
		theme.set_stylebox("pressed", cls_name, btn_pressed)
		theme.set_stylebox("disabled", cls_name, btn_disabled)
		theme.set_stylebox("focus", cls_name, btn_hover)
		theme.set_color("font_color", cls_name, COL_TEXT)
		theme.set_color("font_hover_color", cls_name, COL_TEXT)
		theme.set_color("font_pressed_color", cls_name, COL_ACCENT)
		theme.set_color("font_disabled_color", cls_name, Color("#666d5e"))
		theme.set_font_size("font_size", cls_name, 14)

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 14)

	theme.set_color("default_color", "RichTextLabel", COL_TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)

	var popup_panel: StyleBoxFlat = make_panel_box(Color("#1f231cf5"), COL_BORDER_HI, 2, 4)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_stylebox("hover", "PopupMenu", make_panel_box(Color("#384031"), COL_ACCENT, 1, 4))
	theme.set_color("font_color", "PopupMenu", COL_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", COL_ACCENT)
	theme.set_font_size("font_size", "PopupMenu", 14)

	var sep_line: StyleBoxLine = StyleBoxLine.new()
	sep_line.color = COL_BORDER
	sep_line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_line)

	return theme


static func _load_font(path: String) -> Font:
	if _cached_fonts.has(path):
		return _cached_fonts[path]
	var f: Font = load(path) as Font
	if f != null:
		_cached_fonts[path] = f
	return f
