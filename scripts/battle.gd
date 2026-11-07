extends Control
# 전투 화면: BattleLogic을 돌리고 그리기만 한다. 유닛은 미리 구운 낙서 프레임(DoodleArt)을 돌려 쓴다.

const LEFT_X := 160.0     # 전장 x=0이 화면 어디인지
const RIGHT_X := 1120.0
const GROUND_Y := 470.0
const SCALE := (RIGHT_X - LEFT_X) / BattleLogic.FIELD_LEN
const INK := Color("3a3a3e")

var logic := BattleLogic.new()
var time := 0.0
var cards: Array = []
var enemy_test_idx := 0
var art_level := 1        # 아군 그림 레벨(시험용 조작, 1~9). 레벨업 시스템은 v0.5.0
var tower_tex := load("res://assets/art/base_tower.png") as Texture2D
var castle_tex := load("res://assets/art/base_castle.png") as Texture2D

func _ready() -> void:
	# 배경: 종이 질감 셰이더(방안지). 부모(_draw)보다 뒤에 그린다.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	mat.set_shader_parameter("blemish", false)   # 큰 도화지: 줄·얼룩 없음
	bg.material = mat
	add_child(bg)
	# 로드 때 모든 유닛 프레임을 미리 굽는다(이후 재계산 없음)
	for k in DoodleArt.ALLY_KINDS + DoodleArt.ENEMY_KINDS:
		DoodleArt.frames(k)
	_bake_level(art_level)
	# 하단 카드 4장
	for i in DoodleArt.ALLY_KINDS.size():
		var k: String = DoodleArt.ALLY_KINDS[i]
		var c := UnitCard.new()
		c.kind = k
		c.cost = BattleLogic.UNITS[k].cost
		c.position = Vector2(370 + i * 140, 584)
		c.tapped.connect(func(kind): logic.summon_card(kind))
		add_child(c)
		cards.append(c)
	_add_link("그림 레벨 1", Vector2(40, 620), _next_level)
	_add_link("처음으로", Vector2(560, 24), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_add_link("시험용 적 소환", Vector2(1010, 620), _spawn_test_enemy)

# 글씨만 있는 링크 버튼(버튼 모양 없음)
func _add_link(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color("b03030"))
	b.position = pos
	b.pressed.connect(cb)
	add_child(b)

# 시험용: 아군 그림 레벨을 1→9로 올리며 돌아감. 바뀐 레벨의 자세를 미리 굽는다.
func _next_level() -> void:
	art_level = art_level % 9 + 1
	_bake_level(art_level)
	for c in cards:
		c.level = art_level
	for ch in get_children():
		if ch is Button and ch.text.begins_with("그림 레벨"):
			ch.text = "그림 레벨 %d" % art_level

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
	for c in cards:
		c.cd_ratio = logic.card_ratio(c.kind)
		c.time = time
		c.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	# 배경 낙서(해·구름·언덕·나무·풀·땅 음영): 한 번 구운 그림. 땅 선은 흔들리는 한 줄
	draw_texture(DoodleArt.backdrop(GROUND_Y), Vector2.ZERO)
	draw_texture(DoodleArt.wavy_line(1180, 2.6, 3.0), Vector2(80, GROUND_Y - 5))
	# 기지(AI 이미지, 안 움직임)
	_draw_base(tower_tex, LEFT_X - 40.0, 0.8)
	_draw_base(castle_tex, RIGHT_X + 40.0, 0.65)
	# 유닛: 아래쪽에 있는 것부터가 아니라 소환 순서대로, 떨림 프레임을 8fps로
	for u in logic.units:
		_draw_unit(u)
	_draw_hud(font)
	if logic.winner != -1:
		var msg := "승리!" if logic.winner == 0 else "패배..."
		draw_string(font, Vector2(0, 280), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 130, Color("b03030"))

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
	var px: float = LEFT_X + u.x * SCALE
	var rect := Rect2(px - 80.0, GROUND_Y - 150.0, 160, 160)
	if u.team == 1:   # 적은 왼쪽을 보도록 뒤집기
		rect = Rect2(px + 80.0, rect.position.y, -160, 160)
	draw_texture_rect(tex, rect, false)
	# 체력: 머리 위 가는 선 한 줄(비율만큼 굵은 선)
	var ratio := clampf(float(u.hp) / BattleLogic.UNITS[u.kind].hp, 0.0, 1.0)
	if ratio < 1.0:
		draw_line(Vector2(px - 24, GROUND_Y - 158), Vector2(px + 24, GROUND_Y - 158), Color(0.2, 0.2, 0.2, 0.25), 3)
		draw_line(Vector2(px - 24, GROUND_Y - 158), Vector2(px - 24 + 48 * ratio, GROUND_Y - 158), INK, 3)

# 테이프 붙은 종이 조각 HUD: 내 기지(왼쪽 위), 적 기지(오른쪽 위)
func _draw_hud(font: Font) -> void:
	_hud_piece(font, Vector2(100, 22), -0.02, "우리 기지", 0, INK)
	_hud_piece(font, Vector2(880, 22), 0.02, "적 기지", 1, Color("0e0e16"))

func _hud_piece(font: Font, pos: Vector2, rot: float, label: String, team: int, bar_col: Color) -> void:
	draw_set_transform(pos, rot)
	draw_rect(Rect2(0, 0, 300, 84), Color("fbf6e6"))
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(300, 84)), Rect2(0, 0, 300, 84), false)
	# 테이프(반투명 노란 조각, 양 위 모서리)
	draw_set_transform(pos + Vector2(-8, -2), rot - 0.5)
	draw_rect(Rect2(0, 0, 50, 18), Color(0.95, 0.88, 0.5, 0.6))
	draw_set_transform(pos + Vector2(262, 0), rot + 0.5)
	draw_rect(Rect2(0, 0, 50, 18), Color(0.95, 0.88, 0.5, 0.6))
	draw_set_transform(pos, rot)
	var hp: int = maxi(0, logic.base_hp[team])
	draw_string(font, Vector2(18, 44), "%s %d" % [label, hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, INK)
	# 체력 막대: 손으로 그린 틀 + 채움
	var ratio := clampf(float(hp) / BattleLogic.BASE_HP, 0.0, 1.0)
	draw_rect(Rect2(18, 57, 264 * ratio, 12), Color(bar_col, 0.72))
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(268, 22)), Rect2(16, 52, 268, 22), false)
	draw_set_transform(Vector2.ZERO, 0.0)
