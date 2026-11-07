# CREDITS

외부 라이브러리·에셋·AI 생성 그림을 쓸 때마다 이름, 버전, 만든 사람, 라이선스, 출처, 쓰는 곳, 수정 여부를 적는다.

| 이름 | 버전 | 만든 사람 | 라이선스 | 출처 | 쓰는 곳 | 수정 |
|---|---|---|---|---|---|---|
| Nanum Pen Script (글꼴) | google/fonts main(2026-11-08 수신) | NHN Corporation | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/nanumpenscript | 모든 화면 글자(assets/fonts/, 라이선스 OFL.txt 동봉) | 없음 |
| 코드 낙서 렌더러 + 종이 질감 셰이더 | v0.1.1 | 직접 제작(Claude 작성) | 프로젝트 자체 코드 | scripts/doodle.gd, shaders/paper.gdshader | 유닛·적·메뉴 장식·땅 선·종이 배경(별도 종이 텍스처 파일 없이 셰이더 노이즈로 생성) | - |
| base_tower.png (연필 탑) | v0.1.1 | AI 생성(Codex 내장 이미지 생성) | 생성물(사용 제한 없음, 외부 에셋 아님) | 프롬프트는 ASSET_PROMPTS.md. 원본 assets/raw/base_tower_raw.png | 아군 기지 | 밝기 기반 알파로 종이 제거(rembg 시험 후 윤곽 안쪽까지 흰색이 남아 밝기 방식 채택), 잘라내기, 높이 300으로 축소. v0.2.1에서 안쪽을 종이색으로 채우고 선을 진하게 재처리 |
| base_castle.png (볼펜 성) | v0.1.1 | AI 생성(Codex 내장 이미지 생성) | 생성물(사용 제한 없음, 외부 에셋 아님) | 프롬프트는 ASSET_PROMPTS.md. 원본 assets/raw/base_castle_raw.png | 적 기지 | 위와 같음 |
| Black Han Sans (글꼴) | google/fonts main(2026-11-08 수신) | Black Han Sans Project Authors (Zess Type) | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/blackhansans | 메인 화면 제목(assets/fonts/, 라이선스 OFL_BlackHanSans.txt 동봉) | 없음 |
| Nanum Gothic Bold (글꼴) | google/fonts main(2026-11-08 수신) | NHN Corporation | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/nanumgothic | 메인 화면 메뉴·버전(assets/fonts/, 라이선스 OFL_NanumGothic.txt 동봉) | 없음 |
| bg_battle.png (연필 풍경 스케치) | v0.2.1 | AI 생성(Codex 내장 이미지 생성) | 생성물(사용 제한 없음, 외부 에셋 아님) | 프롬프트는 ASSET_PROMPTS.md. 원본 assets/raw/bg_battle_raw.png | 전투 배경(움직이지 않음) | 밝기 기반 알파로 종이 제거, 1280x720 축소, 아래로 64px 이동 |
