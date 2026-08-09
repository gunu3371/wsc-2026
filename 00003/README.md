# 00003 Terraform 자동화 분석

## 목표와 분리 원칙

`37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003`의 두 과제를 IaC로 재현한다. `task1`과 `task2/{cdn,keycloak,logging,workflow}`를 별도 root module/state로 구성한다. 이름과 리전은 자동 채점 입력이므로 그대로 사용한다.

## 1과제: Solution Architecture (`ap-northeast-2`)

### 핵심 리소스

- VPC `wsc2026-skills-vpc` (`192.168.0.0/16`). Public A/B와 Private A/B, IGW, AZ별 NAT.
- DynamoDB `wsc2026-book-table`: PK `client_id`, `booking_id` 조회용 GSI, on-demand, PITR, deletion protection, KMS alias `wsc2026-db-kms`.
- ECR `wsc2026-book-ecr`: KMS `wsc2026-ecr-kms`, scan, `v1.0.0`만 유지. v1 계열 tag 불변성 요구를 repository policy/lifecycle 및 배포 단계로 보완.
- Private EKS `wsc2026-eks-cluster`, 버전 `1.35`, 전체 control-plane log, secret encryption `wsc2026-eks-kms`, custom cluster domain `wsc2026.skills.local`.
- Node groups: `wsc2026-addon-nodegroup` (`wsc2026/node=addon`)과 `wsc2026-workload-ng` (`wsc2026/node=application`), `t3.medium`.
- Kubernetes: namespace `wsc2026`, deployment/service/ingress, ConfigMap `book-config`, Pod Identity, 3종 probe, topology spread, PDB, request/limit 250m/512Mi.
- S3 `wsc2026-static-<영문4자>-<비번호>-bucket`, OAC 전용, versioning, bucket key 및 KMS `wsc2026-bucket-kms`.
- Lambda `wsc2026-book-get-function`, Python 3.12, KMS `wsc2026-function-kms`, 최소권한 role/policy. `booking_id`로 조회하며 지정 응답 순서/시간 포맷 준수.
- ALB `wsc2026-app-alb`, default 403, CloudFront 전용 origin.
- CloudFront `wsc2026-cdn`: S3 캐시, `/booking`→ALB, `/v1/book`→Lambda Function URL, API 캐시 비활성.
- WAF `wsc2026-waf`: SQLi/XSS managed rules와 1분 200회 rate limit.
- Observability: Prometheus, Alertmanager, node-exporter, Fluent Bit, Grafana. namespace `observability`, dashboard `wsc2026-grafana-dashboard`.

### 자동화 설계

Terraform은 AWS, Kubernetes, Helm provider를 단계적으로 사용한다. EKS 생성 전 Kubernetes/Helm provider가 평가되지 않도록 `task1/platform`과 `task1/addons`를 state로 분리하는 편이 안전하다. Docker build/push는 Terraform 밖의 CI 단계로 두고 digest를 변수로 전달한다. Lambda source와 CloudFront Function/WAF 규칙, Grafana dashboard는 버전 관리되는 파일로 둔다.

## 2과제: 네 개의 독립 모듈

### A. CDN (`us-east-1`)

- S3 `wsc2026-cdn-asset-<비번호>`, public 차단, versioning, OAC, `origin/` 이미지.
- CloudFront `wsc2026-cdn`, 모든 edge location, HTTPS redirect.
- custom cache policy `wsc2026-cache-policy`와 origin request policy `wsc2026-origin-policy`; query string 전달/캐시 키 포함.
- viewer-request Function `wsc2026-device-detect`: 기존 query가 없을 때 mobile `w=480&h=320&type=mobile`, desktop `w=1920&h=1080&type=desktop`.
- viewer-response Function `wsc2026-response-header`: `X-Device-Type`, `X-Resized: true`.
- Lambda@Edge `wsc2026-resize`(Python 3.12)는 **반드시 us-east-1**, publish된 version ARN을 origin-response에 연결. 리사이즈 결과는 `resized/`에 KST timestamp 이름으로 저장.

### B. Keycloak (`ap-northeast-2`)

- `wsc2026-keycloak-vpc` (`10.20.0.0/16`), public 2/private 1, NAT.
- private EC2 `wsc2026-keycloak` (`t3.medium`, AL2023), public IP/SSH 없이 SSM 접근.
- internet-facing ALB `wsc2026-keycloak-alb`, TG `wsc2026-keycloak-tg`.
- Realm `wsc2026-aws`, groups/users, AWS SAML client.
- IAM SAML provider `wsc2026-keycloak-idp`, dev/infra role과 최소권한 policy. infra는 `protected` tag EC2의 start/stop을 명시적으로 deny.
- Terraform AWS 리소스와 Keycloak provider 리소스를 분리한다. 초기 admin password 및 사용자 password는 Secrets Manager 또는 sensitive input으로만 주입한다.

### C. Container logging (`ap-northeast-1`)

- `wsc2026-logging-vpc` (`10.30.0.0/16`), public/private A/C.
- EKS `wsc2026-logging-cluster` 1.35, public endpoint, private AL2023 nodes 2개(`wsc2026-logging-nodegroup`).
- `wsc2026-app`의 `log-generator`와 LoadBalancer service.
- `wsc2026-logging`에 Helm으로 Fluent Bit, OTel Collector, Prometheus, Loki(single binary), Grafana.
- Fluent Bit은 Kubernetes metadata를 추가하고 logging namespace를 제외한 뒤 OTel HTTP로 전달.
- OTel은 JSON을 파싱하고 cluster attribute를 추가, Loki로 log 전송, count connector로 `log_record_count_total{level=...}` 노출.
- Grafana dashboard `wsc2026-app-logs` 및 Loki/Prometheus datasource를 declarative provisioning한다.

### D. Workflow (`ap-southeast-1`)

- versioned S3 `wsc2026-order-pipeline`, `incoming/sample-orders.json`.
- DynamoDB on-demand 3개: `wsc2026-orders`, `wsc2026-inventory`, `wsc2026-pipeline-history`(TTL `expires_at`).
- Python 3.13 Lambda `wsc2026-order-validator`, `wsc2026-payment-processor`.
- Standard state machine `wsc2026-order-pipeline`:
  - S3 SDK integration `FetchOrders` → JSON parse.
  - `ValidateOrders` Map, concurrency 5, Lambda retry 2회.
  - `ProcessAndStore` Map, concurrency 10; valid item만 결제→PutItem→재고 UpdateItem.
  - DynamoDB retry 3회, 기타 오류 catch.
  - 성공/실패 모두 history 테이블 기록, TTL은 실행 시점 +30일.
- ASL은 `templatefile()`과 `jsonencode()`로 생성하고 ARN을 보간한다.

## 권장 구조

```text
00003/
├── task1/{platform,addons,assets}
└── task2/{cdn,keycloak,logging,workflow}
```

공통 변수는 `candidate_id`, `aws_profile`, `allowed_cidrs`, `artifact_paths`, `image_digest`, `tags`; 출력은 API/CloudFront/ALB/Grafana URL과 cluster/table/bucket/function 이름을 포함한다.

## 주의 및 검증

- CMK policy에는 root 전체 권한이나 `kms:*`를 두지 말라는 원문 조건이 있다. key admin/user principal과 필요한 action을 명시한다.
- EKS `1.35`, Lambda/Edge runtime, Helm chart 호환성을 실행 시점 AWS에서 확인한다.
- Lambda@Edge는 versioned function만 연결 가능하고 배포 삭제 순서에 제약이 있다.
- CloudFront Function에서 viewer-response가 query string을 직접 보지 못할 수 있으므로 request header 전달 방식이 실제 런타임에서 유지되는지 통합 테스트한다.
- Keycloak의 mutable 내부 설정은 provider 버전을 고정하고, EC2 bootstrap 완료 후 provider를 적용한다.

검증은 `terraform fmt -check -recursive`, `terraform validate`, 각 root의 `plan` 후 AWS CLI/채점 스크립트, `kubectl`, HTTP 기능 테스트 순으로 수행한다.

## 구현 및 적용 순서

실제 코드는 다음처럼 서로 다른 state를 사용하는 root module로 구성되어 있다.

1. `task1/platform`을 적용하고 ECR에 애플리케이션 `v1.0.0` 이미지를 push한다.
2. private EKS API에 연결 가능한 환경에서 `task1/addons`를 `image=<repository>@<digest>`로 적용한다.
3. 2과제는 `task2/cdn`, `task2/logging/infra`, `task2/logging/addons`, `task2/workflow`를 독립적으로 적용한다.
4. Keycloak은 `task2/keycloak/infra`로 서버를 만든 뒤 `task2/keycloak/config`를 적용한다. Realm metadata를 받아 `infra`의 `saml_metadata_document`로 재적용하고, 생성된 role/provider ARN으로 `config`를 최종 재적용한다.

CDN의 Lambda@Edge 리사이징은 Pillow가 포함된 Python 3.12/us-east-1 layer ARN을 필수 변수 `pillow_layer_arn`에 전달해야 한다. `candidate_id`는 1과제와 CDN root 모두 필수 입력이다. 1과제는 platform → addons → addons의 `alb_hostname`을 platform의 `alb_domain_name`으로 전달해 재적용한다. EKS 1.35와 `IMMUTABLE_WITH_EXCLUSION`, Python 3.13은 적용 계정/리전에서 지원 여부를 먼저 확인해야 한다.

현재 작업 환경에는 `terraform`/`tofu` 바이너리가 없어 provider 다운로드, `fmt`, `init -backend=false`, `validate`는 실행하지 못했다. Python 소스와 JSON은 로컬 cache 경로를 `/tmp`로 지정하여 검사할 수 있다.
