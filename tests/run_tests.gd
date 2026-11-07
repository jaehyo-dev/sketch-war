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
	check(is_equal_approx(b.units[0].x, BattleLogic.CAT.speed), "플레이어 고양이 전진")
	check(is_equal_approx(b.units[1].x, BattleLogic.FIELD_LEN - BattleLogic.CAT.speed), "상대 고양이 반대 방향 전진")

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
	check(d.units[0].hp == BattleLogic.CAT.hp and d.units[1].hp == BattleLogic.CAT.hp, "사거리 밖 무피해")

	# 기지 공격: 상대 기지 앞에서 멈추고 기지 체력이 깎임
	var e := BattleLogic.new()
	e.spawn(0)
	e.units[0].x = BattleLogic.FIELD_LEN - 30.0
	e.tick(0.1)
	check(e.base_hp[1] == BattleLogic.BASE_HP - BattleLogic.CAT.atk, "기지 공격")
	check(e.units[0].x == BattleLogic.FIELD_LEN - 30.0, "기지 앞에서 정지")

	# 승리 판정: 기지가 0이 되면 winner 확정, 이후 소환 불가
	var f := BattleLogic.new()
	f.base_hp[1] = BattleLogic.CAT.atk
	f.spawn(0)
	f.units[0].x = BattleLogic.FIELD_LEN
	f.tick(0.1)
	check(f.winner == 0 and f.base_hp[1] <= 0, "플레이어 승리")
	f.spawn(0)
	check(f.units.size() == 1, "종료 후 소환 불가")

	# 결과 고정(무작위 없음): 같은 입력 → 같은 결과
	var r1 := _simulate()
	var r2 := _simulate()
	check(r1 == r2 and r1 != "", "시뮬레이션 재현성: " + r1)

	print("실패 ", fails, "건")
	quit(1 if fails > 0 else 0)

func _simulate() -> String:
	var s := BattleLogic.new()
	for i in 5:
		s.spawn(0)
		s.tick(2.0)
	for i in 300:
		s.tick(0.1)
	return "%d/%d/%d" % [s.base_hp[0], s.base_hp[1], s.winner]
