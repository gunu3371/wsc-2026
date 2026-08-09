# 00002 Terraform 자동화 분석

## 목표

`37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002`의 1·2과제를 Terraform으로 재현하기 위한 구현 명세다. 문제지와 채점 스크립트의 **리전, 이름, 태그, 런타임, 네트워크 경로**가 채점 기준이므로 임의 변경하지 않는다.

## 권장 저장소 구조

```text
00002/
├── README.md
├── task1/                 # Web Service Provisioning
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── modules/
│   ├── assets/
│   └── kubernetes/
└── task2/                 # 4개의 독립 Small Challenge
    ├── workflow/
    ├── analytics/
    ├── cloud-event/
    └── msk/
```

과제별 state를 분리한다. 특히 2과제의 네 모듈은 리전과 생명주기가 다르므로 디렉터리 및 backend key를 반드시 분리한다.

## 1과제: Web Service Provisioning

기본 리전은 `ap-northeast-2`다.

### 구축 범위

1. 네트워크
   - VPC `wskorea26-vpc`, CIDR `172.16.0.0/16`.
   - Public C/D: `172.16.1.0/24`, `172.16.2.0/24`.
   - Private C/D: `172.16.201.0/24`, `172.16.202.0/24`.
   - IGW 1개, AZ별 NAT Gateway와 private route table.
   - 채점 접근용 `wskorea26-vpc-environment-sg`.
2. 정적 웹
   - S3 `wskorea26-concert-bucket-<비번호>`, 객체 경로 `/web/main/`.
   - KMS alias `wskorea26-s3-key`, public access 차단, CloudFront OAC 전용 정책.
   - `index.html`, `main.jpeg` 업로드.
3. 애플리케이션/레지스트리
   - 제공 `book` 바이너리를 컨테이너화.
   - ECR `wskorea26-book-repo`, 태그 `stable`, 암호화 및 이미지 스캔.
4. 데이터
   - DynamoDB `wskorea26-data-table`, PK `client_id`(String).
   - KMS alias `wskorea26-dynamodb-key`, 삭제 방지.
5. EKS
   - Private cluster `wskorea26-cluster`, 명시 버전 `1.35`.
   - 모든 control-plane log와 secrets KMS 암호화(`wskorea26-eks-key`).
   - `wskorea26-addon-ng`와 `wskorea26-app-ng`, 각 `t3.medium`, 라벨 `node-type=addon|app`.
   - 애플리케이션 namespace `wskorea26`; addon과 workload를 affinity/taint로 분리.
6. Lambda/API
   - `wskorea26-book-lambda`, 문제지 명시 런타임 Python `3.14`.
   - `concert_name`으로 DynamoDB를 최신순 조회하고 ALB 응답 형식으로 반환.
   - 파라미터 누락은 400, 결과 없음은 `[]`/200, `created_at`은 KST.
7. ALB/CloudFront
   - ALB `wskorea26-book-alb`, internet-facing HTTP/80.
   - `/book` 요청을 EKS와 Lambda 대상으로 라우팅.
   - 직접 ALB 요청은 403; CloudFront가 `X-Origin-Verify: wskorea26-cf` 전달.
   - CloudFront `wskorea26-concert-cf`; S3 기본 origin, ALB behavior 분리, HTTP→HTTPS.
8. 관측성
   - 클러스터 metric 및 Pod log를 수집하고 Grafana ALB 제공.
   - dashboard `wskorea26-monitoring`; CPU, memory, running Pod, restart, network 수신량 패널.

### Terraform 경계

- Terraform: VPC, KMS, S3, DynamoDB, ECR, EKS, IAM, ALB, CloudFront, 로그 그룹, Kubernetes/Helm 리소스.
- 빌드 단계: Docker image build/push. `terraform_data` + `local-exec`보다 `Makefile`/CI 선행 단계가 재현성과 오류 처리가 좋다.
- 런타임 코드: Lambda zip은 `archive_file`, 정적 파일은 `aws_s3_object`로 배포 가능하다.
- Grafana dashboard는 JSON을 파일로 보관하고 Helm values/config map으로 선언한다.

## 2과제: Small Challenge

네 모듈은 서로 리소스를 공유하지 않는다.

### A. Workflow (`ap-southeast-1`)

- S3 `wsc2026-student-score-bucket-<비번호>`와 `/input`, `/processed`, `/error` prefix.
- DynamoDB `wsc2026-student-score`, PK `studentId`, SK `examDate`.
- Lambda가 CSV를 읽어 평균/등급을 계산.
- Standard Step Functions `wsc2026-student-score-workflow`.
- 역할: `wsc2026-lambda-student-role`, `wsc2026-stepfunction-student-role`.
- 채점 전 `test.csv`만 `/input`에 두고 processed/error 및 테이블은 비운다.

### B. Real-time analytics (`ap-northeast-2`)

- `analytics-vpc` (`10.20.0.0/16`), public/private 각 2개, private EC2와 public ALB.
- EC2 `wsc2026-analytics-ec2` (`t3.small`, SSM 가능), ALB/TG 고정 이름.
- Kinesis Data Stream `wsc2026-order-stream`, on-demand.
- Managed Service for Apache Flink Studio Notebook `wsc2026-analytics-flink`, Flink `1.19`.
- Notebook SQL로 최근 1분 주문 수와 상품별 누적 매출을 조회.

### C. Cloud event handling (`eu-west-1`)

- `event-vpc`와 public subnet 2개, 대상 EC2 `wsc2026-event-ec2`, SG `wsc2026-event-sg`.
- CloudTrail `wsc2026-event-trail`로 management read/write event 수집.
- EventBridge 규칙 4개: SG ingress 추가, instance profile 변경, 종료, instance type 변경.
- Lambda가 정책 위반을 복구하고 SNS `wsc2026-event-alert`에 알림.
- 이벤트 패턴, Lambda permission, DLQ/재시도, CloudWatch log group까지 코드화한다.

### D. MSK (`ap-northeast-1`)

- `msk-vpc` (`192.168.0.0/16`), public/private A/D, private MSK 및 producer.
- MSK `wsc2026-msk-cluster`, Kafka `3.6.0`, `kafka.t3.small`, IAM 인증 전용.
- topic `wsc2026-sensor-raw`(3 partitions/RF 2), `wsc2026-sensor-alert`(1/RF 2).
- producer EC2 `wsc2026-sensor-producer`; Lambda consumer 2개.
- DynamoDB `wsc2026-sensor-data`와 오류 S3 `wsc2026-sensor-alert-bucket-<비번호>`.
- Kafka topic 생성은 Terraform Kafka provider가 MSK 네트워크에 접근할 수 있어야 한다. 그렇지 않으면 SSM을 통한 별도 bootstrap 단계로 분리한다.

## 공통 변수와 출력

필수 변수: `aws_profile`, `candidate_id`, `allowed_cidr`, `availability_zones`, `artifact_paths`, `tags`. 비밀번호와 토큰은 `sensitive = true`로 선언하고 저장소에 값을 커밋하지 않는다.

필수 출력: CloudFront URL, ALB URL, EKS cluster name, 각 API endpoint, S3 bucket, DynamoDB table, MSK bootstrap broker, 채점에 필요한 resource ARN/ID.

## 구현 전 확인사항

- 문제지의 EKS `1.35`와 Python `3.14`가 실제 AWS에서 지원되는지 배포 시점에 확인하고 변수화한다. 채점이 버전을 직접 비교한다면 원문 값을 우선한다.
- ECR 취약점 0건은 Terraform만으로 보장할 수 없다. CI에서 scan 결과를 확인한 뒤 배포한다.
- CloudFront 전용 ALB 접근은 secret header + default 403으로 구현하되 secret은 sensitive variable로 둔다.
- destroy 전 `prevent_destroy`가 설정된 DynamoDB/KMS와 ECR/S3 내용물을 별도 정리해야 한다.

## 검증 순서

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
```

배포 후 AWS CLI로 고정 이름·리전·암호화·정책을 확인하고, `kubectl`로 노드 라벨과 workload 배치를 검증한 다음 HTTP API, Step Functions 실행, 이벤트 복구, MSK consumer를 각각 기능 테스트한다.

## 구현 및 적용

이 디렉터리에는 위 명세의 실제 root module과 런타임 파일이 구현되어 있다. 각 디렉터리가 별도 state 경계다.

```bash
cd task1
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
./push-image.sh

# VPC 내부 관리 호스트에서 별도 platform state 적용
cd platform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

cd ../../task2/workflow    # analytics, cloud-event, msk도 각각 별도 실행
cp terraform.tfvars.example terraform.tfvars 2>/dev/null || true
terraform init && terraform apply
```

- `task1`의 EKS API는 문제 요구대로 private endpoint다. AWS 기반시설은 `task1`, Kubernetes/Helm은 `task1/platform`의 별도 state이며 후자는 VPC 안의 관리 호스트나 VPN/Direct Connect 환경에서 실행해야 한다.
- `task1/push-image.sh`는 ECR 생성 후 제공 `book` 바이너리를 `stable` 태그로 빌드·푸시한다. 푸시 후 `book_image_uri`에 출력된 URI를 지정해 workload를 갱신한다.
- `task2/msk`에는 제공된 module4 바이너리를 `assets/app`으로 포함했다. 부팅 스크립트가 IAM 인증 Kafka CLI로 두 토픽과 systemd 서비스를 구성한다.
- Workflow의 샘플 CSV는 최초 apply 때 업로드되어 실행을 유발한다. 재채점 전에는 DynamoDB와 `processed/`, `error/`를 비우고 `input/test.csv`를 다시 올린다.

현재 작업 환경에는 Terraform 실행 파일이 없어 `fmt/init/validate`를 실제 수행할 수 없었다. 대신 모든 Python 파일 문법 검사, dashboard JSON 검사, user-data 셸 문법 검사, Terraform 선언/참조 정적 검사를 수행했다.
