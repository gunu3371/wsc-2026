# 1과제 00003 수정본 요구사항 대조표

2026-08-21에 기존 문제·채점 PDF 및 `mark.sh`를 `2026년 전국기능경기대회 hwp 수정본/1과제 00003/` PDF와 대조했다. 수정본의 공식 게시 여부는 로그인 전용 채널에서 추가 확인이 필요하다.

| 범위 | 수정본에서 명확해진 조건 | 구현·검증 위치 |
| --- | --- | --- |
| 로그·메트릭 | 최소 한 번의 애플리케이션 로그와 metric을 생성해 수집 여부 확인 | `addons/observability.tf`, `extensions/observability-fix/` |
| Node | CPU, Memory, Available Nodes | `assets/addons/dashboard.json.tftpl` |
| Pod | CPU, Memory, Pending, Restarts | `assets/addons/dashboard.json.tftpl` |
| Application Pod | CPU, Memory, Running, Restarts, Pending | `assets/addons/dashboard.json.tftpl` |
| Application Traffic | Request Count, Response Time, Status Code, Application Logs | `assets/addons/dashboard.json.tftpl` |
| 채점 준비 | `not-ready`, `error-gen`, `latency-gen`, `crash-test`, `stress-cpu`, `stress-mem` 생성 후 180초 대기 | 공식 `mark.sh`, `README.md` |
| Alert | 수정 채점 PDF에서는 `HighLatency Alert`를 채점과 무관하다고 안내 | `ERROR_CANDIDATES.md`에서 스크립트와 불일치 추적 |

공식 바이너리와 채점 스크립트는 수정하지 않는다.
