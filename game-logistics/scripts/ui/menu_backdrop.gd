class_name MenuBackdrop
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var map_rect: ColorRect = ColorRect.new()
	map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader: Shader = load("res://assets/shaders/topo_map.gdshader") as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("map_size", Vector2(1600.0, 1000.0))
		mat.set_shader_parameter("grid_spacing", 128.0)
		mat.set_shader_parameter("night_factor", 0.58)
		mat.set_shader_parameter("height_map", _make_noise_texture(1042, 512, 0.0038, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
		mat.set_shader_parameter("forest_map", _make_noise_texture(2084, 512, 0.013, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
		mat.set_shader_parameter("grain_map", _make_noise_texture(3096, 256, 0.22, 2, FastNoiseLite.TYPE_VALUE))
		map_rect.material = mat
	else:
		map_rect.color = Color("#1d2219")
	add_child(map_rect)

	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.08, 0.10, 0.07, 0.68)
	add_child(vignette)


func _make_noise_texture(seed_val: int, tex_size: int, freq: float, octaves: int, noise_type: FastNoiseLite.NoiseType) -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = noise_type
	noise.frequency = freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	var img: Image = noise.get_seamless_image(tex_size, tex_size, false, false, 0.12)
	return ImageTexture.create_from_image(img)
