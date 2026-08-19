# 응시번호 00002 Terraform 구현

제61회 전국기능경기대회 클라우드컴퓨팅 00002의 1과제와 2과제를 Terraform으로 구현한다. 같은 디렉터리의 모든 `.tf` 파일은 하나의 root module과 state로 함께 평가된다.

## 기준 자료

- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/00_최종본_안내.txt`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/과제지&배포파일/1과제_문제.pdf`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/채점기준표&채점스크립트/1과제_채점기준.pdf`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/채점기준표&채점스크립트/채점스크립트/mark.sh`
- 같은 최종제출본의 `2과제/과제지&배포파일/2과제_문제.pdf`, `2과제/채점기준표&채점스크립트/2과제_채점기준.pdf`, `mark2-1.sh`부터 `mark2-4.sh`
- `docs/2026-07-31 직종협의회.md`는 운영 참고사항으로만 사용한다.

요구사항 대조표는 `REQUIREMENTS.md`, 원본 간 충돌은 `ERROR_CANDIDATES.md`에 기록했다. 공식 PDF와 채점 스크립트는 수정하지 않았다.

## 디렉터리와 state 경계

```text
00002/
├── task1/
│   ├── foundation/             # 1과제 AWS 기반 root/state
│   │   └── 00-common.tf ~ 10-monitoring.tf
│   └── application/            # EKS Kubernetes/Helm root/state
└── task2/
    ├── workflow/               # ap-southeast-1, 독립 root/state
    ├── analytics/              # ap-northeast-2, 독립 root/state
    ├── cloud-event/            # eu-west-1, 독립 root/state
    └── msk/                    # ap-northeast-1, 독립 root/state
```

1과제는 `task1/foundation → task1/application` 순으로 적용한다. `application`은 foundation output만 읽으며 EKS 워크로드와 모니터링을 소유한다. 디렉터리를 옮겼지만 기존 두 root/state 경계와 각 Terraform 리소스 주소는 유지한다. 2과제 네 root는 리전과 수명주기가 달라 서로 state를 공유하지 않으며 독립적으로 plan/apply/destroy할 수 있다. 모든 root는 `00-common.tf`, 단계 번호 파일, `versions.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`의 공통 형식을 사용한다.

## 주요 고정값

| 범위 | 리전 | 네트워크 | 주요 이름 |
|---|---|---|---|
| 1과제 | ap-northeast-2 | 172.16.0.0/16, public 172.16.1/24·2/24, private 172.16.201/24·202/24 | `wskorea26-cluster`, `wskorea26-book-repo`, `wskorea26-data-table` |
| Workflow | ap-southeast-1 | 해당 없음 | `wsc2026-student-score-workflow`, `wsc2026-student-score` |
| Analytics | ap-northeast-2 | 10.20.0.0/16, public 0/24·1/24, private 100/24·101/24 | `wsc2026-analytics-ec2`, `wsc2026-order-stream` |
| Cloud Event | eu-west-1 | 172.16.0.0/16, public 0/24·1/24 | `wsc2026-event-ec2`, `wsc2026-event-trail` |
| MSK | ap-northeast-1 | 192.168.0.0/16, public 0/24·1/24, private 10/24·11/24 | `wsc2026-msk-cluster`, `wsc2026-sensor-data` |

전역 고유 S3 버킷에는 `candidate_id` 또는 계정 기반 suffix를 붙인다. 공통 태그는 `Project`, `CandidateId`, `ManagedBy=Terraform`이다.

## 사전 준비

- Terraform 1.8 이상
- AWS CLI v2와 대상 계정 자격 증명
- 1과제 이미지 빌드용 Docker와 Bash
- EKS 작업 및 채점용 `kubectl`, Helm, `jq`
- MSK는 공식 배포 바이너리 `task2/msk/assets/app`을 그대로 사용한다.

실행 전에 `aws sts get-caller-identity`로 계정을 확인한다. 실제 `terraform.tfvars`, state, plan, `.terraform/`, 생성 ZIP과 자격 증명은 커밋하지 않는다.

## 변수

- `candidate_id`: 기본 예시는 `00002`; S3 버킷과 Grafana 사용자명에 사용한다.
- `aws_profile`: 선택적 AWS CLI profile이다.
- `availability_zones`: 문제지의 AZ suffix와 일치하는 두 AZ다.
- `allowed_cidr`: Analytics ALB 접근 CIDR이다. 운영 시 필요한 범위로 축소한다.
- `book_image_uri`: 1과제 ECR의 `stable` 이미지 URI다.
- `producer_binary_path`: MSK 공식 producer 바이너리 경로다.

필요한 모듈에서 `terraform.tfvars.example`을 `terraform.tfvars`로 복사하고 실제 값만 수정한다.

## 검증과 적용 순서

각 root module에서 다음을 실행한다.

```powershell
terraform fmt -check
terraform init -input=false
terraform validate
terraform plan -input=false -var-file=terraform.tfvars
```

각 root의 `terraform.tfvars.example`을 복사한 뒤 마지막 옵션을 사용한다. 적용은 검증 성공 후 사용자가 명시적으로 허용한 경우에만 같은 인수로 `terraform apply`를 실행한다.

`task1/application`은 `foundation` state의 EKS output을 읽으므로 foundation을 먼저 apply해야 plan할 수 있다. foundation state가 비어 있는 초기 상태에서는 application의 `validate`까지만 성공하는 것이 정상이다.

1과제 적용 순서는 다음과 같다.

```powershell
Set-Location 00002/task1/foundation
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -input=false
terraform apply -var-file=terraform.tfvars
```

ECR 생성 후 Git Bash 또는 WSL에서 `./push-image.sh`로 공식 `book` 바이너리 이미지를 `stable` 태그로 push한다. 이어 `task1/application/terraform.tfvars`의 `book_image_uri`를 실제 ECR URI로 설정하고, EKS private endpoint에 접근할 수 있는 CloudShell VPC 환경에서 application을 적용한다.

2과제는 `workflow`, `analytics`, `cloud-event`, `msk`를 각각 해당 디렉터리에서 독립 실행한다. Workflow의 샘플 CSV 업로드와 MSK producer 설치는 해당 root apply에 포함된다.

## 일회성 ECR 이미지 푸시 베스천

로컬 Docker를 사용할 수 없을 때만 `task1/extensions/grading-bastion`을 사용한다. 이 독립 root는 private subnet의 SSM 전용 EC2, 최소 ECR/S3/KMS 권한, 임시 Docker build 객체만 생성한다. 이미지 푸시와 ECR 확인이 끝나면 반드시 destroy한다. SSH와 public IP는 사용하지 않는다.

```powershell
Set-Location 00002/task1/extensions/grading-bastion
terraform init -input=false
terraform apply -var-file=terraform.tfvars.example
# SSM Run Command로 Docker build/push 후 ECR stable 태그를 확인한다.
terraform apply -var-file=terraform.tfvars.example -var='dynamodb_deletion_protection_enabled=false'
terraform destroy -var-file=terraform.tfvars.example -var='dynamodb_deletion_protection_enabled=false'
```

## 채점

채점 스크립트는 원본 위치에서 수정하지 않고 AWS CloudShell에서 실행한다. 계정과 리전을 먼저 확인하고, 1과제는 private subnet `wskorea26-priv-subnet-d`와 `wskorea26-vpc-environment-sg`를 사용하는 CloudShell VPC 환경에서 EKS 접근을 확인한다.

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region ap-northeast-2 --name wskorea26-cluster
kubectl get nodes
bash mark.sh
```

2과제는 각 `mark2-1.sh`부터 `mark2-4.sh`를 스크립트가 지정한 리전에서 실행한다. 스크립트는 EC2 중지와 SG 규칙 추가 같은 상태 변경을 수행하므로 내용을 검토한 뒤 실제 채점 시에만 실행한다.

## Destroy 순서

1과제는 외부 ALB를 만드는 Kubernetes/Helm 리소스를 먼저 제거한 뒤 기반을 제거한다.

```powershell
Set-Location 00002/task1/application
terraform destroy -var-file=terraform.tfvars
Set-Location ../foundation
terraform destroy -var-file=terraform.tfvars
```

2과제는 producer와 이벤트 생산을 먼저 중지하고 `msk`, `cloud-event`, `analytics`, `workflow`를 각 root에서 독립 destroy한다. S3는 해당 과제 버킷만 비우며, CloudTrail과 producer가 더 이상 쓰지 않는지 먼저 확인한다. MSK의 VPC Lambda를 삭제한 직후에는 AWS가 Lambda ENI를 비동기로 회수하므로, security group 또는 subnet 삭제가 `DependencyViolation`으로 대기하면 ENI가 `available` 또는 삭제될 때까지 기다린 뒤 같은 `terraform destroy`를 재실행한다. `in-use` 상태의 AWS 관리 ENI를 강제로 삭제하지 않는다. KMS 키는 즉시 삭제되지 않고 AWS가 허용하는 대기 기간 뒤 삭제된다.

마지막으로 각 state의 관리 리소스 수가 0인지 확인하고, 해당 리전의 EC2/VPC/ENI/ELB/EKS/MSK/Lambda/DynamoDB/S3/CloudTrail/EventBridge/Config/SNS/CloudWatch/IAM/KMS를 이름과 태그로 교차 확인한다.

## Terraform 입력 자산

Terraform 입력 자산은 과제 루트 `assets/`에서만 관리한다. `foundation`은 `assets/foundation/`의 웹 파일, Lambda 코드, 제공 바이너리, Kubernetes manifest와 모니터링 대시보드를 사용한다. `grading-bastion`도 foundation 디렉터리가 아니라 같은 자산 경로를 참조한다.

- 공식 원본 `37_클라우드컴퓨팅/...`는 이동하거나 수정하지 않는다.
- Lambda ZIP과 같이 Terraform 실행 중 생성되는 파일은 각 root module에 생성되며 `assets/`에 커밋하지 않는다.
- 자산 이동 후에는 원본 Git blob hash 또는 SHA-256으로 바이트 동일성을 확인한다.
