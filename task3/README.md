# 3과제 Terraform 구현

3과제는 공통 과제 하나뿐이므로 과제번호 하위 디렉터리 없이 `task3/`를 과제 루트로 사용한다. EKS 기반 API, RDS, S3 이미지 제공, 단일 CloudFront endpoint, WAF와 모니터링을 구성한다.

## 기준 자료 및 확인 상태

- 문제지: `../2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_문제지_v1.0.0.pdf`
- 채점기준표: 같은 경로의 `2026년_전국대회_3과제_채점기준표_v1.0.0.pdf`
- 운영 참고: `../docs/2026-07-31 직종협의회.md`

로그인이 필요한 공식 게시물의 마지막 댓글과 최신 첨부는 확인하지 못했다. 공식 정정이 배포되면 [REQUIREMENTS.md](REQUIREMENTS.md)와 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)를 먼저 다시 대조한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, Docker, `kubectl`, Helm 3
- PowerUser 이상 수준의 대회 계정과 `ap-northeast-2` 사용 권한
- 공식 linux/amd64 `user`, `product`, `stress` 바이너리와 `load_user.dump`

현재 저장소에는 공식 바이너리와 `load_user.dump`가 없다. 임의 구현으로 대체하지 말고 공식 지급 파일을 확보한 뒤 진행한다.

### 변수 파일 준비

저장소 루트에서 `task3`로 이동한 뒤 한 번만 복사한다.

```powershell
Set-Location task3
Copy-Item terraform.tfvars.example terraform.tfvars
```

`candidate_id`는 과제번호가 아니라 실제 응시자 구분값이다. 전역 고유 S3 이름 등에 사용되므로 본인의 값으로 바꾼다.

### 검증과 적용 순서

1. `foundation`
2. 공식 바이너리 image build/push
3. foundation output을 `terraform.tfvars`에 기록
4. `application`
5. `monitoring` extension

```powershell
terraform -chdir=foundation fmt -check
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars" -out=foundation.tfplan
terraform -chdir=foundation apply foundation.tfplan
terraform -chdir=foundation output
```

이미지를 push하고 `config.outputs.foundation`을 갱신한 뒤 application을 적용한다.

```powershell
terraform -chdir=application fmt -check
terraform -chdir=application init -input=false
terraform -chdir=application validate
terraform -chdir=application plan -input=false "-var-file=../terraform.tfvars" -out=application.tfplan
terraform -chdir=application apply application.tfplan
terraform -chdir=application output -raw endpoint
```

마지막으로 monitoring extension을 적용한다.

```powershell
terraform -chdir=extensions/monitoring fmt -check
terraform -chdir=extensions/monitoring init -input=false
terraform -chdir=extensions/monitoring validate
terraform -chdir=extensions/monitoring plan -input=false "-var-file=../../terraform.tfvars" -out=monitoring.tfplan
terraform -chdir=extensions/monitoring apply monitoring.tfplan
```

실제 apply는 각 plan을 검토하고 대상 계정과 리전을 확인한 뒤 실행한다.

## 구조와 state 경계

```text
task3/
├── foundation/                  # VPC, EKS, RDS, ECR, S3, IAM
├── application/                 # ingress, workload, HPA/PDB, CloudFront, WAF
├── extensions/
│   └── monitoring/              # Observability addon, alarm, dashboard
├── assets/
│   └── shared/
│       └── Dockerfile.binary    # 공식 x86 바이너리 패키징
├── terraform.tfvars.example
├── REQUIREMENTS.md
└── ERROR_CANDIDATES.md
```

각 root module은 별도 state를 사용한다. 같은 디렉터리 안의 모든 `.tf` 파일은 하나의 root module로 함께 평가된다.

| 단계 | 주요 Terraform 파일 |
| --- | --- |
| VPC와 2-AZ 네트워크 | `foundation/01-network.tf` |
| EKS IAM·cluster | `foundation/02-iam.tf`, `03-cluster.tf` |
| MySQL RDS | `foundation/04-database.tf` |
| ECR·S3·product 권한 | `foundation/05-artifacts.tf` |
| ingress·workload·HPA/PDB | `application/01-platform.tf`, `02-workloads.tf` |
| endpoint·이미지·WAF | `application/03-routing.tf` |
| 로그·지표·오류 탐지 | `extensions/monitoring/01-observability.tf` |

주요 고정값은 VPC `10.30.0.0/16`, EKS EC2 `t3.medium`, 애플리케이션 TCP 8080이다. RDS는 `apdev-rds-instance`, MySQL 8.0, Multi-AZ, `db.t3.micro`, gp3를 사용한다.

## 변수와 output 전달

- `config.common`: 공통값과 실제 응시자 `candidate_id`
- `config.modules`: foundation, application, monitoring 직접 입력
- `config.outputs.foundation`: 후속 module에 전달할 foundation output

foundation 적용 후 다음 값을 실제 `terraform.tfvars`에 복사한다.

- `cluster_name`, `node_role_name`
- `database_secret_arn`
- `image_bucket_name`
- `product_pod_role_arn`

후속 module은 foundation state를 직접 읽지 않는다.

## 공식 바이너리 image build/push

`assets/shared/Dockerfile.binary`는 공식 linux/amd64 바이너리를 변경하지 않고 Amazon Linux 2023 이미지에 넣는다. `<...-binary>`는 실제 지급 파일명으로 바꾼다.

```powershell
$AccountId = aws sts get-caller-identity --query Account --output text
$Registry = "$AccountId.dkr.ecr.ap-northeast-2.amazonaws.com"
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $Registry

docker build --platform linux/amd64 -f assets/shared/Dockerfile.binary --build-arg BINARY=<user-binary> -t "$Registry/apdev-task3-user:latest" .
docker build --platform linux/amd64 -f assets/shared/Dockerfile.binary --build-arg BINARY=<product-binary> -t "$Registry/apdev-task3-product:latest" .
docker build --platform linux/amd64 -f assets/shared/Dockerfile.binary --build-arg BINARY=<stress-binary> -t "$Registry/apdev-task3-stress:latest" .

docker push "$Registry/apdev-task3-user:latest"
docker push "$Registry/apdev-task3-product:latest"
docker push "$Registry/apdev-task3-stress:latest"
```

문제지에는 공식 product 바이너리가 요구하는 S3 환경변수 이름이 빠져 있다. 현재 구현은 `AWS_REGION`, `AWS_DEFAULT_REGION`, `S3_BUCKET`, `S3_BUCKET_NAME`을 제공한다. 공식 정정이 나오면 `application/02-workloads.tf`만 수정한다.

<details>
<summary>RDS에 load_user.dump 적재</summary>

원본 dump는 변경하지 않고 한 번만 적재한다. RDS가 private subnet에 있으므로 EKS 임시 MySQL client Pod 또는 사전에 준비한 SSM bastion에서 실행한다.

적재 전에 다음을 확인한다.

- `user`, `product` 테이블의 기존 존재 여부
- dump에 DDL이 포함됐는지 여부
- 중복 데이터 또는 중복 table 생성 가능성

적재 후 임시 Pod 또는 bastion을 즉시 제거한다.

</details>

## 채점 전 확인

- 제출값은 `application`의 `endpoint` output 그대로 사용하고 `/v1/`을 덧붙이지 않는다.
- RDS가 Multi-AZ `db.t3.micro`인지 확인한다.
- 모든 EKS node가 `t3.medium`이며 Fargate와 Lambda가 없는지 확인한다.
- user/product 목표 응답시간은 0.2초, stress는 1초다.
- `/images/<object path>` 다운로드와 product PUT 형식을 공식 정정 기준으로 확인한다.
- CloudWatch Logs, WAF sampled requests와 HPA 상태를 관찰한 근거로만 조정한다.
- 채점 스크립트 원본은 수정하지 않고 최대 3회만 실행한다.

기본 동작을 확인한다.

```bash
ENDPOINT=$(terraform -chdir=application output -raw endpoint)
curl -i "$ENDPOINT/healthcheck"
curl -i "$ENDPOINT/v1/none"
kubectl -n apdev get deploy,pod,svc,ingress,hpa,pdb
kubectl -n apdev logs deploy/user --tail=50
```

`/v1/none`은 nginx 기본 404여야 한다. WAF가 차단하면 403이 반환될 수 있으므로 정상 load test가 차단되는지도 sampled requests에서 확인한다.

<details>
<summary>EKS 인증 확인</summary>

foundation 생성 principal과 실행 principal이 다르면 `additional_cluster_admin_principal_arns`에 영구 IAM role ARN을 넣고 foundation에 반영한다.

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region ap-northeast-2 --name apdev-eks-cluster
kubectl auth can-i '*' '*' --all-namespaces
```

</details>

## 역순 정리

producer와 채점 트래픽을 먼저 중지한다.

1. `monitoring`
2. `application`
3. `foundation`

```powershell
terraform -chdir=extensions/monitoring destroy -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=application destroy -input=false "-var-file=../terraform.tfvars"
terraform -chdir=foundation destroy -input=false "-var-file=../terraform.tfvars"
```

application을 먼저 제거해야 nginx Service가 만든 NLB와 ENI가 VPC보다 먼저 삭제된다.
foundation의 S3와 ECR은 실습 정리를 위해 `force_destroy`를 사용한다.
Secrets Manager secret은 즉시 삭제하며 customer-managed KMS key는 만들지 않는다.

각 state가 비었는지 확인하고 EKS, RDS, NLB, ECR, S3, NAT/EIP, ENI, CloudFront, WAF, CloudWatch 및 IAM 잔존 여부를 실제 AWS API에서 확인한다. 다른 응시자의 리소스는 삭제하지 않는다.

## 입력 자산 및 관련 문서

- `assets/shared/Dockerfile.binary`: 공식 바이너리 공용 패키징
- [assets/README.md](assets/README.md): 자산 배치 원칙
- [REQUIREMENTS.md](REQUIREMENTS.md): 문제·채점 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 미확인 정정과 오류 후보

특정 root module만 사용하는 입력은 `assets/foundation/`, `assets/application/`, `assets/extensions/<이름>/`에 둔다. 공식 바이너리는 수정하지 않으며 이미지, ZIP, plan 파일은 `assets/`에 커밋하지 않는다.
