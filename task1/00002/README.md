# 1과제 00002 Terraform 구현

과제번호 `00002`의 1과제만 다룬다. 2과제는 `task2/00002`에서 별도 변수 파일, state, 적용, 채점 및 정리 절차로 관리한다.

## 기준 자료 및 확인 상태

- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/00_최종본_안내.txt`
- 기존 문제지: 같은 경로의 `01_최종제출본/제61회전국기능경기대회_vf/1과제/과제지&배포파일/1과제_문제.pdf`
- 기존 채점지·`mark.sh`: 같은 경로의 `01_최종제출본/제61회전국기능경기대회_vf/1과제/채점기준표&채점스크립트/`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/1과제 00002/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

수정본은 2026-08-21에 기존 PDF와 대조했다. 로그인 전용 공식 게시 여부는 확인하지 못했으며 공식 PDF와 채점 스크립트는 수정하지 않았다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상과 AWS CLI v2
- Windows PowerShell 5.1 이상
- EKS 작업용 `kubectl`, Helm, `jq`
- `ap-northeast-2` 대상 AWS 자격 증명

먼저 계정을 확인한다.

```powershell
aws sts get-caller-identity
terraform fmt -check -recursive
```

실제 `terraform.tfvars`, state, plan, `.terraform/`, 생성 ZIP과 자격 증명은 Git에 커밋하지 않는다.

### 변수 파일 준비

과제 루트 `task1/00002`에서 한 번만 실행한다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 검증과 적용 순서

1. `foundation`
2. `image-build` extension과 CodeBuild 이미지 push
3. foundation output을 `terraform.tfvars`에 기록
4. `application`

```powershell
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=foundation apply "-var-file=../terraform.tfvars"
terraform -chdir=foundation output
```

ECR 생성 후 이미지를 빌드하고 `stable` 태그로 push한다.

```powershell
terraform -chdir=extensions/image-build init -input=false
terraform -chdir=extensions/image-build validate
terraform -chdir=extensions/image-build plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/image-build apply "-var-file=../../terraform.tfvars"
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1
```

`config.outputs.foundation`을 갱신하고 CodeBuild가 `SUCCEEDED`인지 확인한 뒤 application을 적용한다.

```powershell
terraform -chdir=application init -input=false
terraform -chdir=application validate
terraform -chdir=application plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=application apply "-var-file=../terraform.tfvars"
```

실제 apply는 각 plan을 검토한 뒤 실행한다.

## 구조와 state 경계

```text
task1/00002/
├── foundation/                  # AWS 기반 root/state
├── application/                 # EKS Kubernetes·Helm root/state
├── extensions/
│   ├── image-build/             # CodeBuild 이미지 생성 root/state
│   └── grading-bastion/         # 선택적 SSM 진단 root/state
├── assets/
│   └── shared/book-image/       # 공식 바이너리와 Dockerfile
└── terraform.tfvars.example     # 1과제 공용 변수 예시
```

각 디렉터리 안의 모든 `.tf` 파일은 하나의 root module로 평가된다. `foundation`, `application`, 각 extension은 state를 공유하지 않는다.

| 범위 | 리전·네트워크 | 주요 이름 |
| --- | --- | --- |
| 1과제 | ap-northeast-2, VPC `172.16.0.0/16` | `wskorea26-cluster`, `wskorea26-book-repo`, `wskorea26-data-table` |

public subnet은 `172.16.1.0/24`, `172.16.2.0/24`, private subnet은 `172.16.201.0/24`, `172.16.202.0/24`다.

## 변수와 output 전달

- `config.common`: 과제 공통값
- `config.modules`: foundation, application, extension 직접 입력
- `config.outputs.foundation`: EKS와 DynamoDB 등 foundation output

application은 foundation state를 직접 읽지 않는다. foundation 적용 후 다음 결과를 실제 `terraform.tfvars`의 `config.outputs.foundation`에 복사한다.

```powershell
terraform -chdir=foundation output
```

CloudShell IAM principal이 foundation 생성 principal과 다르면 적용 전에
`additional_cluster_admin_principal_arns`에 영구 IAM user 또는 role ARN을 넣는다.
계정 root ARN과 `arn:aws:sts::...` 임시 session ARN은 사용하지 않는다.

## 이미지 빌드

Docker나 WSL 대신 CodeBuild가 Linux/amd64 이미지를 만들어 `wskorea26-book-repo:stable`로 push한다. application은 ECR 저장소를 직접 조회하므로 이미지 URI를 변수 파일에 복사하지 않는다.

AWS profile을 사용하는 경우 스크립트에도 같은 profile을 전달한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1 -Profile my-profile
```

실패하면 CloudWatch Logs의 `/aws/codebuild/wskorea26-image-build`를 확인한다. CodeBuild에는 비용이 발생하며 extension을 유지하면 같은 스크립트로 다시 빌드할 수 있다.

## 수정본 반영사항

| 항목 | 값 |
| --- | --- |
| DynamoDB GSI | `concert_name-created_at-index`, PK `concert_name`, SK `created_at` |
| CloudFront origin | `wskorea26-s3-origin`, `wskorea26-alb-origin` |
| S3 origin header | `wskorea26-s3-access: true` |
| ALB origin header | `X-Origin-Verify: wskorea26-cf` |
| Grafana | `book` 앱 기준 CPU, Memory, Running Pods, Restarts, Network Receive |

## 채점 전 확인

- CodeBuild가 `stable` 이미지를 ECR에 push했는지 확인한다.
- `config.outputs.foundation`의 placeholder가 실제 값으로 바뀌었는지 확인한다.
- EKS node, application Pod, Grafana와 CloudFront endpoint를 확인한다.
- 원본 `mark.sh`는 수정하지 않는다.

<details>
<summary>CloudShell VPC environment와 EKS 인증 확인</summary>

foundation은 다음 네트워크 구성을 미리 만든다.

- EKS private endpoint는 기존 `wskorea26-vpc-environment-sg`를 사용한다.
- CloudShell에는 inbound 규칙이 없는 `wskorea26-cloudshell-sg`를 연결한다.
- EKS 연결용 SG는 CloudShell SG에서 들어오는 TCP 443만 허용한다.
- CloudShell은 NAT Gateway 경로가 있는 `wskorea26-priv-subnet-d`를 사용한다.

콘솔에서 선택할 VPC, subnet, security group ID를 확인한다.

```powershell
terraform -chdir=foundation output -raw cloudshell_vpc_id
terraform -chdir=foundation output -raw cloudshell_subnet_id
terraform -chdir=foundation output -raw cloudshell_security_group_id
```

CloudShell VPC environment 자체는 콘솔에서 생성한다. 기존 기본 environment를 삭제할 필요는 없다.

```bash
aws sts get-caller-identity --query Arn --output text
aws eks list-access-entries --region ap-northeast-2 --cluster-name wskorea26-cluster
aws eks update-kubeconfig --region ap-northeast-2 --name wskorea26-cluster
kubectl auth can-i '*' '*' --all-namespaces
kubectl get nodes
bash mark.sh
```

timeout이면 VPC, subnet, SG와 EKS TCP 443 규칙을 확인한다. credential 오류면 `additional_cluster_admin_principal_arns`의 영구 IAM principal 등록 여부를 확인한다.

</details>

<details>
<summary>선택적 grading-bastion 사용</summary>

`grading-bastion`은 일반 이미지 push 용도가 아니다. CodeBuild 장애를 분석해야 할 때만 private subnet에 SSM 전용 EC2를 만든다. SSH와 public IP는 사용하지 않는다.

```powershell
terraform -chdir=extensions/grading-bastion init -input=false
terraform -chdir=extensions/grading-bastion validate
terraform -chdir=extensions/grading-bastion plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/grading-bastion apply "-var-file=../../terraform.tfvars"
```

SSM Run Command로 진단한 뒤 즉시 제거한다.

```powershell
terraform -chdir=extensions/grading-bastion destroy "-var-file=../../terraform.tfvars"
```

</details>

## 역순 정리

1. 적용했다면 `grading-bastion`
2. `image-build`
3. `application`
4. DynamoDB 삭제 보호 해제
5. `foundation`

```powershell
terraform -chdir=extensions/image-build destroy "-var-file=../../terraform.tfvars"
terraform -chdir=application destroy "-var-file=../terraform.tfvars"
```

`config.modules.foundation.dynamodb_deletion_protection_enabled = false`를 실제 변수 파일에 반영한 뒤 foundation을 제거한다.

```powershell
terraform -chdir=foundation destroy "-var-file=../terraform.tfvars"
```

각 state가 비었는지 확인하고 EC2, VPC, ENI, ELB, EKS, Lambda, DynamoDB, S3, CloudWatch, IAM 및 KMS를 실제 AWS API에서 교차 확인한다. KMS 키는 즉시 삭제되지 않으므로 삭제 예약일도 확인한다.

## 입력 자산 및 관련 문서

- `assets/foundation/`: 웹, Lambda, Kubernetes와 monitoring 입력
- `assets/shared/book-image/`: 공식 book 바이너리와 Dockerfile
- [REQUIREMENTS.md](REQUIREMENTS.md): 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 원본 간 충돌

공식 원본은 이동하거나 수정하지 않는다. Lambda ZIP 등 Terraform 실행 산출물은 `assets/`에 넣지 않는다. 자산을 이동할 때는 Git blob hash 또는 SHA-256으로 동일성을 확인한다.
