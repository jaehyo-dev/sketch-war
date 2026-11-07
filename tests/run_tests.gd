extends SceneTree
# 실행: godot --headless -s tests/run_tests.gd   (실패가 하나라도 있으면 종료 코드 1)

var fails := 0

func check(cond: bool, name: String) -> void:
	if cond:
		print("통과: ", name)
	else:
		fails += 1
		print("실패: ", name)

func _init() -> void:
	# 버전 상수 = CHANGELOG 최신 버전
	var log_text := FileAccess.get_file_as_string("res://CHANGELOG.md")
	var re := RegEx.create_from_string("(?m)^## \\[?v?(\\d+\\.\\d+\\.\\d+)")
	var m := re.search(log_text)
	check(m != null and m.get_string(1) == Version.VERSION, "CHANGELOG 최신 버전 == Version.VERSION")

	# 소환은 자기 기지에서 시작
	var b := BattleLogic.new()
	b.spawn(0)
	b.spawn(1)
	check(b.units.size() == 2 and b.units[0].x == 0.0 and b.units[1].x == BattleLogic.FIELD_LEN, "소환 위치")

	# 전진: 1초에 speed만큼, 상대는 반대 방향
	b.tick(1.0)
	check(is_equal_approx(b.units[0].x, BattleLogic.UNITS.stickman.speed), "플레이어 고양이 전진")
	check(is_equal_approx(b.units[1].x, BattleLogic.FIELD_LEN - BattleLogic.UNITS.stickman.speed), "상대 고양이 반대 방향 전진")

	# 적 고양이끼리 만나면 싸우고, 먼저 죽는 쪽이 사라짐
	var c := BattleLogic.new()
	c.spawn(0)
	c.units[0].x = 500.0
	c.spawn(1)
	c.units[1].x = 520.0
	for i in 200:
		c.tick(0.1)
	check(c.units.size() == 1, "맞붙은 고양이 중 한쪽만 생존")

	# 사거리 밖이면 때리지 않음
	var d := BattleLogic.new()
	d.spawn(0)
	d.spawn(1)
	d.units[0].x = 100.0
	d.units[1].x = 900.0
	d.tick(0.1)
	check(d.units[0].hp == BattleLogic.UNITS.stickman.hp and d.units[1].hp == BattleLogic.UNITS.stickman.hp, "사거리 밖 무피해")

	# 기지 공격: 상대 기지 앞에서 멈추고 기지 체력이 깎임
	var e := BattleLogic.new()
	e.spawn(0)
	e.units[0].x = BattleLogic.FIELD_LEN - 30.0
	for i in 5:
		e.tick(0.1)   # 준비 0.25초 뒤에 타격
	check(e.base_hp[1] == BattleLogic.BASE_HP - BattleLogic.UNITS.stickman.atk, "기지 공격")
	check(e.units[0].x == BattleLogic.FIELD_LEN - 30.0, "기지 앞에서 정지")

	# 승리 판정: 기지가 0이 되면 winner 확정, 이후 소환 불가
	var f := BattleLogic.new()
	f.base_hp[1] = BattleLogic.UNITS.stickman.atk
	f.spawn(0)
	f.units[0].x = BattleLogic.FIELD_LEN
	for i in 5:
		f.tick(0.1)
	check(f.winner == 0 and f.base_hp[1] <= 0, "플레이어 승리")
	f.spawn(0)
	check(f.units.size() == 1, "종료 후 소환 불가")

	# 결과 고정(무작위 없음): 같은 입력 → 같은 결과
	var r1 := _simulate()
	var r2 := _simulate()
	check(r1 == r2 and r1 != "", "시뮬레이션 재현성: " + r1)

	# 공격 타이밍: 준비 중에는 데미지 없음 → 준비가 끝나는 틱에 데미지 → 타격 자세 → 걷기로 복귀
	var w := BattleLogic.new()
	w.spawn(0)
	w.spawn(1, "inkblot")
	w.units[0].x = 500.0
	w.units[1].x = 520.0
	var hp0: int = w.units[1].hp
	w.tick(0.1)
	check(w.units[0].state == "windup" and w.units[1].hp == hp0, "준비 시작: 아직 데미지 없음")
	w.tick(0.1)
	w.tick(0.1)
	check(w.units[1].hp == hp0, "준비 중 데미지 없음")
	w.tick(0.1)
	check(w.units[1].hp == hp0 - BattleLogic.UNITS.stickman.atk and w.units[1].hurt_t > 0.0, "준비 끝나는 틱에 타격·피격 표시")
	check(w.units[0].state == "strike", "타격 자세")
	# 양쪽이 동시에 때리므로 이벤트 2건: 적이 맞은 것(팀 1)은 x=520, 스틱맨 데미지
	var hit = w.events.filter(func(ev): return ev.team == 1)
	check(w.events.size() == 2 and hit.size() == 1 and hit[0].x == 520.0 and hit[0].dmg == BattleLogic.UNITS.stickman.atk and not hit[0].base, "타격 이벤트(맞은 위치·데미지)")
	check(e.events.size() == 1 and e.events[0].base and e.events[0].team == 1, "기지 타격 이벤트")
	w.tick(BattleLogic.STRIKE + 0.01)
	check(w.units[0].state == "walk", "타격 후 복귀")

	# 준비 중 대상이 사라지면 헛스윙(데미지 없음, 기지에도 안 들어감)
	var ms := BattleLogic.new()
	ms.spawn(0)
	ms.spawn(1)
	ms.units[0].x = 500.0
	ms.units[1].x = 520.0
	ms.tick(0.1)
	ms.units[1].hp = 0
	ms.tick(0.2)
	ms.tick(0.2)
	check(ms.units[0].state == "strike" and ms.base_hp[1] == BattleLogic.BASE_HP, "대상 사라지면 헛스윙")

	# 유닛 종류별 능력치: 소환한 종류의 체력이 들어감, 모르는 종류는 무시
	var g := BattleLogic.new()
	g.spawn(0, "eraser")
	g.spawn(1, "horned")
	g.spawn(1, "없는종류")
	check(g.units.size() == 2 and g.units[0].hp == 220 and g.units[1].hp == 260, "종류별 체력, 잘못된 종류 무시")

	# 카드 쿨타임: 쓰면 대기, 시간이 지나면 다시 사용 가능
	var h := BattleLogic.new()
	check(h.summon_card("rabbit") and not h.summon_card("rabbit"), "카드 대기 중 재소환 불가")
	check(h.card_ratio("rabbit") == 1.0, "카드 대기 비율 1.0")
	h.tick(1.5)
	check(is_equal_approx(h.card_ratio("rabbit"), 0.5), "카드 대기 비율 감소")
	h.tick(1.5)
	check(h.card_ratio("rabbit") == 0.0 and h.summon_card("rabbit"), "대기 끝나면 재소환")

	# 낙서 렌더러: 같은 시드 = 같은 그림, 프레임마다 서로 눈에 띄게 다름
	var st := Doodle.style_for_level(1)
	var shp := DoodleArt.shapes("stickman")
	var f0 := Doodle.bake(shp, DoodleArt.SIZE, 7, st, 0)
	check(f0.get_data() == Doodle.bake(shp, DoodleArt.SIZE, 7, st, 0).get_data(), "낙서 굽기 재현성(같은 시드)")
	var f1 := Doodle.bake(shp, DoodleArt.SIZE, 7, st, 1)
	check(_diff(f0, f1) > 150, "떨림 프레임이 서로 다름 (차이 %d픽셀)" % _diff(f0, f1))
	check(_ink(f0) > 400 and _ink(f0) < 3000, "스틱맨 선 굵기 적당 (잉크 %d픽셀)" % _ink(f0))
	# 적은 아군보다 훨씬 어둡고 촘촘
	var en := Doodle.bake(DoodleArt.shapes("inkblot"), DoodleArt.SIZE, 7, Doodle.enemy_style(), 0)
	check(_ink(en) > _ink(f0) * 4, "적 스크리블이 아군보다 4배 이상 촘촘 (적 %d)" % _ink(en))
	# 7렙부터 음영 빗금이 생겨 잉크가 늘어남
	var hi := Doodle.bake(shp, DoodleArt.SIZE, 7, Doodle.style_for_level(9), 0)
	check(_ink(hi) > _ink(f0), "고레벨 음영 빗금 추가")
	# 타격 이펙트 폭발 낙서 3종이 그려지고 서로 다름
	var b0 := DoodleArt.burst(0).get_image()
	check(_ink(b0) > 800 and _diff(b0, DoodleArt.burst(1).get_image()) > 300, "타격 폭발 낙서 (잉크 %d)" % _ink(b0))
	# 스틱맨 자세 5종: 모두 그려지고, 서로 다르며, 발은 땅(y≈148) 근처에 있음
	var poses := {}
	for pn in DoodleArt.POSE_NAMES:
		poses[pn] = Doodle.bake(DoodleArt.posed_shapes("stickman", pn, 1), DoodleArt.SIZE, hash("stickman"), st, 0)
		check(_ink(poses[pn]) > 400 and _lowest(poses[pn]) >= 144 and _lowest(poses[pn]) <= 152, "자세 %s: 그려짐, 발이 땅에 (최저 y %d)" % [pn, _lowest(poses[pn])])
	check(_diff(poses.walk_a, poses.strike) > 250 and _diff(poses.walk_a, poses.windup) > 250 and _diff(poses.walk_a, poses.walk_b) > 150, "자세끼리 눈에 띄게 다름")
	for k in DoodleArt.ALLY_KINDS + DoodleArt.ENEMY_KINDS:
		check(not DoodleArt.shapes(k).is_empty() and BattleLogic.UNITS.has(k), "도형·능력치 정의: " + k)

	print("실패 ", fails, "건")
	quit(1 if fails > 0 else 0)

# 알파가 일정 이상인 픽셀 수
func _ink(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.4:
				n += 1
	return n

# 잉크가 있는 가장 아래 행
func _lowest(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.4:
				return y
	return -1

# 잉크 여부가 서로 다른 픽셀 수
func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if (a.get_pixel(x, y).a > 0.4) != (b.get_pixel(x, y).a > 0.4):
				n += 1
	return n

func _simulate() -> String:
	var s := BattleLogic.new()
	for i in 5:
		s.spawn(0)
		s.tick(2.0)
	for i in 300:
		s.tick(0.1)
	return "%d/%d/%d" % [s.base_hp[0], s.base_hp[1], s.winner]
