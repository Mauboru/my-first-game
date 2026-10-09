shader_type sky;

uniform sampler2D stars : source_color, filter_linear, repeat_enable;
uniform sampler2D moon : source_color, filter_linear, repeat_disable;
uniform vec3 star_axis = vec3(0.3, 1.0, 0.2);
uniform float star_speed = 0.01;
uniform float star_tiling = 1.5;
uniform float star_brightness = 1.0;
uniform float moon_size = 0.12;
uniform float moon_brightness = 1.5;

vec3 rotate_around(vec3 v, vec3 axis, float angle) {
	return v * cos(angle) + cross(axis, v) * sin(angle) + axis * dot(axis, v) * (1.0 - cos(angle));
}

// Mirrors the photo at every repeat so the tiles have no visible seam
vec3 sample_stars(vec2 p) {
	p *= star_tiling * vec2(2.0 / 3.0, 1.0);
	return texture(stars, abs(fract(p * 0.5) * 2.0 - 1.0)).rgb;
}

void sky() {
	vec3 dir = rotate_around(EYEDIR, normalize(star_axis), TIME * star_speed);
	// The photo is flat, blending three projections avoids stretching it around the poles
	vec3 weight = pow(abs(dir), vec3(4.0));
	weight /= weight.x + weight.y + weight.z;
	vec3 color = sample_stars(dir.zy) * weight.x;
	color += sample_stars(dir.xz) * weight.y;
	color += sample_stars(dir.xy) * weight.z;
	color *= star_brightness;

	// The moon is drawn where the directional light comes from
	if (LIGHT0_ENABLED && dot(EYEDIR, LIGHT0_DIRECTION) > 0.0) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), LIGHT0_DIRECTION));
		vec3 up = cross(LIGHT0_DIRECTION, right);
		vec2 moon_uv = vec2(dot(EYEDIR, right), -dot(EYEDIR, up)) / moon_size * 0.5 + 0.5;
		if (moon_uv == clamp(moon_uv, 0.0, 1.0)) {
			vec4 moon_color = texture(moon, moon_uv);
			color = mix(color, moon_color.rgb * moon_brightness, moon_color.a);
		}
	}
	COLOR = color;
}
