# 00008 Terraform 자동화 분석

## 개요

이 안은 1과제가 ECS Fargate 기반 Book 서비스이며, 2과제는 DocumentDB, VPC Lattice, 보안 이벤트 복구, SQS 기반 EKS scaling의 네 독립 모듈이다. Terraform state는 다음처럼 분리한다.

```text
00008/
├── task1/
└── task2/
    ├── documentdb/
    ├── lattice/
    ├── cloud-event/
    └── sqs-eks/
```

## 1과제: ECS Fargate Book Service (`ap-northeast-2`)

### 요구사항

- VPC `skills-book-vpc`, DNS hostnames/resolution 활성화, public/private subnet 각각 2개 AZ 이상, DynamoDB VPC endpoint.
- S3 `skills-book-static-2026-<비번호>`, public 차단, CloudFront OAC만 허용.
- CloudFront `skills-book-cloudfront`: 기본 S3/index.html, `/v1/*`는 ALB, POST 허용, HTTPS 정책 권장.
- ALB origin custom header `X-Origin-Verify` 값은 20자 이상 sensitive variable.
- internet-facing ALB public subnet 2개 이상, HTTP/80, IP target/8080, `/health`; header 일치 시 forward, 기본 403.
- private ECR `skills-book-ecr`; 제공 Go binary를 포함한 image를 push.
- ECS cluster/service `skills-book-cluster`/`skills-book-service`, task family `skills-book-task`, container `skills-book-container`, desired 2, port 8080.
- execution role `skills-book-ecs-execution-role`, task role `skills-book-ecs-task-role`; 서로 분리하고 최소권한 적용.
- 환경 변수 `AWS_REGION=ap-northeast-2`, `TABLE_NAME=skills-book-booking`.
- DynamoDB `skills-book-booking`, PK `booking_id`, KMS alias `alias/skills-book-ddb`.
- Logs `/ecs/skills-book-app`, prefix `book`.
- metric filter `skills-book-4xx-filter`, `skills-book-5xx-filter`; namespace `Skills/CloudComputing/Task1`; metric/alarm 고정 이름, Sum/60초/1회/threshold 1/missing notBreaching.

### 자동화 경계

Terraform으로 전체 AWS 인프라와 S3 object를 관리한다. Docker build/push는 별도 CI 단계로 실행한 뒤 image digest를 task definition 변수로 전달한다. CloudFront header secret은 state에 남을 수 있으므로 encrypted remote backend를 사용하고 출력하지 않는다.

## 2과제: 독립 Small Challenges

### A. DocumentDB (`ap-northeast-2`)

- VPC/subnet에서 public client EC2와 private DocumentDB 통신 구성.
- EC2 `skills-nosql-client-ec2`, 제공 `docdb_client.py` 무수정, TCP/8080.
- DocumentDB cluster/instance `skills-nosql-docdb-cluster`/`skills-nosql-docdb-instance-1`, `db.t3.medium`, TLS, backup ≥1일.
- KMS alias `alias/skills-nosql-docdb`.
- Secrets Manager `skills-nosql-docdb-secret`, keys `username,password,host`; host는 scheme/port 없는 endpoint.
- DB `skills_retail`; orders/products/sessions 최소 8/6/3건, BSON Date 필드와 문제지의 unique/compound/TTL index를 정확히 생성.
- Terraform은 AWS 리소스까지 담당하고, MongoDB collection/index/seed는 EC2의 idempotent bootstrap 또는 `mongodbatlas`가 아닌 별도 provision 단계로 둔다. 비밀번호는 random_password + Secrets Manager를 사용한다.

### B. VPC Lattice (`ap-northeast-1`)

- client VPC `skills-lattice-client-vpc` `10.61.0.0/16`, service VPC `skills-lattice-service-vpc` `10.62.0.0/16`; peering/TGW 금지.
- EC2 `skills-lattice-client-ec2` public TCP/80, `SERVICE_URL`은 Lattice generated domain.
- service EC2 `skills-lattice-service-ec2` private TCP/8080; ingress는 Lattice managed prefix list만.
- service network `skills-lattice-sn`; client VPC association SG는 client CIDR의 TCP/80 허용.
- service `skills-lattice-order-service`, target group `skills-lattice-order-tg`(instance, HTTP/8080, `/health`), listener `skills-lattice-http-listener`(HTTP/80).
- 제공 `client_app.py`, `service_app.py`를 user_data 또는 image로 무수정 배포하고 API 응답을 통합 테스트한다.

### C. Cloud Event Handling (`ap-southeast-1`)

- VPC `skills-ceh-vpc` `10.73.0.0/16`, EC2 `skills-ceh-ec2`, SG `skills-ceh-protected-sg`; 최종 ingress 0개.
- SNS Standard topic `skills-ceh-alert-topic`.
- Lambda `skills-ceh-remediate-fn`, Python 3.12, handler `remediate_security_group.lambda_handler`, timeout ≥30초.
- 환경 변수에 protected SG ID와 SNS ARN, 최소 EC2/SNS/Logs 권한.
- CloudTrail `skills-ceh-cloudtrail` logging 활성화.
- default bus EventBridge `skills-ceh-sg-change-rule`이 CloudTrail의 `AuthorizeSecurityGroupIngress`를 감지해 Lambda 호출.
- Lambda resource policy, log group `/aws/lambda/skills-ceh-remediate-fn` 포함. 테스트 ingress는 180초 이내 제거되어야 한다.

### D. SQS + EKS scaling (`us-west-2`)

- EKS `skills-sqs-cluster`; CloudShell에서 public/API allowlist 조건으로 접근 가능.
- Fargate profiles `skills-sqs-fp-keda`(namespace `keda`), `skills-sqs-fp-karpenter`(`karpenter`).
- Standard SQS `skills-sqs-queue`, visibility timeout ≥30초.
- IRSA annotation이 있는 `keda-operator`, `karpenter`, `sqs-worker-sa`.
- namespace/deployment `skills-sqs`/`sqs-worker`, app label, 제공 `worker.py`, SQS 환경 변수.
- worker node selector: `karpenter.sh/nodepool=skills-sqs-nodepool`, `skills-nodepool=event-worker`; Fargate가 아닌 Karpenter EC2에 배치.
- KEDA `sqs-worker-scaledobject`, auth `sqs-worker-trigger-auth`; queueLength 2, min 0, max 6, polling ≤15초, cooldown ≤30초.
- Karpenter NodePool/Class `skills-sqs-nodepool`/`skills-sqs-nodeclass`, consolidation policy 포함.
- Terraform AWS/EKS 단계 후 Helm/Kubernetes 단계를 별도 state로 적용한다. Karpenter CRD가 생긴 뒤 manifest를 적용해야 한다.

## 변수, 출력, 검증

공통 입력은 `aws_profile`, `candidate_id`, `availability_zones`, `allowed_cidr`, `artifact_paths`, `image_digest`, `tags`. 출력은 CloudFront/ALB/client EC2 URL, DocumentDB endpoint(비밀 제외), Lattice domain, EKS name, SQS URL, 채점용 resource IDs를 제공한다.

주의사항:

- DocumentDB 데이터/index는 Terraform apply 완료와 서비스 ready 사이의 순서를 명시적으로 제어한다.
- Lattice SG는 managed prefix list ID를 data source로 조회하며 `0.0.0.0/0`을 허용하지 않는다.
- EKS/Fargate/Karpenter 조합에서 CoreDNS 및 controller scheduling, subnet tag, Pod Identity/IRSA trust를 먼저 검증한다.
- CloudFront/ECS/CloudWatch는 반영 지연이 있으므로 apply 직후가 아닌 안정화 후 채점한다.
- 사용자 제공 과제지의 버전/런타임이 실제 AWS 지원 범위와 다르면 변수화하되, 자동 채점이 직접 비교하는 값은 원문을 우선한다.

기본 정적 검증:

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
```

배포 후에는 원본 `asgmt*_check.sh`와 같은 AWS CLI 조회를 먼저 실행하고, HTTP 200/403, DocumentDB 데이터·index, SG 자동 복구, SQS 12건 발행 시 KEDA Pod 및 Karpenter node 증가를 기능 검증한다.

## 구현된 root module과 적용 순서

- `task1`: VPC/NAT/DynamoDB endpoint, S3/OAC/CloudFront, header-protected ALB, ECR/ECS Fargate, KMS DynamoDB, 로그 metric filter/alarm을 한 state에서 관리한다. 먼저 `terraform apply -target=aws_ecr_repository.book` 후 `build-and-push.sh`로 제공 Go binary 이미지를 올리고 전체 apply를 수행한다. 필수 변수는 `candidate_id`, 20자 이상의 sensitive `origin_verify_secret`이다.
- `task2/documentdb`: AWS 인프라와 제공 파일을 함께 관리한다. EC2 user-data가 제공 `docdb_client.py`를 수정 없이 설치하고, BSON Date 변환/seed 및 문제지의 unique/compound/TTL index를 멱등 생성한다.
- `task2/lattice`: 두 VPC 사이 peering/TGW 없이 Lattice만 사용한다. 두 제공 Python 파일은 base64 user-data로 원문 그대로 배치된다.
- `task2/cloud-event`: 기본 ingress 0개인 보호 SG, 제공 Lambda, SNS, default EventBridge rule, logging CloudTrail을 구성한다.
- `task2/sqs-eks/infra`: EKS/Fargate/SQS/ECR/OIDC/IRSA/Karpenter node role을 생성한다.
- `task2/sqs-eks/addons/controllers`: CoreDNS의 Fargate annotation을 설정하고 KEDA/Karpenter controller를 설치한다.
- `task2/sqs-eks/addons/workloads`: CRD 설치 후 적용하며 Worker, ScaledObject/TriggerAuthentication, NodePool/EC2NodeClass를 생성한다. `infra` 적용 후 worker ECR만 target 생성하고 `build-and-push.sh`를 실행한 다음 controllers, workloads 순서로 적용한다.

로컬 state를 사용할 때 SQS/EKS 하위 root의 상대경로 연결을 유지하려면 각 디렉터리에서 Terraform을 실행한다. 운영 적용 시에는 `terraform_remote_state`의 local backend를 조직의 암호화된 remote backend로 바꾼다. DocumentDB master password와 CloudFront origin secret은 state에 들어가므로 remote state 암호화 및 접근통제가 필수다.

현재 제공 작업 환경에는 `terraform`/`tofu` 바이너리가 없으므로 `fmt`, provider 다운로드, `init -backend=false`, `validate`는 실행할 수 없었다. Python 제공/구현 파일, JSON, shell 구문은 별도 정적 검사 대상으로 포함했다. 실제 apply 전에는 EKS 1.35, Karpenter/KEDA chart 버전과 AWS provider 6.x 스키마를 대상 계정에서 확인한다.
