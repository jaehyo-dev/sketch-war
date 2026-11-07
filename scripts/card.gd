class_name UnitCard
extends Control
# 하단 메모지 카드: 접힌 모서리, 낙서 아이콘(같은 렌더러), 비용, 시계 방향 쿨타임 오버레이.
# 쿨타임 오버레이는 그림에 넣지 않고 여기서 따로 그린다.

signal tapped(kind: String)

var kind := ""
var cost := 0
var cd_ratio := 0.0      # 0 = 사용 가능, 1 = 방금 사용(오버레이가 가득)
var time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(kind)

func _draw() -> void:
	var fold := 28.0
	# 메모지 몸통(오른쪽 아래 모서리를 접어 자름)
	var body := PackedVector2Array([Vector2(4, 4), Vector2(146, 4), Vector2(146, 150 - fold), Vector2(150 - fold, 146), Vector2(4, 146)])
	draw_colored_polygon(body, Color("fff2a6"))
	draw_colored_polygon(PackedVector2Array([Vector2(146, 150 - fold), Vector2(150 - fold, 146), Vector2(150 - fold, 150 - fold)]), Color("e6d57f"))
	draw_texture_rect(DoodleArt.rect_outline(Vector2i(150, 150)), Rect2(0, 0, 150, 150), false)
	# 아이콘: 유닛 낙서 한 장(떨림 프레임 그대로 8fps)
	var frames := DoodleArt.frames(kind)
	draw_texture_rect(frames[DoodleArt.frame_at(time)], Rect2(15, 4, 120, 120), false)
	# 비용
	var font := get_theme_default_font()
	draw_string(font, Vector2(14, 142), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("3a3a3e"))
	# 쿨타임: 12시 방향에서 시계 방향으로 줄어드는 반투명 부채꼴(카드 사각형 안으로 잘라 그림)
	if cd_ratio > 0.0:
		var c := Vector2(75, 75)
		var pts := PackedVector2Array([c])
		var steps := 48
		for i in steps + 1:
			var ang := -PI / 2.0 + TAU * (1.0 - cd_ratio) + TAU * cd_ratio * i / steps
			pts.append(c + _to_edge(Vector2(cos(ang), sin(ang))))
		draw_colored_polygon(pts, Color(0.2, 0.2, 0.22, 0.42))

# 중심에서 방향 d로 쏜 광선이 카드 안쪽 사각형(4..146)과 만나는 지점
func _to_edge(d: Vector2) -> Vector2:
	var tx := 71.0 / maxf(absf(d.x), 0.0001)
	var ty := 71.0 / maxf(absf(d.y), 0.0001)
	return d * minf(tx, ty)
