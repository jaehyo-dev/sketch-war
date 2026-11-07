shader_type canvas_item;
// 종이 질감: 셰이더 노이즈(결·얼룩·구김). pattern 0=무지, 1=방안지(전장), 2=줄 노트
uniform int pattern = 0;
uniform vec2 size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec3 col = vec3(0.957, 0.925, 0.847);
	col -= (hash(px) - 0.5) * 0.035;                   // 잔 알갱이
	col -= (fbm(px * 0.012) - 0.5) * 0.06;             // 큰 얼룩결
	// 은은한 얼룩 한 곳(커피 자국 같은 둥근 번짐)
	float st = smoothstep(95.0, 70.0, distance(px, size * vec2(0.80, 0.30)) + fbm(px * 0.05) * 30.0);
	col = mix(col, col * vec3(0.93, 0.86, 0.74), st * 0.55);
	// 구김 한 줄(대각선, 흔들림)
	float d = abs((px.x * 0.55 + px.y * 0.83) - size.x * 0.42 + (fbm(px * 0.02) - 0.5) * 40.0);
	col -= smoothstep(2.2, 0.0, d) * 0.05;
	col += smoothstep(5.0, 1.5, abs(d - 4.0)) * 0.025;
	if (pattern == 1) {            // 방안지: 연한 파란 연필 격자
		vec2 g = abs(fract(px / 40.0 + 0.5) - 0.5) * 40.0;
		float line = smoothstep(1.2, 0.3, min(g.x, g.y));
		col = mix(col, vec3(0.62, 0.72, 0.85), line * 0.28);
	} else if (pattern == 2) {
		float g = abs(fract(px.y / 40.0 + 0.5) - 0.5) * 40.0;
		col = mix(col, vec3(0.62, 0.72, 0.85), smoothstep(1.2, 0.3, g) * 0.3);
		col = mix(col, vec3(0.85, 0.5, 0.5), smoothstep(1.4, 0.4, abs(px.x - 150.0)) * 0.3);
	}
	COLOR = vec4(col, 1.0);
}
