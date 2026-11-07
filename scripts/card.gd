class_name UnitCard
extends Control
# 하단 메모지 카드: 종류별 색, 그림자, 테이프, 접힌 모서리, 낙서 아이콘(같은 렌더러), 비용, 시계 방향 쿨타임 오버레이.
# 쿨타임 오버레이는 그림에 넣지 않고 여기서 따로 그린다.

signal tapped(kind: String)

const COST_FONT := preload("res://assets/fonts/BlackHanSans-Regular.ttf")
const COLORS := {"stickman": Color("fff2a6"), "eraser": Color("ffd3d9"), "archer": Color("cfe6ff"), "rabbit": Color("d6f0c8")}

var kind := ""
var cost := 0
var cd_ratio := 0.0      # 0 = 사용 가능, 1 = 방금 사용(오버레이가 가득)
var cd_left := 0.0       # 남은 초(오버레이 위 숫자)
var time := 0.0
var level := 1           # 아이콘 그림 레벨

func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	size = Vector2(120, 120)
	pivot_offset = Vector2(60, 60)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(kind)
		# 눌림 반응: 살짝 작아졌다 돌아옴
		scale = Vector2(0.92, 0.92)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.8, 0.8))   # 150칸 기준으로 그리고 0.8배로 줄임
	var fold := 28.0
	var paper: Color = COLORS.get(kind, Color("fff2a6"))
	var body := PackedVector2Array([Vector2(4, 4), Vector2(146, 4), Vector2(146, 150 - fold), Vector2(150 - fold, 146), Vector2(4, 146)])
	# 그림자 → 몸통 → 접힌 모서리
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(5, 7))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.2))
	draw_colored_polygon(body, paper)
	draw_colored_polygon(PackedVector2Array([Vector2(146, 150 - fold), Vector2(150 - fold, 146), Vector2(150 - fold, 150 - fold)]), paper.darkened(0.14))
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(150, 150)), Rect2(0, 0, 150, 150), false)
	# 위쪽 테이프
	draw_colored_polygon(PackedVector2Array([Vector2(50, -4), Vector2(104, -6), Vector2(102, 14), Vector2(48, 16)]), Color(0.96, 0.9, 0.62, 0.75))
	# 아이콘: 유닛 낙서 한 장(떨림 프레임 그대로 8fps)
	var frames := DoodleArt.frames(kind, level)
	draw_texture_rect(frames[DoodleArt.frame_at(time)], Rect2(15, 8, 120, 120), false)
	# 비용: 굵은 고딕 + 흰 테두리
	draw_string_outline(COST_FONT, Vector2(12, 142), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color("fffaf0"))
	draw_string(COST_FONT, Vector2(12, 142), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("2e2e34"))
	# 쿨타임: 12시 방향에서 시계 방향으로 걷혀 가는 반투명 부채꼴(카드 사각형 안으로 잘라 그림) + 남은 초
	if cd_ratio > 0.0:
		var c := Vector2(75, 75)
		var pts := PackedVector2Array([c])
		var steps := 48
		for i in steps + 1:
			var ang := -PI / 2.0 + TAU * (1.0 - cd_ratio) + TAU * cd_ratio * i / steps
			pts.append(c + _to_edge(Vector2(cos(ang), sin(ang))))
		draw_colored_polygon(pts, Color(0.2, 0.2, 0.24, 0.5))
		draw_string(COST_FONT, Vector2(0, 92), str(ceili(cd_left)), HORIZONTAL_ALIGNMENT_CENTER, 150, 64, Color(1, 1, 1, 0.92))

# 중심에서 방향 d로 쏜 광선이 카드 안쪽 사각형(4..146)과 만나는 지점
func _to_edge(d: Vector2) -> Vector2:
	var tx := 71.0 / maxf(absf(d.x), 0.0001)
	var ty := 71.0 / maxf(absf(d.y), 0.0001)
	return d * minf(tx, ty)
