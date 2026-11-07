extends Control
# 전투 화면: BattleLogic을 돌리고 그리기만 한다. 그림은 임시 도형.

const LEFT_X := 160.0     # 전장 x=0이 화면 어디인지
const RIGHT_X := 1120.0
const GROUND_Y := 470.0
const SCALE := (RIGHT_X - LEFT_X) / BattleLogic.FIELD_LEN

var logic := BattleLogic.new()
var result_label: Label

func _ready() -> void:
	_add_button("고양이 소환", Vector2(60, 580), func(): logic.spawn(0))
	_add_button("시험용 적 소환", Vector2(380, 580), func(): logic.spawn(1))
	_add_button("처음으로", Vector2(1020, 40), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), 36)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 110)
	result_label.add_theme_color_override("font_color", Color("b03030"))
	result_label.position = Vector2(440, 180)
	add_child(result_label)

func _add_button(text: String, pos: Vector2, cb: Callable, size := 48) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.position = pos
	b.pressed.connect(cb)
	add_child(b)

func _process(delta: float) -> void:
	logic.tick(delta)
	if logic.winner != -1:
		result_label.text = "승리!" if logic.winner == 0 else "패배..."
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("f4ecd8"))
	draw_line(Vector2(0, GROUND_Y), Vector2(1280, GROUND_Y), Color("4a4036"), 4)
	_draw_base(LEFT_X, 0, Color("6a8fc0"))
	_draw_base(RIGHT_X, 1, Color("c06a6a"))
	for u in logic.units:
		_draw_cat(u)

# 기지(네모) + 체력 막대
func _draw_base(x: float, team: int, col: Color) -> void:
	draw_rect(Rect2(x - 40, GROUND_Y - 150, 80, 150), col)
	draw_rect(Rect2(x - 60, GROUND_Y - 190, 120, 14), Color("999999"))
	var ratio := clampf(float(logic.base_hp[team]) / BattleLogic.BASE_HP, 0.0, 1.0)
	draw_rect(Rect2(x - 60, GROUND_Y - 190, 120 * ratio, 14), Color("4caf50"))

# 고양이: 동그란 몸 + 삼각 귀 + 체력 막대 (팀 색으로 구분)
func _draw_cat(u: Dictionary) -> void:
	var p := Vector2(LEFT_X + u.x * SCALE, GROUND_Y - 22)
	var col := Color("8a8a8a") if u.team == 0 else Color("c08a4a")
	draw_circle(p, 22, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-20, -10), p + Vector2(-8, -34), p + Vector2(-2, -16)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(20, -10), p + Vector2(8, -34), p + Vector2(2, -16)]), col)
	draw_circle(p + Vector2(-8, -4), 3, Color.BLACK)
	draw_circle(p + Vector2(8, -4), 3, Color.BLACK)
	var ratio := clampf(float(u.hp) / BattleLogic.CAT.hp, 0.0, 1.0)
	draw_rect(Rect2(p.x - 20, p.y - 46, 40 * ratio, 5), Color("4caf50"))
