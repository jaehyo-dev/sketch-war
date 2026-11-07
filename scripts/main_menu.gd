extends Control
# 메인 화면: 종이 질감 위에 손글씨 제목과 메뉴(글씨 + 밑줄 + 작은 낙서). 버튼 모양 없음.

const INK := Color("3a3a3e")
# 메인은 손글씨가 아니라 고딕: 제목 Black Han Sans, 메뉴·버전 나눔고딕 Bold (둘 다 SIL OFL)
const TITLE_FONT := preload("res://assets/fonts/BlackHanSans-Regular.ttf")
const MENU_FONT := preload("res://assets/fonts/NanumGothic-Bold.ttf")
# [글씨, 낙서, 눌렀을 때 갈 장면(빈 문자열 = 아직 없음)]
const MENU := [
	["출격", "arrow", "res://scenes/battle.tscn"],
	["편성", "star", ""],
	["도감", "spiral", ""],
	["설정", "bolt", ""],
]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	bg.material = mat
	add_child(bg)

	var spring := TextureRect.new()
	spring.texture = DoodleArt.spring(720)
	spring.position = Vector2(-14, 0)
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spring)

	var title := _label("스케치 전쟁", Vector2(0, 50), 140, Control.PRESET_TOP_LEFT, true)
	title.add_theme_font_override("font", TITLE_FONT)
	_deco(DoodleArt.wavy_line(700, 3.0, 3.4), Vector2(290, 215))
	# 제목 주변 작은 낙서
	_deco(DoodleArt.mini("star"), Vector2(210, 90))
	_deco(DoodleArt.mini("bolt"), Vector2(1020, 80))
	_deco(DoodleArt.mini("star"), Vector2(1100, 170))
	_deco(DoodleArt.mini("spiral"), Vector2(150, 190))
	# 아래쪽 풍경: 왼쪽은 아군, 오른쪽은 적(좌우 뒤집어 마주 봄). 코드 낙서 렌더러 그림
	_deco(DoodleArt.wavy_line(1100, 2.6, 3.0), Vector2(90, 632))
	for h in [["stickman", 50, false], ["eraser", 180, false], ["archer", 310, false], ["hairball", 840, true], ["horned", 990, true]]:
		_hero(h[0], h[1], h[2])

	for i in MENU.size():
		_menu_item(MENU[i], Vector2(520, 270 + i * 84))

	var ver := _label("v" + Version.VERSION, Vector2(1160, 676), 24, Control.PRESET_TOP_LEFT, false)
	ver.add_theme_font_override("font", MENU_FONT)
	ver.modulate = Color(1, 1, 1, 0.7)

func _hero(kind: String, x: float, flip: bool) -> void:
	var t := TextureRect.new()
	t.texture = DoodleArt.frames(kind)[0]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(176, 176)
	t.position = Vector2(x, 641 - 165)   # 그림 속 땅(y=150)이 땅 선에 닿게
	t.flip_h = flip
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)

func _deco(tex: Texture2D, pos: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)

func _label(text: String, pos: Vector2, font_size: int, _preset: int, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	l.position = pos
	if centered:
		l.size = Vector2(1280, font_size * 1.3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

# 메뉴 한 줄: 글씨(눌리는 곳) + 밑줄 + 옆의 작은 낙서
func _menu_item(item: Array, pos: Vector2) -> void:
	var b := Button.new()
	b.text = item[0]
	b.flat = true
	b.position = pos
	b.add_theme_font_override("font", MENU_FONT)
	b.add_theme_font_size_override("font_size", 50)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color("b03030"))
	b.add_theme_color_override("font_disabled_color", Color(0.23, 0.23, 0.25, 0.4))
	var scene: String = item[2]
	if scene == "":
		b.disabled = true   # 아직 없는 메뉴는 연하게(다음 버전에서 채움)
	else:
		b.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	add_child(b)
	_deco(DoodleArt.wavy_line(200, 1.6, 1.9), pos + Vector2(-6, 66))
	_deco(DoodleArt.mini(item[1]), pos + Vector2(210, 4))
