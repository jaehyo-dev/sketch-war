class_name BattleLogic
extends RefCounted
# 전투 규칙만 담은 순수 로직(화면 없음). 무작위 요소가 없어 결과가 항상 같다.
# 팀 0 = 플레이어(왼쪽 기지에서 오른쪽으로), 팀 1 = 상대(오른쪽 기지에서 왼쪽으로).

const FIELD_LEN := 1000.0   # 전장 길이: 왼쪽 기지 x=0, 오른쪽 기지 x=FIELD_LEN
const BASE_HP := 1000

# 고양이 능력치(v0.4.0에서 유닛이 늘면 데이터 표로 확장)
const CAT := {"hp": 100, "atk": 10, "range": 40.0, "speed": 60.0, "cooldown": 1.0}

var units: Array = []                       # 각 유닛: {team, x, hp, cd}
var base_hp: Array = [BASE_HP, BASE_HP]     # 인덱스 = 팀
var winner := -1                            # -1 진행 중, 0/1 = 이긴 팀

# 팀 기지 위치에서 고양이를 소환한다.
func spawn(team: int) -> void:
	if winner != -1:
		return
	var x := 0.0 if team == 0 else FIELD_LEN
	units.append({"team": team, "x": x, "hp": CAT.hp, "cd": 0.0})

# 팀의 전진 방향(+1 / -1)
static func dir_of(team: int) -> float:
	return 1.0 if team == 0 else -1.0

# u 앞쪽에서 사거리 안에 있는 가장 가까운 적 유닛(없으면 null)
func _find_target(u: Dictionary):
	var d := dir_of(u.team)
	var best = null
	var best_dist := INF
	for o in units:
		if o.team == u.team or o.hp <= 0:
			continue
		var dist: float = (o.x - u.x) * d   # 내 앞쪽이면 양수
		if dist >= 0.0 and dist <= CAT.range and dist < best_dist:
			best = o
			best_dist = dist
	return best

func tick(dt: float) -> void:
	if winner != -1:
		return
	for u in units:
		if u.hp <= 0:
			continue
		u.cd = maxf(0.0, u.cd - dt)
		var target = _find_target(u)
		var enemy_team := 1 - int(u.team)
		var enemy_base_x := FIELD_LEN if u.team == 0 else 0.0
		var in_base_range: bool = absf(enemy_base_x - u.x) <= CAT.range
		if target != null or in_base_range:
			if u.cd <= 0.0:
				u.cd = CAT.cooldown
				if target != null:
					target.hp -= CAT.atk
				else:
					base_hp[enemy_team] -= CAT.atk
		else:
			u.x += dir_of(u.team) * CAT.speed * dt
	units = units.filter(func(o): return o.hp > 0)
	if base_hp[1] <= 0:
		winner = 0
	elif base_hp[0] <= 0:
		winner = 1
