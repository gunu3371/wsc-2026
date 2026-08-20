# 1과제 00002 Terraform 구현

제61회 전국기능경기대회 클라우드컴퓨팅 과제번호 00002의 **1과제만** Terraform으로 구현한다. 2과제 구현은 별도 과제 루트인 `task2/00002`에서 관리하며, 이 디렉터리의 변수 파일·state·적용·채점·정리 절차와 공유하지 않는다. 각 root module 디렉터리 안의 모든 `.tf` 파일은 하나의 root module과 state로 함께 평가된다.

## 기준 자료

- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/00_최종본_안내.txt`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/과제지&배포파일/1과제_문제.pdf`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/채점기준표&채점스크립트/1과제_채점기준.pdf`
- `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/1과제/채점기준표&채점스크립트/채점스크립트/mark.sh`
- `docs/2026-07-31 직종협의회.md`는 운영 참고사항으로만 사용한다.

요구사항 대조표는 `REQUIREMENTS.md`, 원본 간 충돌은 `ERROR_CANDIDATES.md`에 기록했다. 공식 PDF와 채점 스크립트는 수정하지 않았다.

## 디렉터리와 state 경계

```text
task1/00002/
├── foundation/                 # 1과제 AWS 기반 root/state
│   └── 00-common.tf ~ 10-monitoring.tf
├── application/                # EKS Kubernetes/Helm root/state
├── extensions/
│   ├── image-build/            # CodeBuild 기반 ECR 이미지 빌드 root/state
│   └── grading-bastion/        # 예외적 진단용 SSM 베스천 root/state
├── assets/
│   └── shared/book-image/      # 공식 book 바이너리와 Dockerfile
└── terraform.tfvars.example    # 1과제 전용 변수 예시
```

1과제는 `foundation → application` 순으로 적용한다. `application`은 foundation output만 입력으로 받으며 EKS 워크로드와 모니터링을 소유한다. root/state 경계와 Terraform 리소스 주소는 유지한다. 변수 예시는 과제 루트의 단일 `terraform.tfvars.example`에서 관리한다.

## 주요 고정값

| 범위 | 리전 | 네트워크 | 주요 이름 |
|---|---|---|---|
| 1과제 | ap-northeast-2 | 172.16.0.0/16, public 172.16.1/24·2/24, private 172.16.201/24·202/24 | `wskorea26-cluster`, `wskorea26-book-repo`, `wskorea26-data-table` |

전역 고유 S3 버킷에는 `task_id` 또는 계정 기반 suffix를 붙인다. 공통 태그는 `Project`, `TaskId`, `ManagedBy=Terraform`이다.

## 사전 준비

- Terraform 1.8 이상
- AWS CLI v2와 대상 계정 자격 증명
- Windows PowerShell 5.1 이상과 AWS CLI v2
- EKS 작업 및 채점용 `kubectl`, Helm, `jq`

실행 전에 `aws sts get-caller-identity`로 계정을 확인한다. 실제 `terraform.tfvars`, state, plan, `.terraform/`, 생성 ZIP과 자격 증명은 커밋하지 않는다.

## 단일 변수 파일

과제 루트에서 `Copy-Item terraform.tfvars.example terraform.tfvars`를 한 번 실행한다. `config.common`에는 과제 공통값, `config.modules`에는 직접 입력, `config.outputs.foundation`에는 foundation 적용 후 얻은 EKS와 DynamoDB output을 기록한다. 실제 파일은 Git에 커밋하지 않는다.

CloudShell의 IAM principal이 foundation 생성 principal과 다르면 foundation 적용 전에 `config.modules.foundation.additional_cluster_admin_principal_arns`에 CloudShell의 영구 IAM user/role ARN을 추가한다. Terraform은 각 ARN의 EKS Access Entry와 클러스터 범위 `AmazonEKSClusterAdminPolicy` 연결을 함께 관리한다. 계정 root ARN과 `arn:aws:sts::...` 형식의 임시 세션 ARN은 사용하지 않는다. foundation 생성 principal과 CloudShell principal이 같으면 빈 목록을 유지한다.

## 검증과 적용 순서

과제 루트에서 root module별로 다음을 실행한다.

```powershell
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars"
# foundation 적용 후 terraform.tfvars의 config.outputs.foundation을 갱신한다.
terraform -chdir=extensions/image-build plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=application plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=extensions/grading-bastion plan -input=false "-var-file=../../terraform.tfvars"
```

적용은 검증 성공 후 사용자가 명시적으로 허용한 경우에만 같은 `-var-file` 인수로 실행한다.

`application`은 foundation state를 직접 읽지 않는다. foundation을 먼저 apply한 뒤 `terraform -chdir=foundation output` 결과를 이 과제 루트의 `terraform.tfvars` 내 `config.outputs.foundation`에 복사해야 application을 plan할 수 있다.

1과제 적용 순서는 다음과 같다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform -chdir=foundation init -input=false
terraform -chdir=foundation apply "-var-file=../terraform.tfvars"
```

ECR 생성 후에는 Docker나 WSL을 사용하지 않는다. image-build extension이 S3에 공식 `book` 바이너리와 Dockerfile을 준비하고, CodeBuild가 Linux/amd64 이미지를 ECR의 `stable` 태그로 푸시한다. application은 ECR 저장소를 직접 조회하므로 이미지 URI를 `terraform.tfvars`에 복사할 필요가 없다.

```powershell
terraform -chdir=extensions/image-build init -input=false
terraform -chdir=extensions/image-build apply "-var-file=../../terraform.tfvars"
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1
# aws_profile을 tfvars에 지정했다면 같은 profile을 -Profile에 전달한다.
# powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1 -Profile my-profile
# CodeBuild가 SUCCEEDED를 출력한 뒤 실행한다.
terraform -chdir=application apply "-var-file=../terraform.tfvars"
```

`Start-BookImageBuild.ps1`은 AWS CLI로 CodeBuild를 시작하고 완료까지 기다린다. 실패하면 CloudWatch Logs의 `/aws/codebuild/wskorea26-image-build`를 확인한다. CodeBuild 실행에는 추가 비용이 발생하며, 푸시가 끝난 뒤에도 extension을 유지하면 같은 명령으로 이미지를 다시 빌드할 수 있다.

## 예외적 진단용 베스천

일반적인 이미지 푸시는 `extensions/image-build`와 CodeBuild를 사용한다. `extensions/grading-bastion`은 CodeBuild 장애를 분석해야 하는 예외 상황에만 사용한다. 이 독립 root는 private subnet의 SSM 전용 EC2, 최소 ECR/S3/KMS 권한, 임시 Docker build 객체만 생성한다. 진단이 끝나면 반드시 destroy한다. SSH와 public IP는 사용하지 않는다.

```powershell
terraform -chdir=extensions/grading-bastion init -input=false
terraform -chdir=extensions/grading-bastion apply "-var-file=../../terraform.tfvars"
# SSM Run Command로 Docker build/push 후 ECR stable 태그를 확인한다.
terraform -chdir=extensions/grading-bastion destroy "-var-file=../../terraform.tfvars"
```

## 채점

채점 스크립트는 원본 위치에서 수정하지 않고 AWS CloudShell에서 실행한다. 계정과 리전을 먼저 확인하고, 1과제는 private subnet `wskorea26-priv-subnet-d`와 `wskorea26-vpc-environment-sg`를 사용하는 CloudShell VPC 환경에서 EKS 접근을 확인한다.

```bash
aws sts get-caller-identity --query Arn --output text
aws eks list-access-entries --region ap-northeast-2 --cluster-name wskorea26-cluster
aws eks update-kubeconfig --region ap-northeast-2 --name wskorea26-cluster
kubectl auth can-i '*' '*' --all-namespaces
kubectl get nodes
bash mark.sh
```

`kubectl auth can-i`가 `yes`이고 노드가 조회된 뒤에만 채점한다. 등록한 추가 관리자 권한은 foundation state가 소유하므로 채점 중 수동으로 Access Entry를 만들거나 삭제하지 않는다.

## Destroy 순서

1과제는 외부 ALB를 만드는 Kubernetes/Helm 리소스를 먼저 제거한 뒤 기반을 제거한다.

```powershell
terraform -chdir=extensions/image-build destroy "-var-file=../../terraform.tfvars"
terraform -chdir=application destroy "-var-file=../terraform.tfvars"
# config.modules.foundation.dynamodb_deletion_protection_enabled를 false로 반영한 뒤 실행한다.
terraform -chdir=foundation destroy "-var-file=../terraform.tfvars"
```

마지막으로 각 state의 관리 리소스 수가 0인지 확인하고, `ap-northeast-2`의 EC2/VPC/ENI/ELB/EKS/Lambda/DynamoDB/S3/CloudWatch/IAM/KMS를 이름과 태그로 교차 확인한다. KMS 키는 즉시 삭제되지 않으므로 삭제 예약일도 확인한다.

## Terraform 입력 자산

Terraform 입력 자산은 과제 루트 `assets/`에서만 관리한다. `foundation`은 `assets/foundation/`의 웹 파일, Lambda 코드, Kubernetes manifest와 모니터링 대시보드를 사용한다. 공식 `book` 바이너리와 Dockerfile은 `assets/shared/book-image/`에 두며, `image-build`와 `grading-bastion`이 동일 파일을 재사용한다.

- 공식 원본 `37_클라우드컴퓨팅/...`는 이동하거나 수정하지 않는다.
- Lambda ZIP과 같이 Terraform 실행 중 생성되는 파일은 각 root module에 생성되며 `assets/`에 커밋하지 않는다.
- 자산 이동 후에는 원본 Git blob hash 또는 SHA-256으로 바이트 동일성을 확인한다.
