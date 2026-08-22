# 1과제 00007 수정본 요구사항 대조표

2026-08-23에 기존 문제·채점 PDF와 `mark.sh`, 재변환 수정본을 `1과제 촤종수정본/`의 release candidate 문제지·채점지·`d1-07-mark.sh`와 다시 대조했다.

| 범위 | 수정본 기준 | 구현 위치 |
| --- | --- | --- |
| 공식 자산 | 최종 후보의 `book-linux-amd64_v1.0.1`, `main.jpeg`와 SHA-256 일치; 최종 후보에 없는 `index.html`은 기존 공식본과 SHA-256 일치 | `assets/shared/book-image/`, `assets/foundation/` |
| ECR | scan-on-push, `IMMUTABLE_WITH_EXCLUSION`, `latest`, `v1.0.0`; 채점 전에 스캔 이력과 LOW 이상 0건 확인 | `foundation/`, `extensions/image-build/`, `Start-BookImageBuild.ps1` |
| EKS 접근 | public=false/private=true; 최종 문제지에서 EKS Access Entry 및 aws-auth 금지 강제는 삭제됨. Terraform 실행과 Pod Identity에 유효한 `API` 인증은 구현 선택으로 유지 | `cluster/main.tf`, `ERROR_CANDIDATES.md` |
| Node EC2 태그 | app/addon EC2 instance의 `Name`을 각각 `unicorn-k8snode-app-node`, `unicorn-k8snode-addon-node`로 지정 | `cluster/main.tf` |
| Book Deployment | `unicorn-book-app-deploy`, ready 2/2 | `addons/main.tf` |
| Service | `unicorn-book-app-svc`, `ClusterIP` | `addons/main.tf` |
| Probe·종료 | `/health`, `terminationGracePeriodSeconds=45`, `preStop sleep 15` | `addons/main.tf` |
| Pod Identity | service account `unicorn-book-app-sa` | `addons/main.tf` |
| ALB 연결 | `unicorn-alb`, `unicorn-tg`; 채점 대상 ClusterIP와 별개인 내부 NodePort bridge로 기존 instance target 경로 유지 | `addons/main.tf` |
| CloudFront | Distribution Comment `unicorn-svc-cf`; `/health`는 internal ALB VPC origin으로 전달 | `addons/main.tf` |
| S3 OAC | bucket policy의 `StringEquals.AWS:SourceArn`을 생성된 Distribution ARN으로 제한 | `addons/main.tf` |
| WAF | 50회/60초 IP rate rule, XSS와 rate-limit의 정확한 403 본문; 최종 스크립트의 동시 요청·재시도 방식 대응 | `addons/main.tf` |
| Log | `/health` 제외, 출력 키 `client_ip,method,path,status_code,timestamp` | `assets/addons/transform.lua`, `addons/main.tf` |
| Grafana | 선수별 계정, 지정된 5개 패널, 전용 ALB/TG | `assets/addons/dashboard.json`, `addons/observability-network.tf` |
| 시간 | 채점 Timestamp는 UTC 또는 KST 허용 | `assets/addons/transform.lua`, `ERROR_CANDIDATES.md` |

추가 bridge Service는 ALB가 EKS 노드의 NodePort로 전달하기 위한 구현 세부사항이며, 채점 대상 Service 이름과 형식은 수정본을 따른다.

최종 채점 PDF에서는 EKS authentication mode의 예상값이 제거됐지만 `d1-07-mark.sh`에는 조회 명령이 남아 있다. 출력 자체는 점수 판정값으로 사용되지 않으며 현재 `API`는 금지된 방식이 아니라 Terraform 적용 주체가 cluster를 관리하기 위한 구현 선택이다.
