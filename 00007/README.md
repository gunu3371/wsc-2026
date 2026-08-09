# 00007 Terraform 자동화 분석

## 개요

원본은 1과제 대형 EKS 티켓 플랫폼과 2과제의 독립 모듈 4개로 구성된다. Terraform root/state는 `task1`, `task2/nosql`, `task2/cdn`, `task2/scaling`, `task2/o11y`로 분리한다.

## 1과제: Unicorn Tickets (`ap-northeast-2`)

### 네트워크와 보안

- `unicorn-vpc` `10.97.0.0/16`, 3개 AZ(a/b/c).
- public `10.97.0/1/2.0/24`, private `10.97.10/11/12.0/24`; IGW, AZ별 NAT/route table.
- VPC Flow Logs 활성화. 앱의 image pull 및 log/metric export는 인터넷을 경유하지 않도록 ECR API/DKR, S3, Logs, STS 등 VPC endpoint를 설계한다.
- private subnet에 CloudShell VPC environment `unicorn-mark`; 모든 채점 대상 접근 가능.
- KMS alias `unicorn-kms-app`, `unicorn-kms-data`, `unicorn-kms-platform`; 90일 rotation. platform key는 WAF log 암호화를 위해 `us-east-1` multi-region 구성도 필요하다.

### 데이터와 컨테이너

- S3 `unicorn-web-<ACCOUNT_ID>`, public 차단, versioning, data CMK.
- DynamoDB `unicorn-concert-db`: PK `booking_id`, GSI `client-id-created-at-index`(`client_id`, `created_at`, ALL), on-demand, PITR, deletion protection, app CMK.
- ECR `unicorn-concert-app`, image `v1.0.0`와 `latest`, scan 및 data CMK.
- EKS `unicorn-eks-cluster` 1.35, fully private, all logs, secret/EBS/log platform CMK, KST node timezone.
- App node label `unicorn=app`(2대 이상, AZ 분산), addon label `unicorn=addon`(1대 이상).
- namespace `unicorn`; `unicorn-book-app-deploy`, `unicorn-book-app-svc`, container `book`; probe, preStop, graceful termination.
- EKS Access Entry만 사용하고 `aws-auth` 방식은 제외. Pod Identity trust를 cluster로 한정.

### API, edge, 관측성

- Lambda `unicorn-get-booking-func`, log group `/unicorn/lambda/get-booking`; 필수 `booking_id`와 선택 filter로 조회.
- internal ALB `unicorn-alb`, TG `unicorn-tg`; GET→Lambda, POST와 `/health`→EKS.
- CloudFront `unicorn-svc-cf`: S3 OAC와 internal ALB VPC Origin.
- us-east-1 WAF `unicorn-waf`: Common/KnownBadInputs, `unicorn-rate-limit` 60초 50회, custom 403 body, encrypted WAF log.
- IAM `unicorn-audit-role`: external ID `unicorn-audit-2026<등번호>`, max session 1h, DynamoDB 조회 및 VPC/EKS describe만 허용.
- Fluent Bit → `/unicorn/eks/book-app`, `/health` 제외, 10초 이내 전달.
- `monitoring` namespace의 Prometheus/Grafana, 외부 Grafana ALB, dashboard `unicorn-grafana-dashboard`.

## 2과제

### A. NoSQL (`ap-southeast-1`)

- DynamoDB `bigbae-nosql-reservation-table`: PK/SK `train_id`/`seat_id`, stream `NEW_AND_OLD_IMAGES`, PITR, on-demand.
- sparse GSI `gsi-user-reservations`: `user_id`/`reserved_at`, projection ALL.
- audit table `bigbae-nosql-audit-table`, PK `event_id`.
- Python 3.13 Lambda `bigbae-nosql-reservation-audit`, stream trigger, timeout 30s.
- public EC2 `bigbae-nosql-app-ec2`, Flask TCP/8080, 제공 `app.py` 무수정.
- Terraform은 테이블·trigger·IAM·EC2/user_data를 담당한다. 초기 좌석 데이터가 필요하면 별도 seed asset과 idempotent bootstrap으로 둔다.

### B. CDN Function A/B test (`us-east-1`)

- S3 `skillsphone-landing-ab-<12자리_ACCOUNT_ID>`, OAC 전용; version-a/b object.
- CloudFront KeyValueStore `skillsphone-cdn-ab-config`: `weight=0.3`, version 경로 2개.
- Functions `skillsphone-cdn-ab-req-fn`, `skillsphone-cdn-ab-res-fn`, runtime `cloudfront-js-2.0`, LIVE.
- request function은 cookie 유지 또는 무작위 배정 후 URI/header 재작성; response function은 1일 `Set-Cookie`.
- custom cache policy `skillsphone-cdn-ab-cache-policy`, TTL 0/300/3600, `x-sp-ab` cookie 포함; managed policy 금지.
- Distribution `skillsphone-cdn-ab-distribution`, HTTPS redirect 및 두 function association.

### C. EKS Scaling (`ap-northeast-2`)

- SQS Standard `skm-order-queue`.
- EKS `skm-eks-cluster` 1.35; addon NG `skm-cluster-addon-ng` 1/1/1 `t3.medium`, taint 적용.
- `skillsmkt`의 `order-processor`, initial 1, request 500m/512Mi, Pod Identity/IRSA로 SQS consume/delete.
- KEDA `order-scaler`: min/max 1/5, queue target 5.
- Karpenter는 kube-system; NodePool/Class `skm-app-nodepool`/`skm-app-nodeclass`, `t3.small|t3.medium`, 60초 consolidation.
- 앱 node selector/toleration을 고정해 addon node에 배치되지 않게 한다. 부하 종료 후 Pod 1/Node 1 상태 검증.

### D. Container logging (`ap-northeast-1`)

- EKS `o11y-cluster` 1.35, multi-AZ nodes `t3.medium`, 2/2/2, KST.
- `o11y` namespace의 `log-generator` replicas 2, ALB/TG `o11y-app-alb`/`o11y-app-tg`.
- `monitoring`의 OTel DaemonSet `o11y-otel`: `/var/log/pods/*/*/*.log`, k8sattributes, OTLP HTTP.
- Loki `o11y-loki` single binary + persistent chunks/index + OTLP ingestion.
- Grafana deployment `o11y-grafana`, ALB/TG 및 Loki datasource, `Log Overview` dashboard.

## 구현 구조와 자동화 경계

```text
00007/
├── task1/{foundation,cluster,addons,assets}
└── task2/{nosql,cdn,scaling,o11y}
```

- AWS provider alias로 `ap-northeast-2`, `ap-northeast-1`, `ap-southeast-1`, `us-east-1`을 명시한다.
- EKS 기반 root는 foundation/cluster와 Helm/Kubernetes addon 적용을 분리한다.
- 컨테이너 빌드·push는 CI/Makefile, Terraform에는 immutable digest만 전달한다.
- dashboard, Helm values, CloudFront JS, Lambda source, user-data를 별도 파일로 관리한다.
- password는 sensitive variable/Secrets Manager로 주입하고 README의 예시 값을 state 외부에서 관리한다.

## 위험 요소와 검증

- CloudFront VPC Origin 지원 대상/리전과 internal ALB 조건을 실제 계정에서 선확인한다.
- WAF log group 이름 prefix와 us-east-1 KMS policy의 Logs service principal 조건을 맞춘다.
- 문제지의 KMS 90일 rotation 요구는 AWS KMS/Terraform provider가 지원하는 rotation period 속성을 사용하는 버전으로 고정한다.
- EKS 1.35 및 AL2023 node AMI 지원 여부를 배포 시점에 확인한다.
- CloudFront KVS/Function은 provider 최신 schema가 필요하므로 provider version을 고정한다.

`terraform fmt -check -recursive` → `init` → `validate` → root별 `plan`을 수행하고, 배포 뒤 고정 name/tag/region, IAM 최소권한, 암호화, Kubernetes 배치, API 및 scaling/log pipeline을 채점 스크립트와 동일한 관점에서 검증한다.

## 구현 및 적용 순서

모든 디렉터리는 독립 Terraform state를 사용한다. 1과제는 private-only EKS API 요구 때문에 `addons` 단계는 `unicorn-vpc`에 연결된 CloudShell/VPN 실행 환경에서 적용해야 한다.

```bash
terraform -chdir=task1/foundation init && terraform -chdir=task1/foundation apply
terraform -chdir=task1/cluster init && terraform -chdir=task1/cluster apply
terraform -chdir=task1/addons init && terraform -chdir=task1/addons apply \
  -var='app_image=ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/unicorn-concert-app@sha256:DIGEST' \
  -var='audit_principal_arn=arn:aws:iam::ACCOUNT:root' -var='competitor_number=00007'

terraform -chdir=task2/nosql init && terraform -chdir=task2/nosql apply
terraform -chdir=task2/cdn init && terraform -chdir=task2/cdn apply
terraform -chdir=task2/scaling init && terraform -chdir=task2/scaling apply \
  -var='order_processor_image=ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/order-processor@sha256:DIGEST'
terraform -chdir=task2/o11y init && terraform -chdir=task2/o11y apply \
  -var='log_generator_image=ACCOUNT.dkr.ecr.ap-northeast-1.amazonaws.com/log-generator@sha256:DIGEST'
```

`task1/addons/assets`, `task2/scaling/assets`, `task2/o11y/assets`의 Dockerfile로 이미지를 빌드해 각 리전 ECR에 먼저 push한다. digest URI를 변수로 받도록 하여 태그 변경으로 인한 비결정적 재배포를 막았다. CDN HTML/Functions, Lambda, user-data, Loki/OTel/Grafana provisioning 파일은 각 root의 `assets`에 포함돼 있다.

루트의 기존 `task1/main.tf`는 한 번에 구성하는 호환용 구현이며, 신규 배포에는 충돌 방지를 위해 위의 `foundation` → `cluster` → `addons` 세 root만 사용한다. 두 방식을 같은 계정에서 함께 적용하면 안 된다.
