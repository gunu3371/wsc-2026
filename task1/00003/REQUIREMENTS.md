# 1과제 00003 최종 release candidate 요구사항 대조표

2026-08-23에 기존 문제·채점 자료와 현재 구현을 `1과제 촤종수정본/day1-03-release-candidate-tp.pdf`, `day1-03-release-candidate-marking.pdf`, `d1-03-mark.sh`와 대조했다. 이 release candidate 이후의 공식 게시 여부는 로그인 전용 채널에서 추가 확인이 필요하다.

| 범위 | 최종본에서 명확해진 조건 | 구현·검증 위치 |
| --- | --- | --- |
| 선수 입력 | 과제번호와 별도로 선수 비번호 및 S3용 영문 네 자리 사용 | `terraform.tfvars.example` |
| DynamoDB | PITR 35일, Pod 역할 `PutItem`, Lambda 역할 `Query`, 두 주체를 구분한 table resource policy | `platform/data_registry.tf`, `platform/workload_iam.tf`, `platform/storage_lambda.tf` |
| IAM 채점 | 최종 스크립트는 customer-managed policy와 inline policy의 action을 모두 확인 | 현재 두 역할은 customer-managed policy로 최소 권한 부여 |
| ECR | `MUTABLE_WITH_EXCLUSION`, `v1*`, 공식 바이너리 `v1.0.0`만 유지 | `platform/`, `extensions/image-build/` |
| 배포 순서 | ALB 생성 후 CloudFront가 생성되도록 state 순환 제거 | `addons/`, `delivery/` |
| WAF | SQLi·XSS 및 200회/60초 rate limit을 구성하고 최종 스크립트가 실제 HTTP 403을 확인 | `delivery/main.tf`의 AWS managed SQLi/Common rule과 rate-based block rule |
| 로그·메트릭 | 최소 한 번의 애플리케이션 로그와 metric을 생성해 수집 여부 확인 | `addons/observability.tf`, `addons/observability-access.tf` |
| Node | CPU, Memory, Available Nodes | `assets/addons/dashboard.json.tftpl` |
| Pod | CPU, Memory, Pending, Restarts | `assets/addons/dashboard.json.tftpl` |
| Application Pod | CPU, Memory, Running, Restarts, Pending | `assets/addons/dashboard.json.tftpl` |
| Application Traffic | Request Count, Response Time, Status Code, Application Logs | `assets/addons/dashboard.json.tftpl` |
| 채점 준비 | `not-ready`, `error-gen`, `latency-gen`, `crash-test`, `stress-cpu`, `stress-mem` 생성 후 180초 대기 | 공식 `mark.sh`, `README.md` |
| Alert | 최종 채점 PDF와 스크립트에서는 `HighLatency Alert`를 채점과 무관하다고 안내 | 점수 대상 5개 alert 구현, 문제지와의 불일치는 `ERROR_CANDIDATES.md`에서 추적 |

공식 바이너리와 채점 스크립트는 수정하지 않는다.
