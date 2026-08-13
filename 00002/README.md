# 00002 Terraform 구현

`37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002`의 1·2과제를 Terraform으로 구현한 디렉터리다. 문제지와 채점 스크립트에 명시된 리전, 리소스 이름, CIDR, 런타임 및 네트워크 경로를 기준으로 구성한다.

## Terraform 파일 구성 방식

각 root module의 리소스를 과제 단계별 `.tf` 파일로 분리했다. Terraform은 현재 디렉터리의 모든 `.tf` 파일을 한 모듈로 함께 읽으므로 단계 파일을 개별 실행하지 않는다. 해당 디렉터리에서 한 번의 `terraform plan` 또는 `terraform apply`로 전체 단계를 적용한다.

각 디렉터리는 독립적인 state를 사용한다.

```text
00002/
├── task1/                       # 1과제 AWS 기반시설
│   ├── 00-common.tf
│   ├── 01-network.tf
│   ├── 02-static-storage.tf
│   ├── 03-container-registry.tf
│   ├── 04-database.tf
│   ├── 05-eks.tf
│   ├── 06-lambda.tf
│   ├── 07-application-load-balancer.tf
│   ├── 08-cloudfront.tf
│   ├── 09-application-api.tf
│   ├── 10-monitoring.tf
│   └── platform/                # EKS 내부 Kubernetes/Helm 리소스
│       ├── 01-application.tf
│       └── 02-monitoring.tf
└── task2/
    ├── workflow/                # ap-southeast-1
    ├── analytics/               # ap-northeast-2
    ├── cloud-event/             # eu-west-1
    └── msk/                     # ap-northeast-1
```

`versions.tf`, `variables.tf`, `outputs.tf`는 각 모듈의 공급자·입력·출력을 선언한다. 런타임 코드는 `lambda/`, 배포 자료는 `assets/`, EC2 초기화 스크립트는 `user_data.sh.tftpl`에 있다.

## 1과제: Web Service Provisioning

기본 리전은 `ap-northeast-2`다.

| 단계 | 파일 | 구현 내용 |
|---|---|---|
| 공통 | `00-common.tf` | 계정·가용 영역 data source와 공통 local 값 |
| 1 | `01-network.tf` | `172.16.0.0/16` VPC, public/private subnet, IGW, AZ별 NAT와 route table, 환경 SG |
| 2 | `02-static-storage.tf` | KMS 암호화 S3, public access 차단, `web/main/` 정적 객체, CloudFront 복호화 정책 |
| 3 | `03-container-registry.tf` | 스캔과 암호화를 적용한 `wskorea26-book-repo` ECR |
| 4 | `04-database.tf` | KMS 암호화 및 삭제 방지를 적용한 `wskorea26-data-table` DynamoDB |
| 5 | `05-eks.tf` | private EKS, control-plane log, secrets KMS, addon/app node group와 taint·label |
| 6 | `06-lambda.tf` | DynamoDB를 사용하는 `wskorea26-book-lambda`와 IAM |
| 7 | `07-application-load-balancer.tf` | `/book` Lambda target, 검증 header 규칙, 기본 403 응답 ALB |
| 8 | `08-cloudfront.tf` | S3 OAC 기본 origin, `/book*` ALB behavior, HTTP→HTTPS |
| 9 | `09-application-api.tf` | POST/GET 기능시험 단계 설명. 인프라는 4·6·7·8단계에서 선언 |
| 10 | `10-monitoring.tf` | Grafana ALB, target group, EKS NodePort 접근 규칙 |

EKS API endpoint는 private이다. 따라서 다음 리소스는 별도 state인 `task1/platform`에서 VPC 내부 관리 호스트 또는 연결된 네트워크를 통해 적용한다.

- `01-application.tf`: `wskorea26` namespace, book Deployment와 Service
- `02-monitoring.tf`: kube-prometheus-stack, Grafana와 `wskorea26-monitoring` dashboard

### 1과제 적용 순서

```bash
cd 00002/task1
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# ECR 생성 후 book:stable 이미지 빌드 및 푸시
./push-image.sh

# VPC 내부 관리 환경에서 실행
cd platform
cp terraform.tfvars.example terraform.tfvars
# book_image_uri를 실제 ECR URI로 변경
terraform init
terraform validate
terraform apply -var-file=terraform.tfvars
```

## 2과제: Small Challenge

네 모듈은 리전과 생명주기가 다르며 서로 state를 공유하지 않는다.

### A. Workflow (`task2/workflow`, `ap-southeast-1`)

| 단계 | 파일 | 구현 내용 |
|---|---|---|
| 1 | `01-storage.tf` | S3의 `input/`, `processed/`, `error/`와 DynamoDB 복합 키 |
| 2 | `02-lambda.tf` | CSV 처리·S3 트리거 Lambda와 IAM |
| 3 | `03-step-functions.tf` | Standard Step Functions와 처리 성공/실패 분기 |
| 4 | `04-s3-trigger.tf` | S3 notification과 과제 원본 `input/test.csv` 업로드 |

최초 apply 시 원본 CSV가 업로드되어 workflow가 자동 실행된다. 재시험 전에는 DynamoDB 및 `processed/`, `error/`를 정리하고 `input/test.csv`를 다시 업로드한다.

### B. Analytics (`task2/analytics`, `ap-northeast-2`)

| 단계 | 파일 | 구현 내용 |
|---|---|---|
| 1 | `01-network.tf` | `10.20.0.0/16` VPC, public/private subnet, NAT와 SG |
| 2 | `02-kinesis.tf` | on-demand `wsc2026-order-stream` |
| 3 | `03-application-ec2.tf` | private EC2, SSM, Kinesis 권한, Flask/Gunicorn systemd 서비스 |
| 4 | `04-load-balancer.tf` | public ALB, target group와 `/health` 검사 |
| 5 | `05-flink.tf` | Managed Flink Studio Interactive 애플리케이션과 실행 역할 (`ZEPPELIN-FLINK-3_0`) |

Analytics는 필수 사용자 변수가 없다. 필요하면 `aws_profile`, `allowed_cidr`, `availability_zones`, `tags`를 CLI 또는 별도 `terraform.tfvars`로 지정한다.

AWS는 `INTERACTIVE` 애플리케이션에 `FLINK-1_19`를 허용하지 않는다. Studio Notebook을 실제 생성할 수 있도록 Zeppelin 계열 런타임인 `ZEPPELIN-FLINK-3_0`을 사용하며, 기본 Glue Data Catalog 데이터베이스도 함께 생성한다.

### C. Cloud Event (`task2/cloud-event`, `eu-west-1`)

| 단계 | 파일 | 구현 내용 |
|---|---|---|
| 공통 | `00-common.tf` | 계정 data source와 audit bucket suffix |
| 1 | `01-network-ec2.tf` | `event-vpc`, public EC2, 대상 SG와 instance profile |
| 2 | `02-alerting-audit.tf` | SNS, audit S3와 management event CloudTrail |
| 3 | `03-lambda.tf` | 정책 위반 복구·알림 Lambda와 IAM |
| 4 | `04-eventbridge.tf` | EC2·CloudTrail·Config 이벤트 규칙, target와 호출 권한 |
| 5 | `05-config.tf` | AWS Config recorder, delivery channel와 관리형 규칙 |

Cloud Event도 필수 사용자 변수가 없다. 기본값을 바꿀 때만 `aws_profile`, `availability_zones`, `tags`를 지정한다.

### D. MSK (`task2/msk`, `ap-northeast-1`)

| 단계 | 파일 | 구현 내용 |
|---|---|---|
| 공통 | `00-common.tf` | 계정 data source, CIDR·AZ·bucket local 값 |
| 1 | `01-network.tf` | `192.168.0.0/16` VPC, public/private subnet, NAT와 SG |
| 2 | `02-msk-cluster.tf` | Kafka 3.6.0, `kafka.t3.small`, IAM 인증 MSK와 broker log |
| 3 | `03-destinations.tf` | 센서 DynamoDB, alert S3, producer 바이너리와 SNS |
| 4 | `04-producer.tf` | private producer EC2, IAM, topic 생성과 systemd 실행. 제공 바이너리 출력을 IAM/TLS Kafka CLI로 전달하는 래퍼 포함 |
| 5 | `05-consumers.tf` | raw/alert Lambda consumer와 MSK event source mapping |

Producer user data가 IAM 인증 Kafka CLI로 다음 토픽을 만든다.

- `wsc2026-sensor-raw`: partition 3, replication factor 2
- `wsc2026-sensor-alert`: partition 1, replication factor 2

### 2과제 적용

각 디렉터리에서 독립적으로 실행한다.

```bash
cd 00002/task2/workflow
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform apply -var-file=terraform.tfvars

cd ../analytics
terraform init
terraform validate
terraform apply

cd ../cloud-event
terraform init
terraform validate
terraform apply

cd ../msk
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform apply -var-file=terraform.tfvars
```

## 입력값 관리

- `candidate_id`: 비번호. S3 bucket 이름에 사용되므로 실제 비번호로 변경한다.
- `aws_profile`: AWS CLI profile을 사용할 때만 지정한다.
- `allowed_cidr`: 외부에서 ALB 또는 환경 SG에 접근할 CIDR이다.
- `availability_zones`: 문제지에서 요구한 AZ를 변경해야 할 때만 지정한다.
- `book_image_uri`: ECR에 푸시한 `wskorea26-book-repo:stable` URI다.
- `producer_binary_path`: MSK producer 바이너리 경로이며 기본 예시는 `./assets/app`이다.

실제 `terraform.tfvars`, state, plan, ZIP 산출물과 비밀번호는 저장소에 커밋하지 않는다.

## 검증

모든 root module에서 다음 검사를 수행한다.

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan
```

배포 후에는 함께 제공된 채점 스크립트로 고정 리소스 이름, 리전, 암호화, runtime과 기능 동작을 확인한다. 추가로 다음 항목을 직접 점검한다.

- CloudFront 정적 페이지와 `/book` POST/GET
- EKS node의 `node-type` label과 Pod 배치
- Workflow 실행 후 DynamoDB 5건 및 오류 JSON 4건
- Analytics `/health`, `/order`와 systemd 활성 상태
- Cloud Event의 EC2·SG 자동 복구와 SNS 알림
- MSK producer 실행, event source mapping 및 DynamoDB/S3 결과

Terraform 1.15.8에서 여섯 개 root module 모두 `terraform init`과 `terraform validate`를 통과했으며, 전체 `.tf` 파일에 `terraform fmt`를 적용했다.
