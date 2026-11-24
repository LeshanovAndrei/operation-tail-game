class_name TopoBackdrop
extends ColorRect

const MAP_ORIGIN: Vector2 = Vector2(-400.0, -400.0)
const MAP_SIZE: Vector2 = Vector2(3100.0, 2050.0)

var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	position = MAP_ORIGIN
	size = MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader: Shader = load("res://assets/shaders/topo_map.gdshader") as Shader
	if shader == null:
		return

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.set_shader_parameter("map_size", MAP_SIZE)
	_shader_mat.set_shader_parameter("grid_spacing", 128.0)
	_shader_mat.set_shader_parameter("night_factor", 0.0)

	_shader_mat.set_shader_parameter("height_map", _make_noise_texture(1042, 512, 0.0038, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_shader_mat.set_shader_parameter("forest_map", _make_noise_texture(2084, 512, 0.013, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_shader_mat.set_shader_parameter("grain_map", _make_noise_texture(3096, 256, 0.22, 2, FastNoiseLite.TYPE_VALUE))

	material = _shader_mat


func set_night_factor(factor: float) -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("night_factor", clampf(factor, 0.0, 1.0))


func _make_noise_texture(seed_val: int, tex_size: int, freq: float, octaves: int, noise_type: FastNoiseLite.NoiseType) -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = noise_type
	noise.frequency = freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	var img: Image = noise.get_seamless_image(tex_size, tex_size, false, false, 0.12)
	return ImageTexture.create_from_image(img)
