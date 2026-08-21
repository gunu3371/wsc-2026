# 2과제 00007 수정본 요구사항 대조표

2026-08-21에 기존 문제·채점 PDF 및 `mark1.sh`~`mark4.sh`를 `2026년 전국기능경기대회 hwp 수정본/2과제 00007/` PDF와 대조했다.

| 모듈 | 수정본에서 명확해진 조건 | 구현·검증 위치 |
| --- | --- | --- |
| CDN | `skillsphone-cdn-ab-distribution`은 CloudFront Distribution Comment | `cdn/main.tf` |
| Scaling | Pod와 Node의 scale-out·scale-in이 모두 2분 이내 발생 | `scaling/main.tf`, 실제 부하 검증 필요 |
| Scaling 관찰 | 수정 채점 PDF의 관찰 반복은 5초 간격 30회 | `ERROR_CANDIDATES.md`에서 기존 스크립트와 차이 추적 |
| O11y | Loki query 명령의 URL과 option을 정상 공백·줄바꿈으로 실행 | 공식 PDF는 수정됐으나 기존 `mark4.sh`에는 NBSP가 남음 |
| 시간 | UTC 또는 KST 모두 허용 | 채점 절차 |

실제 AWS 부하 시험 없이 KEDA·Karpenter 시간을 추측으로 변경하지 않는다.
