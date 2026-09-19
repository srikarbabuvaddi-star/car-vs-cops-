shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Real City Avenue Grid & Vibrant Garden Park Environment
uniform vec4 asphalt_color : source_color = vec4(0.08, 0.10, 0.14, 1.0);
uniform vec4 yellow_line_color : source_color = vec4(1.0, 0.75, 0.08, 1.0);
uniform vec4 white_line_color : source_color = vec4(0.94, 0.96, 1.0, 1.0);
uniform vec4 curb_glow_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);

// Garden Park Palette
uniform vec4 grass_dark : source_color = vec4(0.18, 0.42, 0.16, 1.0);
uniform vec4 grass_light : source_color = vec4(0.26, 0.56, 0.22, 1.0);
uniform vec4 hedge_color : source_color = vec4(0.11, 0.28, 0.10, 1.0);
uniform vec4 sidewalk_color : source_color = vec4(0.70, 0.74, 0.78, 1.0);
uniform vec4 sidewalk_line : source_color = vec4(0.50, 0.54, 0.58, 1.0);
uniform vec4 path_color : source_color = vec4(0.48, 0.44, 0.40, 1.0);

uniform float block_size = 56.0;        // Spacing between avenue centers
uniform float road_half_width = 10.0;   // 20m wide multi-lane avenues
uniform float sidewalk_width = 2.4;     // Concrete sidewalk border
uniform float vignette_radius = 500.0;

varying vec3 world_pos;

// High-speed pseudo-random hash
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 pos = world_pos.xz;

	// Avenue Grid Coordinates (centered around each avenue at 0.0)
	vec2 cell = floor((pos + block_size * 0.5) / block_size);
	vec2 local_pos = pos - cell * block_size;
	vec2 abs_local = abs(local_pos);

	// Road mask: true if on horizontal or vertical avenue
	bool on_road_x = abs_local.y <= road_half_width;
	bool on_road_z = abs_local.x <= road_half_width;
	bool is_road = on_road_x || on_road_z;
	bool is_intersection = on_road_x && on_road_z;

	vec3 surface = vec3(0.0);
	vec3 emission = vec3(0.0);
	float surf_roughness = 0.7;

	if (is_road) {
		// --- ASPHALT ROADWAY ---
		float grain = hash(floor(pos * 8.0)) * 0.08 + hash(floor(pos * 32.0)) * 0.04;
		surface = asphalt_color.rgb + vec3(grain);
		surf_roughness = 0.55;

		// 1. DOUBLE SOLID YELLOW MEDIAN LINES
		float yellow_lines = 0.0;
		if (on_road_x) {
			float dist_from_center = abs_local.y;
			if (abs(dist_from_center - 0.18) <= 0.07 || abs(dist_from_center - 0.42) <= 0.07) {
				if (!is_intersection || abs_local.x > road_half_width * 0.75) {
					yellow_lines = 1.0;
				}
			}
		}
		if (on_road_z) {
			float dist_from_center = abs_local.x;
			if (abs(dist_from_center - 0.18) <= 0.07 || abs(dist_from_center - 0.42) <= 0.07) {
				if (!is_intersection || abs_local.y > road_half_width * 0.75) {
					yellow_lines = 1.0;
				}
			}
		}

		// 2. DASHED WHITE LANE DIVIDERS (4 distinct lanes)
		float white_dashed = 0.0;
		if (on_road_x && !is_intersection) {
			if (abs(abs_local.y - 5.0) <= 0.08) {
				if (fract(pos.x * 0.125) <= 0.5) {
					white_dashed = 1.0;
				}
			}
		}
		if (on_road_z && !is_intersection) {
			if (abs(abs_local.x - 5.0) <= 0.08) {
				if (fract(pos.y * 0.125) <= 0.5) {
					white_dashed = 1.0;
				}
			}
		}

		// 3. SOLID WHITE SHOULDER LINES
		float white_edge = 0.0;
		if (on_road_x && !is_intersection) {
			if (abs(abs_local.y - (road_half_width - 0.8)) <= 0.10) {
				white_edge = 1.0;
			}
		}
		if (on_road_z && !is_intersection) {
			if (abs(abs_local.x - (road_half_width - 0.8)) <= 0.10) {
				white_edge = 1.0;
			}
		}

		// 4. INTERSECTION ZEBRA CROSSWALKS
		float zebra = 0.0;
		if (is_road && !is_intersection) {
			if (on_road_x && abs(abs_local.x - (road_half_width + 1.6)) <= 1.2) {
				if (fract(pos.y * 0.8) <= 0.5) {
					zebra = 1.0;
				}
			}
			if (on_road_z && abs(abs_local.y - (road_half_width + 1.6)) <= 1.2) {
				if (fract(pos.x * 0.8) <= 0.5) {
					zebra = 1.0;
				}
			}
		}

		if (yellow_lines > 0.5) {
			surface = yellow_line_color.rgb;
			emission += yellow_line_color.rgb * 0.85;
		} else if (white_dashed > 0.5 || white_edge > 0.5 || zebra > 0.5) {
			surface = white_line_color.rgb;
			emission += white_line_color.rgb * 0.65;
		}

		// Glowing curb edge
		float curb_glow = 0.0;
		if (!is_intersection) {
			if (on_road_x && abs(abs_local.y - road_half_width) <= 0.25) {
				curb_glow = 1.0;
			}
			if (on_road_z && abs(abs_local.x - road_half_width) <= 0.25) {
				curb_glow = 1.0;
			}
		} else {
			float corner_dist = length(abs_local - vec2(road_half_width));
			if (abs(corner_dist - 0.3) <= 0.2) {
				curb_glow = 1.0;
			}
		}

		if (curb_glow > 0.5) {
			surface = mix(surface, curb_glow_color.rgb, 0.85);
			emission += curb_glow_color.rgb * 2.0;
		}

	} else {
		// --- VIBRANT GARDEN PARK AREA BETWEEN ROADS ---
		float dist_from_road_x = abs_local.x - road_half_width;
		float dist_from_road_y = abs_local.y - road_half_width;
		float min_dist = min(dist_from_road_x, dist_from_road_y);

		if (min_dist <= sidewalk_width) {
			// Concrete Sidewalk Buffer
			float flagstone = step(min(fract(pos.x * 0.4), fract(pos.y * 0.4)), 0.04);
			surface = mix(sidewalk_color.rgb, sidewalk_line.rgb, flagstone * 0.55);
			surf_roughness = 0.8;
		} else {
			// Garden Park Interior
			float hedge_dist = min_dist - sidewalk_width;
			if (hedge_dist <= 1.0) {
				// Dark leafy perimeter hedge border
				float leaf_noise = hash(floor(pos * 6.0)) * 0.15;
				surface = hedge_color.rgb + vec3(leaf_noise * 0.5);
				surf_roughness = 0.9;
			} else {
				// Lush Turf Grass
				float turf_noise = hash(floor(pos * 4.0)) * 0.12 + hash(floor(pos * 16.0)) * 0.05;
				// Subtle mown lawn diagonal striping
				float mown = fract((pos.x + pos.y) * 0.15) <= 0.5 ? 0.06 : -0.03;
				vec3 grass = mix(grass_dark.rgb, grass_light.rgb, 0.5 + mown + turf_noise);
				surface = grass;
				surf_roughness = 0.85;

				// Winding Central Gravel Footpath
				float path_dist = abs(abs_local.x - abs_local.y);
				if (path_dist <= 1.2 && min_dist > 3.5) {
					float gravel = hash(floor(pos * 10.0)) * 0.1;
					surface = path_color.rgb + vec3(gravel);
					surf_roughness = 0.95;
				} else {
					// Scattered Flowerbed Clusters (Roses, Marigolds, Lilies)
					vec2 flower_grid = floor(pos * 0.5);
					float f_hash = hash(flower_grid);
					if (f_hash > 0.80) {
						vec3 flower_col = vec3(0.92, 0.18, 0.45); // Rose magenta
						if (f_hash > 0.92) {
							flower_col = vec3(0.98, 0.88, 0.15); // Marigold yellow
						} else if (f_hash > 0.86) {
							flower_col = vec3(0.95, 0.95, 0.98); // White blossom
						}
						float petal = step(hash(floor(pos * 8.0)), 0.35);
						surface = mix(surface, flower_col, petal * 0.85);
					}
				}
			}
		}
	}

	// Distance Vignette (fades gracefully into horizon at boundary)
	float dist = length(pos);
	float fade = clamp((dist - (vignette_radius * 0.75)) / (vignette_radius * 0.25), 0.0, 1.0);
	vec3 final_color = mix(surface, vec3(0.04, 0.07, 0.05), fade);

	ALBEDO = final_color;
	ROUGHNESS = surf_roughness;
	METALLIC = is_road ? 0.12 : 0.0;
	SPECULAR = is_road ? 0.4 : 0.15;
	EMISSION = emission * (1.0 - fade);
}
