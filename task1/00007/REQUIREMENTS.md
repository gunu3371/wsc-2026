# 1과제 00007 수정본 요구사항 대조표

2026-08-21에 기존 문제·채점 PDF와 `mark.sh`를 `2026년 전국기능경기대회 hwp 수정본/1과제 00007/` PDF와 대조했다.

| 범위 | 수정본 기준 | 구현 위치 |
| --- | --- | --- |
| Book Deployment | `unicorn-book-app-deploy`, ready 2/2 | `addons/main.tf` |
| Service | `unicorn-book-app-svc`, `ClusterIP` | `addons/main.tf` |
| Probe·종료 | `/health`, `terminationGracePeriodSeconds=45`, `preStop sleep 15` | `addons/main.tf` |
| Pod Identity | service account `unicorn-book-app-sa` | `addons/main.tf` |
| ALB 연결 | `unicorn-alb`, `unicorn-tg`; 채점 대상 ClusterIP와 별개인 내부 NodePort bridge로 기존 instance target 경로 유지 | `addons/main.tf` |
| CloudFront | Distribution Comment `unicorn-svc-cf` | `addons/main.tf` |
| WAF | XSS 채점 및 custom response를 위한 override 허용 | `addons/main.tf` |
| 시간 | 채점 Timestamp는 UTC 또는 KST 허용 | `assets/addons/app.py`, `ERROR_CANDIDATES.md` |

추가 bridge Service는 ALB가 EKS 노드의 NodePort로 전달하기 위한 구현 세부사항이며, 채점 대상 Service 이름과 형식은 수정본을 따른다.
