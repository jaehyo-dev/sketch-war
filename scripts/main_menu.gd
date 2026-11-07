extends Control
# 스케치북 표지 메인 화면. 그림은 임시 도형.

const PAPER := Color("f4ecd8")
const COVER := Color("c9a66b")

func _ready() -> void:
	var title := Label.new()
	title.text = "스케치 전쟁"
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color("3a2f25"))
	# 가로 폭 전체를 쓰고 글자를 가운데 정렬
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 160)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var start := Button.new()
	start.text = "시작"
	start.add_theme_font_size_override("font_size", 56)
	start.custom_minimum_size = Vector2(240, 90)
	start.position = Vector2(520, 380)
	start.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	add_child(start)

	var ver := Label.new()
	ver.text = "v" + Version.VERSION
	ver.add_theme_font_size_override("font_size", 32)
	ver.add_theme_color_override("font_color", Color("3a2f25"))
	ver.position = Vector2(1130, 660)
	add_child(ver)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), COVER)
	draw_rect(Rect2(90, 50, 1100, 620), PAPER)
	# 왼쪽 스프링 제본 구멍
	for i in 9:
		draw_circle(Vector2(90, 100 + i * 65), 14, Color("5a4630"))
