class_name Doodle
extends RefCounted
# 낙서 렌더러: "도형 데이터"를 받아 선을 노이즈로 흔들어 Image로 굽는다(화면·렌더러 없이도 동작 → 테스트 가능).
# 도형(Dictionary) 종류:
#   line {p:[a,b]}            선        poly {p:[...]}         열린 폴리라인
#   closed {p:[...]}          닫힌 다각형(끝이 살짝 안 닫힘)
#   circle {c,r}              원(시작·끝이 겹치게 두 번 긋기)   ellipse {c,rx,ry}
#   dot {c,r}                 점(눈)
#   scribble {p:[...],n}      다각형 안을 무작위 방향 가는 선으로 빽빽이 채움(적)
#   clear {c,r}               알파를 지우는 원(적의 눈)
#   shade {p:[...]}           음영 빗금 영역(스타일 hatch > 0 일 때만)
# 스타일: wobble(흔들림 px), passes(겹쳐 긋는 횟수), width(기본 굵기), hatch(빗금 간격, 0=없음), color

# 레벨별 스타일. 1~9렙만 구현(10/20/30렙 변화는 v0.2.0). 레벨이 오를수록 선이 안정되고 겹침·음영이 늘어난다.
static func style_for_level(lv: int) -> Dictionary:
	lv = clampi(lv, 1, 9)
	var t := (lv - 1) / 8.0
	return {
		"wobble": lerpf(2.6, 1.0, t),
		"passes": 2 if lv < 7 else 3,
		"width": lerpf(2.6, 3.2, t),
		"hatch": 0.0 if lv < 5 else lerpf(9.0, 6.0, t),
		"color": Color("3a3a3e"),
	}

# 적 전용 스타일: 어둡고 촘촘한 검은 볼펜
static func enemy_style() -> Dictionary:
	return {"wobble": 2.4, "passes": 2, "width": 2.3, "hatch": 0.0, "color": Color("0e0e16")}

# 도형 데이터 → Image. seed가 같으면 결과가 항상 같다. frame은 떨림 변형 번호.
static func bake(shapes: Array, size: Vector2i, seed: int, style: Dictionary, frame := 0) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, frame])
	var buf := PackedFloat32Array()
	buf.resize(size.x * size.y)
	var ctx := {"buf": buf, "w": size.x, "h": size.y, "rng": rng, "st": style}
	for s in shapes:
		_draw_shape(ctx, s)
	var data := PackedByteArray()
	data.resize(size.x * size.y * 4)
	var col: Color = style.color
	var r := int(col.r * 255.0)
	var g := int(col.g * 255.0)
	var b := int(col.b * 255.0)
	for i in buf.size():
		data[i * 4] = r
		data[i * 4 + 1] = g
		data[i * 4 + 2] = b
		data[i * 4 + 3] = int(clampf(buf[i], 0.0, 1.0) * col.a * 255.0)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)

static func _draw_shape(ctx: Dictionary, s: Dictionary) -> void:
	var st: Dictionary = ctx.st
	var rng: RandomNumberGenerator = ctx.rng
	var wob: float = st.wobble
	var passes: int = st.passes
	match s.k:
		"line":
			for i in passes:
				_stroke(ctx, [_j(rng, s.p[0], wob), _j(rng, s.p[1], wob)], s.get("w", 1.0))
		"poly":
			for i in passes:
				var pts := []
				for p in s.p:
					pts.append(_j(rng, p, wob * 0.6))
				_stroke(ctx, pts, s.get("w", 1.0))
		"closed":
			for i in passes:
				var pts := []
				for p in s.p:
					pts.append(_j(rng, p, wob * 0.6))
				# 끝점이 시작점에 못 미치게 → 모서리가 살짝 안 닫힘
				var first: Vector2 = pts[0]
				var last: Vector2 = pts[pts.size() - 1]
				pts.append(first.lerp(last, rng.randf_range(0.0, 0.15)) + _rv(rng, wob * 1.2))
				_stroke(ctx, pts, s.get("w", 1.0))
		"circle", "ellipse":
			var rx: float = s.r if s.k == "circle" else s.rx
			var ry: float = s.r if s.k == "circle" else s.ry
			for i in passes:
				# 매번 다른 각도에서 시작 + 끝이 시작을 지나쳐 겹침
				var a0 := rng.randf() * TAU
				var sweep := TAU + rng.randf_range(0.3, 0.7)
				var steps := maxi(12, int((rx + ry) * 0.9))
				var c: Vector2 = _j(rng, s.c, wob * 0.5)
				var ph := rng.randf() * TAU
				var pts := []
				for k in steps + 1:
					var a := a0 + sweep * k / steps
					var rr := 1.0 + 0.06 * sin(a * 2.0 + ph) + 0.03 * sin(a * 3.0 + ph * 2.0)
					# 겹치는 구간은 반지름을 조금씩 벌려 두 번 그은 티가 나게
					rr += 0.05 * maxf(0.0, (a - a0 - TAU) / 0.7) * (-1.0 if i % 2 == 0 else 1.0)
					pts.append(c + Vector2(cos(a) * rx * rr, sin(a) * ry * rr))
				_stroke(ctx, pts, s.get("w", 1.0))
		"dot":
			var c: Vector2 = _j(rng, s.c, wob * 0.4)
			_stamp_disc(ctx, c, s.r * rng.randf_range(0.9, 1.2), 1.0, [])
		"clear":
			_clear_disc(ctx, _j(rng, s.c, wob * 0.3), s.r)
		"scribble":
			_scribble(ctx, s)
		"shade":
			if st.hatch > 0.0:
				_hatch(ctx, s)

static func _rv(rng: RandomNumberGenerator, amp: float) -> Vector2:
	return Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp))

static func _j(rng: RandomNumberGenerator, p: Vector2, amp: float) -> Vector2:
	return p + _rv(rng, amp)

# 한 번 긋기: 점들을 잇는 선을 2px 간격으로 샘플, 옆으로 흔들고, 굵기를 노이즈로 바꿔 도장 찍듯 그린다.
static func _stroke(ctx: Dictionary, pts: Array, wscale: float, clip := []) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var st: Dictionary = ctx.st
	var base_w: float = st.width * wscale
	var amp: float = st.wobble * 0.45
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var freq := rng.randf_range(0.05, 0.11)
	var dist := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		var n := maxi(1, int(seg / 1.5))
		var normal := (b - a).orthogonal().normalized()
		for k in n + 1:
			var t := float(k) / n
			var p := a.lerp(b, t)
			var d := dist + seg * t
			p += normal * (sin(d * freq + ph1) + 0.5 * sin(d * freq * 2.3 + ph2)) * amp
			# 굵기: 선 중간은 굵고, 노이즈로 들쭉날쭉
			var w := base_w * (0.75 + 0.35 * sin(d * 0.13 + ph2) + 0.15 * sin(d * 0.41 + ph1))
			_stamp_disc(ctx, p, maxf(0.55, w * 0.5), 1.0, clip)
		dist += seg

# 부드러운 가장자리를 가진 원판을 알파 버퍼에 찍는다(max 합성).
static func _stamp_disc(ctx: Dictionary, c: Vector2, r: float, strength: float, clip: Array) -> void:
	if not clip.is_empty() and not Geometry2D.is_point_in_polygon(c, PackedVector2Array(clip)):
		return
	var buf: PackedFloat32Array = ctx.buf
	var w: int = ctx.w
	var h: int = ctx.h
	var x0 := maxi(0, int(floorf(c.x - r - 1.0)))
	var x1 := mini(w - 1, int(ceilf(c.x + r + 1.0)))
	var y0 := maxi(0, int(floorf(c.y - r - 1.0)))
	var y1 := mini(h - 1, int(ceilf(c.y + r + 1.0)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cov := clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0) * strength
			var idx := y * w + x
			if cov > buf[idx]:
				buf[idx] = cov
	ctx.buf = buf

static func _clear_disc(ctx: Dictionary, c: Vector2, r: float) -> void:
	var buf: PackedFloat32Array = ctx.buf
	var w: int = ctx.w
	for y in range(maxi(0, int(c.y - r - 1)), mini(ctx.h, int(c.y + r + 2))):
		for x in range(maxi(0, int(c.x - r - 1)), mini(w, int(c.x + r + 2))):
			var cov := clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
			buf[y * w + x] *= 1.0 - cov
	ctx.buf = buf

# 적 몸통: 외곽을 거칠게 두 번 긋고, 안쪽을 무작위 방향의 가는 선으로 빽빽이 채운다.
static func _scribble(ctx: Dictionary, s: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var poly := []
	for p in s.p:
		poly.append(_j(rng, p, ctx.st.wobble * 1.0))
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	var clip := poly.duplicate()
	for i in int(s.get("n", 200)):
		var c := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		if not Geometry2D.is_point_in_polygon(c, PackedVector2Array(poly)):
			continue
		var ang := rng.randf() * PI
		var half := Vector2(cos(ang), sin(ang)) * rng.randf_range(8.0, 22.0)
		_stroke(ctx, [c - half, c + half], 0.55, clip)
	# 거친 외곽(두 번, 바깥으로 삐죽)
	for i in 2:
		var edge := []
		for p in poly:
			edge.append(_j(rng, p, ctx.st.wobble * 1.4))
		edge.append(edge[0] + _rv(rng, 3.0))
		_stroke(ctx, edge, 1.0)

# 음영 빗금: 영역 안을 사선 평행선으로 채운다.
static func _hatch(ctx: Dictionary, s: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var gap: float = ctx.st.hatch
	var poly := PackedVector2Array(s.p)
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	var d := -rect.size.y
	while d < rect.size.x:
		var a := Vector2(rect.position.x + d, rect.end.y)
		var b := Vector2(rect.position.x + d + rect.size.y, rect.position.y)
		_stroke(ctx, [a + _rv(rng, 1.0), b + _rv(rng, 1.0)], 0.5, Array(poly))
		d += gap

static func to_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)
