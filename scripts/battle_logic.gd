class_name BattleLogic
extends RefCounted
# 전투 규칙만 담은 순수 로직(화면 없음). 무작위 요소가 없어 결과가 항상 같다.
# 팀 0 = 플레이어(왼쪽 기지에서 오른쪽으로), 팀 1 = 상대(오른쪽 기지에서 왼쪽으로).

const FIELD_LEN := 1000.0   # 전장 길이: 왼쪽 기지 x=0, 오른쪽 기지 x=FIELD_LEN
const BASE_HP := 1000

# 종류별 능력치. cost는 카드에 표시만 한다(돈 시스템은 v0.3.0). card_cd = 카드 재사용 대기(초).
const UNITS := {
	"stickman": {"hp": 100, "atk": 10, "range": 40.0, "speed": 60.0, "cooldown": 1.0, "cost": 50, "card_cd": 2.0},
	"eraser": {"hp": 220, "atk": 6, "range": 36.0, "speed": 40.0, "cooldown": 1.2, "cost": 100, "card_cd": 4.0},
	"archer": {"hp": 60, "atk": 8, "range": 170.0, "speed": 50.0, "cooldown": 1.1, "cost": 120, "card_cd": 4.0},
	"rabbit": {"hp": 70, "atk": 7, "range": 34.0, "speed": 110.0, "cooldown": 0.8, "cost": 80, "card_cd": 3.0},
	"inkblot": {"hp": 120, "atk": 8, "range": 40.0, "speed": 45.0, "cooldown": 1.2},
	"hairball": {"hp": 60, "atk": 6, "range": 36.0, "speed": 90.0, "cooldown": 0.8},
	"horned": {"hp": 260, "atk": 14, "range": 44.0, "speed": 35.0, "cooldown": 1.5},
}

var units: Array = []                       # 각 유닛: {id, kind, team, x, hp, cd}
var card_cd := {}                           # 종류 → 카드 남은 대기 시간(초)
var _next_id := 0
var base_hp: Array = [BASE_HP, BASE_HP]     # 인덱스 = 팀
var winner := -1                            # -1 진행 중, 0/1 = 이긴 팀

# 팀 기지 위치에서 유닛을 소환한다.
func spawn(team: int, kind := "stickman") -> void:
	if winner != -1 or not UNITS.has(kind):
		return
	var x := 0.0 if team == 0 else FIELD_LEN
	units.append({"id": _next_id, "kind": kind, "team": team, "x": x, "hp": UNITS[kind].hp, "cd": 0.0})
	_next_id += 1

# 플레이어 카드로 소환: 카드 대기 중이면 false
func summon_card(kind: String) -> bool:
	if card_cd.get(kind, 0.0) > 0.0 or winner != -1:
		return false
	spawn(0, kind)
	card_cd[kind] = UNITS[kind].card_cd
	return true

# 카드 대기 비율(0=사용 가능 ~ 1=방금 사용)
func card_ratio(kind: String) -> float:
	return clampf(card_cd.get(kind, 0.0) / UNITS[kind].card_cd, 0.0, 1.0)

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
		if dist >= 0.0 and dist <= UNITS[u.kind].range and dist < best_dist:
			best = o
			best_dist = dist
	return best

func tick(dt: float) -> void:
	if winner != -1:
		return
	for k in card_cd:
		card_cd[k] = maxf(0.0, card_cd[k] - dt)
	for u in units:
		if u.hp <= 0:
			continue
		var st: Dictionary = UNITS[u.kind]
		u.cd = maxf(0.0, u.cd - dt)
		var target = _find_target(u)
		var enemy_team := 1 - int(u.team)
		var enemy_base_x := FIELD_LEN if u.team == 0 else 0.0
		var in_base_range: bool = absf(enemy_base_x - u.x) <= st.range
		if target != null or in_base_range:
			if u.cd <= 0.0:
				u.cd = st.cooldown
				if target != null:
					target.hp -= st.atk
				else:
					base_hp[enemy_team] -= st.atk
		else:
			u.x += dir_of(u.team) * st.speed * dt
	units = units.filter(func(o): return o.hp > 0)
	if base_hp[1] <= 0:
		winner = 0
	elif base_hp[0] <= 0:
		winner = 1
