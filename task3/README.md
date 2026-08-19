# 2026년 전국대회 클라우드컴퓨팅 제3과제

이 디렉터리는 제3과제의 EKS 기반 API, RDS, S3 이미지 제공, 단일 CloudFront endpoint, WAF 및 모니터링을 Terraform으로 구성합니다. 문제지의 비공개 동적 트래픽을 특정 값으로 하드코딩하지 않고, WAF 표본 요청·컨테이너 로그·Container Insights를 보고 경기 중 조정할 수 있게 설계했습니다.

## 기준 자료

- `../2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_문제지_v1.0.0.pdf`
- `../2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_채점기준표_v1.0.0.pdf`
- 운영 참고: `../docs/2026-07-31 직종협의회.md`

로그인이 필요한 공식 게시물의 마지막 댓글·최신 첨부는 이 작업 환경에서 확인하지 못했습니다. 공식 정정이 배포되면 `REQUIREMENTS.md`와 `ERROR_CANDIDATES.md`부터 다시 대조해야 합니다.

## 구조와 state 경계

```text
task3/
├── foundation/                  # VPC, EKS, EC2 node group, RDS, ECR, S3, IAM
├── application/                 # ingress, 3개 workload, HPA/PDB, CloudFront, WAF
├── extensions/
│   └── monitoring/              # CloudWatch Observability addon, alarms, dashboard
├── assets/
│   └── shared/
│       └── Dockerfile.binary    # 공식 x86 바이너리 패키징용
├── REQUIREMENTS.md
└── ERROR_CANDIDATES.md
```

`foundation`, `application`, `extensions/monitoring`은 각각 별도 root module이며 state를 공유하지 않습니다. 필요한 값만 `terraform output`에서 다음 module의 변수로 전달합니다. 각 root module 안의 모든 `.tf` 파일은 파일명과 관계없이 하나의 root module로 함께 평가됩니다.

의존 순서는 다음과 같습니다.

```text
foundation -> 공식 바이너리 이미지 build/push -> application -> monitoring
```

| 문제 단계 | Terraform 파일 |
|---|---|
| 공통 계정·리전·태그 | `foundation/00-common.tf`, `application/00-common.tf` |
| VPC/2-AZ 네트워크 | `foundation/01-network.tf` |
| EKS IAM | `foundation/02-iam.tf` |
| EKS/EC2 t3.medium | `foundation/03-cluster.tf` |
| MySQL RDS | `foundation/04-database.tf` |
| ECR/S3/product 권한 | `foundation/05-artifacts.tf` |
| EKS ingress·metrics-server | `application/01-platform.tf` |
| user/product/stress·HPA·PDB | `application/02-workloads.tf` |
| 단일 endpoint·이미지·WAF | `application/03-routing.tf` |
| 로그·지표·오류 탐지 | `extensions/monitoring/01-observability.tf` |

주요 고정값은 `ap-northeast-2`, VPC `10.30.0.0/16`, RDS identifier `apdev-rds-instance`, MySQL 8.0, Multi-AZ, `db.t3.micro`, gp3, EKS EC2 `t3.medium`, 애플리케이션 TCP/8080입니다. S3 bucket은 전역 유일성을 위해 응시번호와 계정 ID가 붙습니다.

## 사전 준비

- Terraform 1.8 이상
- AWS CLI 2
- Docker
- `kubectl`, Helm 3
- PowerUser 이상 수준의 대회 계정과 `ap-northeast-2` 사용 권한
- 공식 `user`, `product`, `stress` linux/amd64 바이너리 및 `load_user.dump`

현재 저장소에는 공식 3과제 바이너리와 `load_user.dump`가 없습니다. 임의 구현으로 대체하면 입력 형식과 성능 특성이 달라질 수 있으므로, 공식 지급 파일을 확보한 뒤 아래 절차를 수행합니다.

## 단일 변수 파일

`task3` 루트에서 예시 파일을 한 번만 복사한다. `config.common`은 공통값, `config.modules`는 root module 직접 입력, `config.outputs.foundation`은 foundation 적용 후 후속 모듈에 전달할 값이다. 실제 파일은 Git에 커밋하지 않는다.

```powershell
Set-Location task3
Copy-Item terraform.tfvars.example terraform.tfvars
```

## 1. foundation

PowerShell에서:

```powershell
terraform -chdir=foundation fmt -check
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false -var-file=../terraform.tfvars -out=foundation.tfplan
terraform -chdir=foundation apply foundation.tfplan
aws sts get-caller-identity
terraform -chdir=foundation output
```

CloudShell 역할이 cluster 생성 principal과 다르면 `additional_cluster_admin_principal_arns`에 IAM role ARN을 넣고 foundation에 반영합니다. 이후 CloudShell에서 다음을 검증합니다.

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region ap-northeast-2 --name apdev-eks-cluster
kubectl auth can-i '*' '*' --all-namespaces
```

## 2. 공식 바이너리 이미지 build/push

`assets/shared/Dockerfile.binary`는 공식 linux/amd64 바이너리를 변경하지 않고 Amazon Linux 2023 컨테이너에 넣습니다. 아래 `<binary>`는 실제 지급 파일명으로 바꿉니다.

```powershell
$AccountId = aws sts get-caller-identity --query Account --output text
$Registry = "$AccountId.dkr.ecr.ap-northeast-2.amazonaws.com"
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $Registry

docker build --platform linux/amd64 -f task3/assets/shared/Dockerfile.binary --build-arg BINARY=<user-binary> -t "$Registry/apdev-task3-user:latest" .
docker build --platform linux/amd64 -f task3/assets/shared/Dockerfile.binary --build-arg BINARY=<product-binary> -t "$Registry/apdev-task3-product:latest" .
docker build --platform linux/amd64 -f task3/assets/shared/Dockerfile.binary --build-arg BINARY=<stress-binary> -t "$Registry/apdev-task3-stress:latest" .

docker push "$Registry/apdev-task3-user:latest"
docker push "$Registry/apdev-task3-product:latest"
docker push "$Registry/apdev-task3-stress:latest"
```

공식 바이너리가 요구하는 S3 환경변수 이름은 문제지에 누락되어 있습니다. 구현은 호환성을 높이기 위해 `AWS_REGION`, `AWS_DEFAULT_REGION`, `S3_BUCKET`, `S3_BUCKET_NAME`을 product pod에 제공합니다. 공식 정정에서 다른 key가 지정되면 `application/02-workloads.tf`만 수정합니다.

## 3. application

foundation output의 `cluster_name`, `database_secret_arn`, `image_bucket_name`, `product_pod_role_arn`을 과제 루트 `terraform.tfvars`의 `config.outputs.foundation`에 복사합니다.

```powershell
terraform -chdir=application fmt -check
terraform -chdir=application init -input=false
terraform -chdir=application validate
terraform -chdir=application plan -input=false -var-file=../terraform.tfvars -out=application.tfplan
terraform -chdir=application apply application.tfplan
terraform -chdir=application output -raw endpoint
```

CloudFront 생성에는 시간이 걸립니다. 제출값은 `endpoint` output 그대로이며 `/v1/` 같은 경로를 붙이지 않습니다.

`load_user.dump`는 원본을 변경하지 말고 RDS에 한 번만 적재합니다. RDS는 private subnet에 있으므로 EKS의 임시 MySQL client pod나 사전에 준비한 SSM bastion에서 실행하고, 적재 후 임시 pod/bastion을 즉시 제거합니다. 먼저 `user`, `product` 테이블 존재 여부와 dump가 DDL을 포함하는지 확인하여 중복 생성하지 마십시오.

검증 예시:

```bash
ENDPOINT=$(terraform output -raw endpoint)
curl -i "$ENDPOINT/healthcheck"
curl -i "$ENDPOINT/v1/none"
kubectl -n apdev get deploy,pod,svc,ingress,hpa,pdb
kubectl -n apdev logs deploy/user --tail=50
```

`/v1/none`은 nginx 기본 404여야 합니다. WAF managed rule 또는 rate rule이 비정상 요청을 차단하면 403을 반환합니다. 정상 load test가 WAF에 의해 차단되는지 sampled requests를 반드시 확인하십시오.

## 4. monitoring extension

foundation output `node_role_name`과 `cluster_name`을 같은 `config.outputs.foundation` 구역에 넣습니다.

```powershell
terraform -chdir=extensions/monitoring fmt -check
terraform -chdir=extensions/monitoring init -input=false
terraform -chdir=extensions/monitoring validate
terraform -chdir=extensions/monitoring plan -input=false -var-file=../../terraform.tfvars -out=monitoring.tfplan
terraform -chdir=extensions/monitoring apply monitoring.tfplan
```

이 extension은 독립적으로 `plan/apply/destroy`할 수 있으며, foundation/application 리소스의 소유권을 가져가지 않습니다. CloudWatch Observability addon이 컨테이너 stdout/stderr와 Container Insights 지표를 수집합니다.

## 채점 전 점검

- 제출 endpoint가 실제 시스템과 일치하는지 확인합니다. 불일치하면 전 항목 0점입니다.
- RDS가 Multi-AZ `db.t3.micro`인지 확인합니다. 다른 DB 형태·대수는 성능/비용 항목 0점 사유입니다.
- EKS node가 모두 `t3.medium`이고 Fargate/Lambda가 없는지 확인합니다.
- user/product/stress의 availability와 목표 응답시간(user/product 0.2초, stress 1초)을 정상·부하 상황에서 측정합니다.
- `/images/<object path>` 다운로드와 product PUT 업로드 형식을 공식 정정 기준으로 확인합니다.
- CloudWatch Logs, WAF sampled requests, HPA 상태를 관찰하고 근거가 있을 때만 조정합니다.
- 채점 스크립트 원본은 수정하지 않습니다. 채점은 최대 3회 수행하고 실행 환경·오류·수정 파일을 기록합니다.

## destroy

producer와 채점 트래픽을 먼저 중지한 뒤 아래 역순으로 제거합니다.

```powershell
terraform -chdir=extensions/monitoring destroy -input=false -var-file=../../terraform.tfvars
terraform -chdir=application destroy -input=false -var-file=../terraform.tfvars
terraform -chdir=foundation destroy -input=false -var-file=../terraform.tfvars
```

application을 먼저 제거해야 nginx Service가 만든 NLB와 ENI가 VPC보다 먼저 삭제됩니다. foundation의 S3/ECR은 실습 정리를 위해 `force_destroy`이며, Secrets Manager secret은 즉시 삭제 설정입니다. 이 구현은 customer-managed KMS key를 만들지 않습니다.

destroy 후 각 state의 `terraform state list`가 비어 있는지 확인하고, AWS API에서 EKS, RDS, NLB, ECR, S3, NAT Gateway/EIP, ENI, CloudFront, WAF, CloudWatch, IAM 잔존 여부를 직접 확인합니다. 다른 응시번호·프로젝트의 리소스는 삭제하지 않습니다.

## Terraform 입력 자산

공용 공식 바이너리 패키징 Dockerfile은 `assets/shared/Dockerfile.binary`에 둔다. 향후 특정 root module만 사용하는 입력 파일은 `assets/foundation/`, `assets/application/`, `assets/extensions/<이름>/`처럼 소유 모듈 경로에 둔다.

- 공식 지급 바이너리 자체는 수정하지 않는다.
- Terraform이 생성하는 이미지·ZIP·plan 파일은 `assets/`에 두거나 커밋하지 않는다.
