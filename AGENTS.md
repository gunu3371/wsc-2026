# 클라우드컴퓨팅 과제 Terraform 작업 지침

이 파일은 저장소 루트 아래의 응시번호별 과제(`00002`, `00003`, `00007`, `00008` 등)를 Terraform으로 구현·검증·채점·정리할 때 공통으로 적용한다. 특정 과제의 리소스 이름이나 아키텍처를 다른 과제에 그대로 복사하지 말고, 항상 해당 응시번호의 원본 문제지와 채점 자료를 기준으로 작업한다.

## 1. 기준 자료와 작업 범위

1. 작업 대상이 `<응시번호>`라면 먼저 `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-<응시번호>/` 아래를 조사한다.
2. 우선순위는 다음과 같다.
   1. 과제 문제지 PDF
   2. 채점 기준 PDF와 채점 스크립트
   3. 공식 배포 파일과 안내 문서
   4. HWP/HWPX 자료
3. PDF의 단계, 리전, CIDR, 리소스 이름, 버전, 런타임, 암호화, 태그, 입출력 경로를 빠짐없이 표로 정리한 뒤 구현한다.
4. 문제지와 채점 스크립트가 다르면 실제 채점에 영향을 주는 요구사항을 모두 만족하도록 구현한다. 충돌하여 동시에 만족할 수 없을 때만 사용자에게 알린다.
5. 공식 배포 파일은 가능한 한 그대로 재사용한다. 바이너리, 이미지, 샘플 데이터, Lambda 코드의 내용을 임의로 대체하지 않는다.
6. 다른 응시번호 폴더는 패턴 참고용으로만 읽을 수 있다. 대상 과제의 고정 이름, 리전, 계정별 값 또는 네트워크 구성을 다른 과제에서 가져오지 않는다.

## 2. 디렉터리와 Terraform 파일 구성

- 결과물은 저장소 루트의 `<응시번호>/task1`, `<응시번호>/task2` 아래에 둔다.
- 과제지에서 서로 독립된 모듈은 별도의 Terraform root module과 별도의 state로 분리한다.
- 한 root module 안에서는 과제지의 단계마다 번호가 붙은 개별 `.tf` 파일을 만든다.
- 권장 형식은 다음과 같다.

```text
<응시번호>/
├── README.md
├── task1/
│   ├── 00-common.tf
│   ├── 01-<첫-단계>.tf
│   ├── 02-<둘째-단계>.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── assets/
└── task2/
    ├── <module-a>/
    │   ├── 00-common.tf
    │   ├── 01-<첫-단계>.tf
    │   ├── versions.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── <module-b>/
```

- `00-common.tf`에는 계정·리전 data source, 공통 locals 등만 둔다.
- `versions.tf`에는 Terraform/provider 버전과 provider 설정을 둔다.
- `variables.tf`와 `outputs.tf`에는 각각 입력과 출력만 둔다.
- Lambda 소스, 웹 자산, 컨테이너 파일, 사용자 데이터는 `lambda/`, `assets/`, `*.tftpl` 등으로 분리한다.
- 파일 분리는 가독성을 위한 것이며 같은 디렉터리의 모든 `.tf`는 하나의 root module로 함께 평가된다는 점을 README에 명시한다.
- `terraform.tfstate*`, 실제 `terraform.tfvars`, plan 파일, `.terraform/`, 생성 ZIP, 자격 증명과 비밀값은 커밋하지 않는다. 필요한 값은 `terraform.tfvars.example`에 안전한 예시로 제공한다.

## 3. 구현 원칙

- 리소스 이름, 리전, CIDR, AZ 수, 포트, 경로, 태그는 문제지 및 채점 스크립트의 정확한 값을 따른다.
- 계정 ID, 현재 파티션, caller ARN처럼 실행 환경에 따라 달라지는 값은 data source로 구한다.
- 응시번호가 이름에 들어가는 경우 `candidate_id` 같은 변수로 만들고 기본값 또는 예시는 대상 번호와 일치시킨다.
- S3처럼 전역 고유 이름이 필요한 리소스는 문제의 명명 규칙을 해치지 않는 범위에서만 계정 ID나 응시번호를 사용한다.
- 모든 리소스에 가능한 한 과제 식별 태그를 공통 적용한다. 예: `Project`, `CandidateId`, `ManagedBy = "Terraform"`. 정리 시 이 태그를 사용한다.
- provider가 지원하는 수명주기와 종속성을 명시적으로 구성한다. 단순히 `depends_on`을 남발하지 않는다.
- 삭제 시 내용이 생기는 실습용 S3 버킷은 요구사항에 반하지 않는다면 `force_destroy = true`를 고려한다. CloudTrail이나 애플리케이션이 계속 쓰는 버킷은 생산자를 먼저 중지한 뒤 비운다.
- EKS/Kubernetes/Helm처럼 클러스터 API 접근이 필요한 리소스는 기반 AWS 인프라와 별도 root module로 분리한다. 삭제는 애드온/워크로드 모듈부터 역순으로 수행한다.
- 코드 생성 후 깨진 한글, 잘못된 따옴표, 보이지 않는 제어 문자, 잘린 HCL 블록을 확인한다. 문서는 UTF-8로 저장한다.
- Terraform이 관리하지 않는 콘솔 수동 변경은 최소화한다. 불가피하면 README에 생성·검증·삭제 방법을 기록한다.

## 4. README 작성 기준

각 `<응시번호>/README.md`는 UTF-8 한국어로 작성하며 최소한 다음을 포함한다.

- 사용한 원본 문제지와 채점 자료의 상대 경로
- task와 모듈별 디렉터리 구조
- 과제 단계와 `.tf` 파일의 1:1 대응표
- 리전, 주요 네트워크 대역, 고정 리소스 이름
- 사전 준비 사항과 필요한 도구 버전
- 변수 설명과 `terraform.tfvars.example` 사용법
- `init`, `fmt`, `validate`, `plan`, `apply` 실행 순서
- 이미지 빌드/푸시나 별도 platform 적용 등 중간 절차
- 채점 스크립트 실행 방법과 전제 조건
- 모듈 간 정확한 destroy 순서 및 잔존 리소스 확인 방법
- KMS처럼 즉시 삭제할 수 없는 리소스의 동작

README의 명령은 해당 디렉터리에서 그대로 실행 가능한 형태여야 한다. Windows 전용 경로와 Bash 명령이 섞일 때는 PowerShell/WSL 실행 위치를 분명히 적는다.

## 5. 로컬 Terraform 검증

각 root module마다 다음 순서로 검사한다.

```bash
terraform fmt -recursive
terraform init -input=false
terraform validate
terraform plan -input=false
```

- 먼저 `terraform fmt -check -recursive` 또는 `terraform fmt -recursive`로 HCL 파싱과 형식을 확인한다.
- `init` 실패 시 provider 버전, 네트워크, lock 파일 문제를 구분한다.
- `validate` 오류는 파일·라인 단위로 수정한다.
- `plan`에는 과제에 필요한 변수 또는 `-var-file`을 빠짐없이 전달한다.
- 모든 root module의 plan이 성공할 때까지 실제 AWS에 적용하지 않는다.
- 사용자가 “plan까지만” 요청한 경우 `apply`, AWS CLI 생성/변경 명령, 채점 스크립트 실행은 하지 않는다.
- plan 결과에서 예상치 못한 삭제, 다른 응시번호 리소스, 기본 VPC 변경, 과도하게 넓은 IAM 권한을 검토한다.

## 6. AWS 적용 원칙

- 실제 `terraform apply`는 사용자가 명시적으로 요청한 경우에만 실행한다.
- 시작 전에 `aws sts get-caller-identity`와 각 module의 provider 리전을 확인한다.
- 다른 과제 또는 기존 사용자 리소스와 이름·태그가 겹치지 않는지 확인한다.
- 기반 인프라 → 애플리케이션/플랫폼 → 데이터 투입 순으로 적용한다.
- 장시간 생성되는 EKS, MSK, Flink, NAT Gateway 등은 완료 상태까지 기다리고 중간 실패를 확인한다.
- apply 후에는 Terraform output만 믿지 말고 AWS API로 실제 상태와 엔드포인트를 확인한다.
- 테스트 데이터나 채점 실행이 만드는 객체·로그도 이후 정리 대상에 포함한다.

## 7. 채점 스크립트 실행과 수정 반복

1. 대상 응시번호와 과제 번호에 정확히 대응하는 채점 스크립트를 찾는다.
2. 스크립트를 읽어 필요한 셸, AWS profile/region, `jq`, `kubectl` 등의 전제 조건과 파괴적 명령 유무를 먼저 확인한다.
3. Windows에서 Bash 스크립트는 WSL 또는 Git Bash의 경로 변환을 확인한 뒤 실행한다.
4. 사용자가 별도 횟수를 지정하지 않았다면 채점과 수정은 최대 3회까지만 시도한다.
5. 각 시도에서 다음을 기록한다.
   - 실행한 스크립트와 대상 과제
   - 실패한 항목과 실제 오류
   - 원인
   - 수정한 파일
6. 오류가 Terraform/애플리케이션 구현에서 발생한 경우에만 파일을 수정하고 필요한 최소 범위에 다시 plan/apply한다.
7. 채점 스크립트 자체의 명백한 환경 의존 오류는 원본을 함부로 고치지 말고 실행 환경을 맞춘다. 원본 오류로 판단되면 사용자에게 근거를 알린다.
8. 채점이 성공하거나 3회 실패하면 반복을 종료한다. 사용자가 정리를 요청했거나 “성공/실패 후 정리”를 포함했다면 결과와 관계없이 정리 단계로 진행한다.

## 8. 리소스 정리 절차

정리는 대상 응시번호와 이번 작업에서 생성한 리소스로만 제한한다. 이름 또는 태그가 불명확한 리소스는 삭제하지 않는다.

1. 새 데이터를 계속 생성하는 producer, CloudTrail, 이벤트 소스, 애플리케이션을 먼저 중지한다.
2. EKS 내부 리소스, Helm release, Kubernetes Service/Ingress 등 외부 AWS 리소스를 만드는 항목을 먼저 destroy한다.
3. 애플리케이션 모듈에서 기반 모듈의 역순으로 `terraform destroy`한다.
4. S3 `BucketNotEmpty`가 발생하면 생산자가 중지되었는지 확인하고, 대상 버킷만 비운 뒤 destroy를 재시도한다.
5. Terraform 밖에서 자동 생성된 CloudWatch Log Group을 과제 이름/태그로 찾아 삭제한다.
6. KMS 키는 AWS 정책상 즉시 삭제할 수 없다. 대상 키가 확실한 경우 최소 허용 대기 기간으로 삭제 예약하고 최종 삭제 날짜를 보고한다.
7. destroy 오류를 state에서 임의 제거하여 숨기지 않는다. 실제 AWS 리소스가 사라진 것을 확인한 경우에만 state 정합성을 처리한다.

다음 항목을 모든 사용 리전과 전역 서비스에서 교차 검증한다.

- 각 Terraform state의 관리 리소스 수가 0인지
- EC2, EBS, VPC, subnet, ENI, security group, NAT Gateway, Elastic IP
- ELB/ALB/NLB와 target group
- EKS, MSK, Kinesis/Flink, Lambda, Step Functions
- DynamoDB, S3, ECR, CloudFront
- CloudTrail, EventBridge, AWS Config, SNS, CloudWatch Log Group
- IAM role, instance profile, customer-managed policy
- KMS alias와 삭제 예약 키

Resource Groups Tagging API는 삭제된 EC2/NAT/EBS ARN을 잠시 반환할 수 있다. 태깅 결과만으로 잔존 여부를 판단하지 말고 해당 서비스 API에서 `terminated`, `deleted`, `NotFound`인지 직접 확인한다.

## 9. 안전과 완료 보고

- AWS 계정 전체를 포괄하는 이름 없는 일괄 삭제를 하지 않는다.
- 기본 VPC, 다른 응시번호, 다른 프로젝트 또는 사용자가 만든 리소스는 건드리지 않는다.
- 삭제 전에는 계정 ID, 리전, 리소스 ID, 이름, 태그를 확인한다.
- 로컬 `.tf` 소스와 README는 리소스 정리 대상이 아니다. 사용자가 명시적으로 요청하지 않는 한 삭제하지 않는다.
- 완료 보고에는 다음을 간결하게 포함한다.
  - 수정한 파일과 구현 범위
  - `fmt`, `validate`, `plan`, apply 결과
  - 채점 시도 횟수와 최종 결과
  - destroy 결과와 실제 AWS 잔존 리소스 조회 결과
  - 삭제 예약 상태로 남은 KMS 키와 최종 삭제 예정일
  - 실행하지 못한 항목과 그 이유

## 10. 작업 체크리스트

- [ ] 대상 응시번호의 문제지·채점지·채점 스크립트를 확인했다.
- [ ] 과제 단계별로 `.tf` 파일을 분리했다.
- [ ] 공식 배포 자산을 올바른 위치에서 재사용했다.
- [ ] README를 UTF-8로 갱신했다.
- [ ] 모든 root module에서 `fmt`, `init`, `validate`, `plan`이 성공했다.
- [ ] 사용자 요청 범위 안에서만 apply했다.
- [ ] 채점 스크립트를 최대 허용 횟수 안에서 실행·수정했다.
- [ ] 종속 관계의 역순으로 destroy했다.
- [ ] Terraform state와 실제 AWS API를 모두 확인했다.
- [ ] 삭제 예약 리소스와 잔존 여부를 사용자에게 보고했다.
