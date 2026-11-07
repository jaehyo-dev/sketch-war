extends Control
# 전투 화면: BattleLogic을 돌리고 그리기만 한다. 유닛은 미리 구운 낙서 프레임(DoodleArt)을 돌려 쓴다.
# 타격 이펙트는 로직이 내주는 events를 읽어 그린다(폭발 낙서 + 파편 + 의성어 + 데미지 숫자 + 화면 흔들림).

const LEFT_X := 160.0     # 전장 x=0이 화면 어디인지
const RIGHT_X := 1120.0
const GROUND_Y := 470.0
const SCALE := (RIGHT_X - LEFT_X) / BattleLogic.FIELD_LEN
const INK := Color("3a3a3e")
const TITLE_FONT := preload("res://assets/fonts/BlackHanSans-Regular.ttf")
const MENU_FONT := preload("res://assets/fonts/NanumGothic-Bold.ttf")
const WORDS := ["퍽!", "쾅!", "탁!", "팍!"]
const FX_LIFE := 0.42

var logic := BattleLogic.new()
var time := 0.0
var cards: Array = []
var enemy_test_idx := 0
var art_level := 1        # 아군 그림 레벨(시험용 조작, 1~9). 레벨업 시스템은 v0.5.0
var level_btn: Button
var fx: Array = []        # 진행 중인 타격 이펙트
var fx_count := 0
var shake := 0.0          # 화면 흔들림 세기(점점 줄어듦)
var base_shake := [0.0, 0.0]
var tower_tex := load("res://assets/art/base_tower.png") as Texture2D
var castle_tex := load("res://assets/art/base_castle.png") as Texture2D
var bg_tex := load("res://assets/art/bg_battle.png") as Texture2D

func _ready() -> void:
	# 배경: 종이 질감 셰이더(큰 도화지). 부모(_draw)보다 뒤에 그린다.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	mat.set_shader_parameter("blemish", false)   # 큰 도화지: 줄·얼룩 없음
	bg.material = mat
	add_child(bg)
	# 로드 때 모든 유닛 프레임과 이펙트를 미리 굽는다(이후 재계산 없음)
	for k in DoodleArt.ALLY_KINDS + DoodleArt.ENEMY_KINDS:
		DoodleArt.frames(k)
	_bake_level(art_level)
	for i in 3:
		DoodleArt.burst(i)
	# 하단 카드 4장(살짝씩 다르게 기울임)
	var tilt := [-1.5, 1.0, -0.8, 1.6]
	for i in DoodleArt.ALLY_KINDS.size():
		var k: String = DoodleArt.ALLY_KINDS[i]
		var c := UnitCard.new()
		c.kind = k
		c.cost = BattleLogic.UNITS[k].cost
		c.position = Vector2(370 + i * 140, 584)
		c.rotation_degrees = tilt[i]
		c.tapped.connect(func(kind): logic.summon_card(kind))
		add_child(c)
		cards.append(c)
	level_btn = _add_tag("그림 레벨 1", Vector2(30, 650), _next_level)
	_add_tag("처음으로", Vector2(590, 24), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_add_tag("시험용 적 소환", Vector2(1020, 650), _spawn_test_enemy)

# 종이 쪽지 모양 작은 버튼(그림자 + 얇은 테두리)
func _add_tag(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", MENU_FONT)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color("b03030"))
	for st_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fbf6e6") if st_name != "hover" else Color("fffbea")
		sb.set_border_width_all(2)
		sb.border_color = INK
		sb.set_corner_radius_all(3)
		sb.shadow_color = Color(0, 0, 0, 0.2)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(2, 3)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		b.add_theme_stylebox_override(st_name, sb)
	b.position = pos
	b.pressed.connect(cb)
	add_child(b)
	return b

# 시험용: 아군 그림 레벨을 1→9로 올리며 돌아감. 바뀐 레벨의 자세를 미리 굽는다.
func _next_level() -> void:
	art_level = art_level % 9 + 1
	_bake_level(art_level)
	for c in cards:
		c.level = art_level
	level_btn.text = "그림 레벨 %d" % art_level

func _bake_level(lv: int) -> void:
	for pose in DoodleArt.POSE_NAMES:
		DoodleArt.frames("stickman", lv, pose)

# 적 시스템은 v0.3.0 — 지금은 종류를 돌려가며 시험 소환
func _spawn_test_enemy() -> void:
	logic.spawn(1, DoodleArt.ENEMY_KINDS[enemy_test_idx % DoodleArt.ENEMY_KINDS.size()])
	enemy_test_idx += 1

func _process(delta: float) -> void:
	time += delta
	logic.tick(delta)
	for ev in logic.events:
		_add_fx(ev)
	logic.events.clear()
	for f in fx:
		f.t += delta
	fx = fx.filter(func(f): return f.t < FX_LIFE)
	shake = maxf(0.0, shake - delta * 28.0)
	base_shake[0] = maxf(0.0, base_shake[0] - delta * 20.0)
	base_shake[1] = maxf(0.0, base_shake[1] - delta * 20.0)
	for c in cards:
		c.cd_ratio = logic.card_ratio(c.kind)
		c.cd_left = logic.card_cd.get(c.kind, 0.0)
		c.time = time
		c.queue_redraw()
	queue_redraw()

# 타격 이벤트 → 이펙트 한 개(기지는 높은 곳, 유닛은 가슴 높이에서 터짐)
func _add_fx(ev: Dictionary) -> void:
	var y := GROUND_Y - (110.0 if ev.base else 78.0)
	fx.append({
		"pos": Vector2(LEFT_X + ev.x * SCALE, y), "t": 0.0, "variant": fx_count, "dmg": ev.dmg,
		"word": WORDS[fx_count % WORDS.size()], "rot": (fx_count % 3 - 1) * 0.25, "sc": 0.5 + ev.dmg / 40.0, "dx": (fx_count % 2 * 2 - 1) * 34.0,
	})
	fx_count += 1
	shake = minf(9.0, maxf(shake, 2.5 + ev.dmg * 0.45))
	if ev.base:
		base_shake[ev.team] = 6.0

func _draw() -> void:
	# 화면 흔들림: 전장만 흔들고 HUD·카드는 그대로
	var sh := Vector2(sin(time * 97.0), cos(time * 83.0)) * shake
	draw_set_transform(sh)
	# 배경: AI 연필 풍경(안 움직임) + 코드로 그린 땅 선·풀·땅 음영
	if bg_tex:
		draw_texture(bg_tex, Vector2.ZERO)
	draw_texture(DoodleArt.backdrop(GROUND_Y), Vector2.ZERO)
	# 기지(AI 이미지, 안 움직임). 맞으면 좌우로 부르르
	_draw_base(tower_tex, LEFT_X - 40.0 + sin(time * 80.0) * base_shake[0], 0.8)
	_draw_base(castle_tex, RIGHT_X + 40.0 + sin(time * 80.0) * base_shake[1], 0.65)
	for u in logic.units:
		_draw_unit(u)
	for f in fx:
		_draw_fx(f)
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	if logic.winner != -1:
		var msg := "승리!" if logic.winner == 0 else "패배..."
		draw_string_outline(TITLE_FONT, Vector2(0, 280), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 130, 16, Color("fffaf0"))
		draw_string(TITLE_FONT, Vector2(0, 280), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 130, Color("b03030"))

func _draw_base(tex: Texture2D, cx: float, s: float) -> void:
	var sz := tex.get_size() * s
	draw_texture_rect(tex, Rect2(cx - sz.x / 2.0, GROUND_Y + 2.0 - sz.y, sz.x, sz.y), false)

# 로직 상태 → 자세. 타격·준비가 우선, 그다음 피격, 아니면 걸음(걸음 폭마다 A/B 교대 → 발이 미끄러지지 않음)
func _pose_of(u: Dictionary) -> String:
	if u.state == "strike":
		return "strike"
	if u.state == "windup":
		return "windup"
	if u.hurt_t > 0.0:
		return "hurt"
	return "walk_a" if int(u.x / 24.0) % 2 == 0 else "walk_b"

func _draw_unit(u: Dictionary) -> void:
	var fr: Array = DoodleArt.frames(u.kind, art_level if u.team == 0 else 1, _pose_of(u))
	var tex: Texture2D = fr[DoodleArt.frame_at(time, u.id)]
	# 맞으면 공격자 반대쪽으로 확 밀렸다 돌아옴(그림은 그대로, 위치만)
	var recoil: float = -BattleLogic.dir_of(u.team) * 14.0 * (u.hurt_t / BattleLogic.HURT)
	var px: float = LEFT_X + u.x * SCALE + recoil
	var rect := Rect2(px - 80.0, GROUND_Y - 150.0, 160, 160)
	if u.team == 1:   # 적은 왼쪽을 보도록 뒤집기
		rect = Rect2(px + 80.0, rect.position.y, -160, 160)
	draw_texture_rect(tex, rect, false)
	# 체력: 머리 위 가는 선 한 줄(비율만큼 굵은 선)
	var ratio := clampf(float(u.hp) / BattleLogic.UNITS[u.kind].hp, 0.0, 1.0)
	if ratio < 1.0:
		draw_line(Vector2(px - 24, GROUND_Y - 158), Vector2(px + 24, GROUND_Y - 158), Color(0.2, 0.2, 0.2, 0.25), 3)
		draw_line(Vector2(px - 24, GROUND_Y - 158), Vector2(px - 24 + 48 * ratio, GROUND_Y - 158), INK, 3)

# 타격 이펙트: 폭발 낙서(커지며 사라짐) + 사방으로 튀는 파편선 + 의성어 + 올라가는 데미지 숫자
func _draw_fx(f: Dictionary) -> void:
	var p := clampf(f.t / FX_LIFE, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - p, 3.0)
	var a := 1.0 - p * p
	var s: float = f.sc * (0.4 + 0.6 * ease)
	draw_set_transform(f.pos, f.rot, Vector2(s, s))
	draw_texture_rect(DoodleArt.burst(f.variant), Rect2(-100, -100, 200, 200), false, Color(1, 1, 1, a * 0.9))
	draw_set_transform(Vector2.ZERO)
	for i in 7:   # 파편선
		var ang: float = f.variant * 0.9 + i * TAU / 7.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(f.pos + d * (36.0 + 80.0 * ease) * f.sc, f.pos + d * (52.0 + 96.0 * ease) * f.sc, Color(0.12, 0.12, 0.15, a), 3.0)
	var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - p * 5.0)   # 처음에 확 커졌다 줄어듦
	draw_set_transform(f.pos + Vector2(f.dx, -70 - 16 * ease), f.rot * 0.6, Vector2(pop, pop))
	draw_string_outline(TITLE_FONT, Vector2(-100, 0), f.word, HORIZONTAL_ALIGNMENT_CENTER, 200, 56, 12, Color(1, 0.98, 0.92, a))
	draw_string(TITLE_FONT, Vector2(-100, 0), f.word, HORIZONTAL_ALIGNMENT_CENTER, 200, 56, Color(0.1, 0.1, 0.13, a))
	draw_set_transform(Vector2.ZERO)
	draw_string_outline(MENU_FONT, f.pos + Vector2(f.dx + 40, -22 - 44 * p), "-%d" % f.dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(1, 0.98, 0.92, a))
	draw_string(MENU_FONT, f.pos + Vector2(f.dx + 40, -22 - 44 * p), "-%d" % f.dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.7, 0.14, 0.14, a))

# 테이프 붙은 종이 조각 HUD: 내 기지(왼쪽 위), 적 기지(오른쪽 위)
func _draw_hud() -> void:
	_hud_piece(Vector2(60, 22), -0.02, "우리 기지", 0, tower_tex, INK)
	_hud_piece(Vector2(920, 22), 0.02, "적 기지", 1, castle_tex, Color("0e0e16"))

func _hud_piece(pos: Vector2, rot: float, label: String, team: int, icon: Texture2D, bar_col: Color) -> void:
	draw_set_transform(pos + Vector2(5, 7), rot)
	draw_rect(Rect2(0, 0, 300, 84), Color(0, 0, 0, 0.18))     # 그림자
	draw_set_transform(pos, rot)
	draw_rect(Rect2(0, 0, 300, 84), Color("fbf6e6"))
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(300, 84)), Rect2(0, 0, 300, 84), false)
	# 테이프(반투명 노란 조각, 양 위 모서리)
	draw_set_transform(pos + Vector2(-10, -10), rot - 0.5)
	draw_rect(Rect2(0, 0, 50, 18), Color(0.95, 0.88, 0.5, 0.65))
	draw_set_transform(pos + Vector2(262, -8), rot + 0.5)
	draw_rect(Rect2(0, 0, 50, 18), Color(0.95, 0.88, 0.5, 0.65))
	draw_set_transform(pos, rot)
	# 기지 그림 아이콘
	var isz := icon.get_size() * (56.0 / icon.get_size().y)
	draw_texture_rect(icon, Rect2(16 + (44 - isz.x) / 2.0, 14, isz.x, 56), false)
	var hp: int = maxi(0, logic.base_hp[team])
	draw_string(MENU_FONT, Vector2(76, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_string(TITLE_FONT, Vector2(76, 32), str(hp), HORIZONTAL_ALIGNMENT_RIGHT, 208, 28, INK)
	# 체력 막대: 채움 + 10% 눈금 + 손으로 그린 틀
	var ratio := clampf(float(hp) / BattleLogic.BASE_HP, 0.0, 1.0)
	draw_rect(Rect2(78, 45, 204 * ratio, 18), Color(bar_col, 0.78))
	for i in range(1, 10):
		draw_line(Vector2(78 + 20.4 * i, 45), Vector2(78 + 20.4 * i, 63), Color("fbf6e6", 0.7), 1.5)
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(212, 28)), Rect2(74, 40, 212, 28), false)
	draw_set_transform(Vector2.ZERO)
