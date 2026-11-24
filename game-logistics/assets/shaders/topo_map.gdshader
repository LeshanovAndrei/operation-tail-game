shader_type canvas_item;

uniform sampler2D height_map : repeat_enable, filter_linear;
uniform sampler2D forest_map : repeat_enable, filter_linear;
uniform sampler2D grain_map : repeat_enable, filter_linear;
uniform vec2 map_size = vec2(2600.0, 1800.0);
uniform float grid_spacing = 128.0;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 world_px = UV * map_size;
	vec2 h_uv = UV * 0.72;
	vec2 f_uv = UV * 1.65 + vec2(0.17, 0.31);
	vec2 g_uv = world_px / 256.0;

	float h = texture(height_map, h_uv).r;
	float f = texture(forest_map, f_uv).r;
	float g = texture(grain_map, g_uv).r;

	// Soft directional hillshading (NW light)
	float eps = 0.004;
	float hx = texture(height_map, h_uv + vec2(eps, 0.0)).r - texture(height_map, h_uv - vec2(eps, 0.0)).r;
	float hy = texture(height_map, h_uv + vec2(0.0, eps)).r - texture(height_map, h_uv - vec2(0.0, eps)).r;
	float hillshade = clamp((hx * 9.0 + hy * 9.0), -0.09, 0.09);

	// Warm parchment base + highland tint + soft olive forest patches
	vec3 col_parchment = vec3(0.784, 0.761, 0.659); // #c8c2a8
	vec3 col_highland = vec3(0.722, 0.686, 0.573);  // #b8af92
	vec3 col_forest = vec3(0.616, 0.659, 0.525);    // #9da886

	float elev_t = smoothstep(0.44, 0.78, h);
	vec3 base_col = mix(col_parchment, col_highland, elev_t);

	float forest_mask = smoothstep(0.55, 0.65, f) * (1.0 - smoothstep(0.76, 0.90, h) * 0.45);
	base_col = mix(base_col, col_forest, forest_mask * 0.80);
	base_col += vec3(hillshade * 0.34);

	// Sparse, soft topographic contour isolines (no noisy zebra effect)
	float levels = 6.0;
	float scaled_h = h * levels;
	float dist_minor = abs(fract(scaled_h + 0.5) - 0.5);
	float fw_minor = max(fwidth(scaled_h), 0.012);
	float minor_line = 1.0 - smoothstep(0.0, fw_minor * 1.1, dist_minor);

	float scaled_major = h * (levels * 0.5);
	float dist_major = abs(fract(scaled_major + 0.5) - 0.5);
	float fw_major = max(fwidth(scaled_major), 0.010);
	float major_line = 1.0 - smoothstep(0.0, fw_major * 1.35, dist_major);

	vec3 col_contour = vec3(0.455, 0.388, 0.282);
	base_col = mix(base_col, col_contour, minor_line * 0.14);
	base_col = mix(base_col, col_contour * 0.85, major_line * 0.21);

	// Subtle paper grain
	base_col += (g - 0.5) * 0.032;

	// Delicate kilometer coordinate grid
	vec2 grid_pos = mod(world_px, grid_spacing);
	float gx = min(grid_pos.x, grid_spacing - grid_pos.x);
	float gy = min(grid_pos.y, grid_spacing - grid_pos.y);
	float grid_line = 1.0 - smoothstep(0.0, 1.15, min(gx, gy));
	vec3 col_grid = vec3(0.32, 0.34, 0.27);
	base_col = mix(base_col, col_grid, grid_line * 0.20);

	// Atmospheric night shift preserving map legibility
	vec3 night_tint = base_col * vec3(0.48, 0.54, 0.66);
	base_col = mix(base_col, night_tint, night_factor * 0.72);

	COLOR = vec4(base_col, 1.0);
}
