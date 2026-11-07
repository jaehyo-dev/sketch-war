class_name DoodleArt
extends RefCounted
# 유닛·장식의 "도형 데이터"와, 굽기(떨림 3장) 캐시. 좌표는 160x160 칸, 땅은 y=150, 오른쪽을 본다.
# 적(team 1)은 그릴 때 좌우로 뒤집는다.

const SIZE := Vector2i(160, 160)
const FRAMES := 3               # 떨림 변형 장수
const ALLY_KINDS := ["stickman", "eraser", "archer", "rabbit"]
const ENEMY_KINDS := ["inkblot", "hairball", "horned"]

static var _cache := {}         # "kind:level" → Array[ImageTexture]

# --- 도형 만들기 도우미 ---
static func L(a: Vector2, b: Vector2) -> Dictionary: return {"k": "line", "p": [a, b]}
static func P(pts: Array) -> Dictionary: return {"k": "poly", "p": pts}
static func Z(pts: Array) -> Dictionary: return {"k": "closed", "p": pts}
static func C(c: Vector2, r: float) -> Dictionary: return {"k": "circle", "c": c, "r": r}
static func E(c: Vector2, rx: float, ry: float) -> Dictionary: return {"k": "ellipse", "c": c, "rx": rx, "ry": ry}
static func D(c: Vector2, r := 1.8) -> Dictionary: return {"k": "dot", "c": c, "r": r}
static func S(pts: Array, n := 220) -> Dictionary: return {"k": "scribble", "p": pts, "n": n}
static func X(c: Vector2, r: float) -> Dictionary: return {"k": "clear", "c": c, "r": r}
static func H(pts: Array) -> Dictionary: return {"k": "shade", "p": pts}
static func V(x: float, y: float) -> Vector2: return Vector2(x, y)

# 종류별 도형 데이터. 얼굴은 점 눈 + 선 입(무표정).
static func shapes(kind: String) -> Array:
	match kind:
		"stickman":
			return posed_shapes("stickman", "walk_a")
		"eraser":  # 네모 몸통 + 표정 + 다리
			return [
				Z([V(48, 52), V(112, 50), V(113, 114), V(49, 116)]),
				L(V(48, 98), V(113, 97)),
				D(V(71, 68)), D(V(93, 67)), L(V(72, 84), V(92, 83)),
				L(V(113, 78), V(128, 84)), L(V(48, 80), V(36, 90)),
				L(V(64, 116), V(60, 148)), L(V(98, 116), V(102, 148)),
				L(V(52, 148), V(68, 148)), L(V(94, 148), V(110, 148)),
				H([V(49, 98), V(113, 97), V(113, 114), V(49, 116)]),
			]
		"archer":  # 연필 몸통 + 뾰족 머리 + 활
			return [
				Z([V(66, 54), V(94, 54), V(94, 118), V(66, 118)]),
				Z([V(66, 54), V(94, 54), V(80, 24)]),
				L(V(73, 40), V(80, 30)),
				D(V(74, 72)), D(V(86, 72)), L(V(75, 86), V(85, 86)),
				L(V(66, 108), V(94, 108)),
				L(V(74, 118), V(70, 148)), L(V(86, 118), V(92, 148)),
				L(V(94, 88), V(110, 88)),
				P([V(110, 56), V(124, 72), V(126, 90), V(124, 108), V(110, 124)]),
				L(V(110, 56), V(110, 124)),
				H([V(66, 54), V(76, 54), V(76, 118), V(66, 118)]),
			]
		"rabbit":  # 긴 귀 토끼
			return [
				E(V(78, 112), 32, 24),
				C(V(108, 82), 17),
				E(V(104, 46), 6, 19), E(V(118, 48), 6, 18),
				D(V(114, 80)), L(V(118, 90), V(124, 90)),
				C(V(44, 112), 8),
				L(V(66, 134), V(62, 148)), L(V(94, 134), V(98, 148)),
				L(V(58, 148), V(70, 148)), L(V(90, 148), V(104, 148)),
				H([V(50, 112), V(60, 98), V(78, 92), V(70, 130), V(52, 128)]),
			]
		"inkblot":  # 잉크 얼룩 (아래로 흘러내림)
			return [
				S([V(34, 100), V(44, 70), V(70, 54), V(100, 56), V(124, 74), V(130, 104), V(120, 130), V(100, 136),
					V(98, 150), V(88, 150), V(86, 138), V(66, 140), V(60, 152), V(50, 152), V(48, 136), V(36, 124)], 900),
				X(V(76, 88), 6), X(V(102, 90), 6), D(V(78, 89), 2.2), D(V(104, 91), 2.2),
			]
		"hairball":  # 털뭉치 거미
			var legs := []
			for i in 4:
				var y := 90.0 + i * 12.0
				legs.append(P([V(70, y), V(46 - i * 4, y - 22 + i * 6), V(24 - i * 2, y + 26)]))
				legs.append(P([V(92, y), V(116 + i * 4, y - 22 + i * 6), V(138 + i * 2, y + 26)]))
			return legs + [
				S([V(52, 96), V(60, 76), V(80, 68), V(102, 76), V(110, 96), V(104, 116), V(80, 124), V(58, 116)], 520),
				X(V(70, 92), 5), X(V(92, 92), 5), D(V(71, 93), 2.0), D(V(93, 93), 2.0),
			]
		"horned":  # 뿔 달린 그림자
			return [
				S([V(52, 148), V(48, 108), V(56, 78), V(70, 60), V(90, 60), V(104, 78), V(112, 108), V(108, 148)], 900),
				S([V(60, 62), V(48, 24), V(72, 54)], 90), S([V(98, 54), V(122, 24), V(112, 66)], 90),
				S([V(106, 96), V(132, 110), V(120, 120)], 90),
				X(V(74, 82), 5), X(V(96, 82), 5), D(V(75, 83), 2.0), D(V(97, 83), 2.0),
			]
	return []

# 굽기: 종류+레벨의 떨림 변형 FRAMES장을 만들어 캐시(로드 때 한 번). 매 프레임 재계산하지 않는다.
static func frames(kind: String, level := 1, pose := "walk_a") -> Array:
	if not has_rig(kind):
		pose = "walk_a"   # 관절 데이터가 없는 유닛은 자세 하나뿐
	var key := "%s:%d:%s" % [kind, level, pose]
	if _cache.has(key):
		return _cache[key]
	var style := Doodle.enemy_style() if kind in ENEMY_KINDS else Doodle.style_for_level(level)
	var out := []
	for f in FRAMES:
		out.append(Doodle.to_texture(Doodle.bake(posed_shapes(kind, pose, level), SIZE, hash(kind), style, f)))
	_cache[key] = out
	return out

# --- 관절 + 자세 ---
# RIG: joints(기본 관절 좌표), follow(앞 관절을 따라 같이 움직이는 관절), parts(관절을 이어 그리는 도형), poses(바뀌는 관절만 덮어씀).
# 자세마다 발은 땅(y=148)에, 몸 중심은 x≈80 근처에 둬서 자세를 바꿔도 몸이 튀지 않게 한다.
# parts의 lv = 이 레벨부터 보이는 부분(10/20/30렙 변화용, 지금은 안 씀). seed는 자세와 무관(hash(kind))이라 자세가 바뀌어도 떨림 모양이 이어진다.
const POSE_NAMES := ["walk_a", "walk_b", "windup", "strike", "hurt"]
static var _rigs := {}

static func has_rig(kind: String) -> bool:
	return kind == "stickman"

static func rig(kind: String) -> Dictionary:
	if _rigs.has(kind):
		return _rigs[kind]
	var r := {}
	if kind == "stickman":
		r = {
			"joints": {
				"head": V(80, 50), "neck": V(80, 64), "hip": V(80, 102), "hand_b": V(62, 90), "hand_f": V(104, 84),
				"stick_tip": V(121, 48), "foot_l": V(67, 148), "foot_r": V(95, 148),
				"h1a": V(72, 38), "h1b": V(67, 23), "h2a": V(80, 36), "h2b": V(81, 19), "h3a": V(88, 38), "h3b": V(95, 24),
				"h4a": V(67, 45), "h4b": V(55, 37), "eye1": V(84, 49), "eye2": V(93, 49), "mouth_a": V(84, 57), "mouth_b": V(93, 57),
				"sh": V(80, 74), "sh_r": V(88, 70), "hip_r": V(88, 100),
			},
			"follow": {
				"h1a": "head", "h1b": "head", "h2a": "head", "h2b": "head", "h3a": "head", "h3b": "head", "h4a": "head", "h4b": "head",
				"eye1": "head", "eye2": "head", "mouth_a": "head", "mouth_b": "head",
				"sh": "neck", "sh_r": "neck", "hip_r": "hip", "stick_tip": "hand_f",
			},
			"stick": ["hand_f", "stick_tip"],   # 나뭇가지: 중간에서 잔가지가 뻗음(자동 계산)
			"parts": [
				{"k": "circle", "j": ["head"], "r": 14},
				{"k": "line", "j": ["h1a", "h1b"]}, {"k": "line", "j": ["h2a", "h2b"]}, {"k": "line", "j": ["h3a", "h3b"]}, {"k": "line", "j": ["h4a", "h4b"]},
				{"k": "dot", "j": ["eye1"]}, {"k": "dot", "j": ["eye2"]}, {"k": "line", "j": ["mouth_a", "mouth_b"]},
				{"k": "line", "j": ["neck", "hip"]},
				{"k": "line", "j": ["sh", "hand_b"]}, {"k": "line", "j": ["sh", "hand_f"]},
				{"k": "line", "j": ["hand_f", "stick_tip"]}, {"k": "line", "j": ["stick_mid", "twig_b"]},
				{"k": "line", "j": ["hip", "foot_l"]}, {"k": "line", "j": ["hip", "foot_r"]},
				{"k": "shade", "j": ["neck", "sh_r", "hip_r", "hip"]},
			],
			"poses": {
				"walk_a": {"foot_l": V(62, 148), "foot_r": V(98, 148), "hip": V(80, 103), "hand_b": V(70, 94), "hand_f": V(106, 82)},
				"walk_b": {"foot_l": V(76, 148), "foot_r": V(86, 148), "hip": V(80, 99), "neck": V(80, 61), "head": V(80, 47), "hand_b": V(60, 84), "hand_f": V(102, 88)},
				"windup": {"head": V(76, 50), "neck": V(78, 64), "hip": V(80, 102), "hand_f": V(56, 62), "stick_tip": V(38, 32), "hand_b": V(92, 86), "foot_l": V(60, 148), "foot_r": V(100, 148)},
				"strike": {"head": V(98, 56), "neck": V(90, 68), "hip": V(78, 102), "hand_f": V(120, 84), "stick_tip": V(142, 100), "hand_b": V(72, 92), "foot_l": V(58, 148), "foot_r": V(106, 148)},
				"hurt": {"head": V(68, 54), "neck": V(74, 66), "hip": V(80, 102), "hand_f": V(92, 70), "stick_tip": V(104, 40), "hand_b": V(56, 76), "foot_l": V(68, 148), "foot_r": V(98, 148)},
			},
		}
	_rigs[kind] = r
	return r

# 관절 + 자세 + 레벨 → 도형 dict 배열(Doodle.bake가 그대로 먹는 형식)
static func posed_shapes(kind: String, pose: String, level := 1) -> Array:
	if not has_rig(kind):
		return shapes(kind)
	var rg := rig(kind)
	var ov: Dictionary = rg.poses.get(pose, {})
	var j := {}
	for n in rg.joints:
		j[n] = ov.get(n, rg.joints[n])
	for n in rg.follow:           # 덮어쓰지 않은 따라가는 관절은 기준 관절이 움직인 만큼 같이 이동
		if not ov.has(n):
			var a: String = rg.follow[n]
			j[n] = rg.joints[n] + (j[a] - rg.joints[a])
	if rg.has("stick"):
		j["stick_mid"] = j[rg.stick[0]].lerp(j[rg.stick[1]], 0.58)
		j["twig_b"] = j.stick_mid + V(12, -3)
	var out := []
	for p in rg.parts:
		if p.get("lv", 1) > level:
			continue
		var pts := []
		for n in p.j:
			pts.append(j[n])
		match p.k:
			"line": out.append({"k": "line", "p": pts})
			"circle": out.append({"k": "circle", "c": pts[0], "r": p.r})
			"dot": out.append({"k": "dot", "c": pts[0], "r": p.get("r", 1.8)})
			"shade": out.append({"k": "shade", "p": pts})
	# 효과 낙서: 타격 땐 가지 끝의 속도선, 피격 땐 머리 주변의 충격선
	if pose == "strike":
		var t: Vector2 = j.stick_tip
		out += [L(t + V(-2, -16), t + V(12, -26)), L(t + V(6, -2), t + V(20, -4)), L(t + V(-2, 14), t + V(10, 22))]
	elif pose == "hurt":
		var h: Vector2 = j.head
		out += [L(h + V(-18, -18), h + V(-28, -26)), L(h + V(-22, 0), h + V(-34, -2)), L(h + V(-18, 16), h + V(-28, 24))]
	return out

# 8fps로 도는 프레임 번호(phase로 유닛마다 어긋나게)
static func frame_at(time: float, phase := 0) -> int:
	return (int(time * 8.0) + phase) % FRAMES

# --- 장식용 낙서 텍스처(메뉴 밑줄, 스프링, 종이 테두리 등). 한 번 굽고 캐시 ---
static func _deco(key: String, shp: Array, size: Vector2i, style: Dictionary) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = Doodle.to_texture(Doodle.bake(shp, size, hash(key), style, 0))
	return _cache[key]

static func _pencil(wobble := 2.0, width := 2.6) -> Dictionary:
	return {"wobble": wobble, "passes": 2, "width": width, "hatch": 0.0, "color": Color("3a3a3e")}

# 흔들리는 가로 선(땅, 밑줄)
static func wavy_line(width: int, wobble := 2.0, line_w := 2.6) -> ImageTexture:
	return _deco("line%d:%s" % [width, wobble], [L(V(6, 9), V(width - 6, 9))], Vector2i(width, 18), _pencil(wobble, line_w))

# 흔들리는 네모 테두리(HUD, 카드, 막대 틀)
static func rect_outline(size: Vector2i) -> ImageTexture:
	var w := float(size.x)
	var h := float(size.y)
	return _deco("rect%s" % size, [Z([V(5, 5), V(w - 5, 4), V(w - 4, h - 5), V(6, h - 4)])], size, _pencil(1.6, 2.4))

# 왼쪽 가장자리 스프링 제본(단순한 선 고리)
static func spring(height: int) -> ImageTexture:
	var shp := []
	for i in int(height / 56.0):
		var y := 40.0 + i * 56.0
		shp.append(E(V(34, y), 24, 9))
		shp.append(L(V(34, y), V(66, y - 2)))
	return _deco("spring%d" % height, shp, Vector2i(72, height), _pencil(1.5, 3.0))

# 메뉴 옆 작은 낙서: star / arrow / spiral / bolt
static func mini(kind: String) -> ImageTexture:
	var shp := []
	match kind:
		"star":
			shp = [P([V(30, 6), V(40, 36), V(10, 18), V(50, 18), V(20, 36), V(30, 6)])]
		"arrow":
			shp = [L(V(6, 30), V(52, 30)), P([V(40, 18), V(54, 30), V(40, 42)])]
		"spiral":
			shp = [P([V(30, 30), V(36, 28), V(34, 20), V(24, 22), V(22, 36), V(36, 42), V(48, 30), V(42, 14), V(22, 10), V(8, 28)])]
		"bolt":
			shp = [P([V(36, 4), V(18, 30), V(32, 30), V(22, 56), V(46, 24), V(32, 24), V(40, 4)])]
	return _deco("mini" + kind, shp, Vector2i(60, 60), _pencil(1.4, 2.6))

# 전투 배경 앞쪽: 땅 선, 풀 뭉치, 땅 음영(코드). 뒤쪽 풍경은 AI 스케치 이미지. 레벨과 무관한 기본 품질.
# 연하게 그려 유닛이 앞에 도드라지게 한다. 풀 위치는 시드 고정.
static func backdrop(ground_y: float) -> ImageTexture:
	var key := "backdrop%d" % int(ground_y)
	if _cache.has(key):
		return _cache[key]
	var g := ground_y
	var shp := []
	# 하늘·산·폐허는 AI 풍경 스케치(assets/art/bg_battle.png)가 맡고, 여기선 땅·풀만 코드로 그린다
	# 땅 선 위 풀 뭉치(위치 고정)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var x := 40.0
	while x < 1250.0:
		var h := rng.randf_range(10.0, 20.0)
		shp.append(L(V(x, g), V(x - 5, g - h))); shp.append(L(V(x + 3, g), V(x + 3, g - h - 5))); shp.append(L(V(x + 6, g), V(x + 11, g - h + 2)))
		x += rng.randf_range(50.0, 110.0)
	# 땅 선(흔들리는 한 줄)과 그 아래 음영 빗금(카드 위에서 끝남)
	shp.append(L(V(40, g), V(1250, g)))
	shp.append(H([V(0, g + 8), V(1280, g + 8), V(1280, g + 62), V(0, g + 62)]))
	var st := {"wobble": 2.2, "passes": 2, "width": 2.4, "hatch": 15.0, "color": Color(0.23, 0.23, 0.25, 0.55)}
	_cache[key] = Doodle.to_texture(Doodle.bake(shp, Vector2i(1280, 720), 99, st, 0))
	return _cache[key]

# 타격 이펙트: 삐죽한 별 모양 폭발 낙서(200x200, 중심 100,100). 변형 3종, 시드 고정. 그릴 때 크기·투명도만 바꾼다.
static func burst(variant: int) -> ImageTexture:
	var key := "burst%d" % (variant % 3)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + variant % 3
	var c := V(100, 100)
	var star := []
	var n := 12
	for i in n * 2:
		var a := TAU * i / (n * 2) + rng.randf_range(-0.08, 0.08)
		var r := (rng.randf_range(72.0, 92.0) if i % 2 == 0 else rng.randf_range(30.0, 42.0))
		star.append(c + Vector2(cos(a), sin(a)) * r)
	var shp := [Z(star)]
	for i in 6:   # 안쪽 방사선
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		shp.append(L(c + Vector2(cos(a), sin(a)) * 12.0, c + Vector2(cos(a), sin(a)) * rng.randf_range(34.0, 52.0)))
	shp.append(C(c, 10))
	var st := {"wobble": 3.0, "passes": 2, "width": 3.8, "hatch": 0.0, "color": Color("1c1c22")}
	_cache[key] = Doodle.to_texture(Doodle.bake(shp, Vector2i(200, 200), 700 + variant % 3, st, 0))
	return _cache[key]
