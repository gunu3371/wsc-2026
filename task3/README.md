# 3과제 Terraform 구현

3과제는 공통 과제 하나뿐이므로 과제번호 하위 디렉터리 없이 `task3/`를 과제 루트로 사용한다. core/stress EKS node group, ALB 기반 API, RDS, S3 이미지 제공, 단일 CloudFront endpoint, WAF와 경량 Fluent Bit 모니터링을 구성한다.

## 기준 자료 및 확인 상태

- 문제지: `../2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_문제지_v1.0.0.pdf`
- 채점기준표: 같은 경로의 `2026년_전국대회_3과제_채점기준표_v1.0.0.pdf`
- 운영 참고: `../docs/2026-07-31 직종협의회.md`

로그인이 필요한 공식 게시물의 마지막 댓글과 최신 첨부는 확인하지 못했다. 공식 정정이 배포되면 [REQUIREMENTS.md](REQUIREMENTS.md)와 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)를 먼저 다시 대조한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm 3
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
2. foundation output을 `terraform.tfvars`에 기록
3. `extensions/additional-infrastructure`
4. additional-infrastructure output을 `terraform.tfvars`에 기록
5. `extensions/image-build`
6. 공식 바이너리 S3 업로드와 CodeBuild 실행
7. `application`
8. `extensions/additional-application`
9. `extensions/monitoring`

```powershell
terraform -chdir=foundation fmt -check
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars" -out=foundation.tfplan
terraform -chdir=foundation apply foundation.tfplan
terraform -chdir=foundation output
```

`config.outputs.foundation`을 갱신한 뒤 추가 workload의 ECR과 전용 node group을 먼저 적용한다. `additional_workloads = {}`이면 이 state는 리소스를 만들지 않는다.

```powershell
terraform -chdir=extensions/additional-infrastructure fmt -check
terraform -chdir=extensions/additional-infrastructure init -input=false
terraform -chdir=extensions/additional-infrastructure validate
terraform -chdir=extensions/additional-infrastructure plan -input=false "-var-file=../../terraform.tfvars" -out=additional-infrastructure.tfplan
terraform -chdir=extensions/additional-infrastructure apply additional-infrastructure.tfplan
terraform -chdir=extensions/additional-infrastructure output
```

`config.outputs.additional_infrastructure`를 갱신한 뒤 image-build extension을 적용하고 공식 바이너리 이미지를 생성한다.

```powershell
terraform -chdir=extensions/image-build fmt -check
terraform -chdir=extensions/image-build init -input=false
terraform -chdir=extensions/image-build validate
terraform -chdir=extensions/image-build plan -input=false "-var-file=../../terraform.tfvars" -out=image-build.tfplan
terraform -chdir=extensions/image-build apply image-build.tfplan
```

CodeBuild가 성공한 뒤 기본 application을 적용한다.

```powershell
terraform -chdir=application fmt -check
terraform -chdir=application init -input=false
terraform -chdir=application validate
terraform -chdir=application plan -input=false "-var-file=../terraform.tfvars" -out=application.tfplan
terraform -chdir=application apply application.tfplan
terraform -chdir=application output -raw endpoint
```

추가 workload가 있으면 같은 ALB에 경로를 등록한다. 기본 application이 namespace, database secret, Metrics Server와 AWS Load Balancer Controller를 먼저 생성해야 한다.

```powershell
terraform -chdir=extensions/additional-application fmt -check
terraform -chdir=extensions/additional-application init -input=false
terraform -chdir=extensions/additional-application validate
terraform -chdir=extensions/additional-application plan -input=false "-var-file=../../terraform.tfvars" -out=additional-application.tfplan
terraform -chdir=extensions/additional-application apply additional-application.tfplan
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
│   ├── additional-infrastructure/ # 추가 ECR과 전용 EKS node group
│   ├── additional-application/  # 추가 workload와 ALB 경로
│   ├── image-build/             # CodeBuild, binary input S3, build log
│   └── monitoring/              # Fluent Bit, alarm, CloudWatch dashboard
├── assets/
│   ├── application/
│   │   └── aws-load-balancer-controller-iam-policy.json
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
| 추가 ECR·전용 node group | `extensions/additional-infrastructure/01-ecr.tf`, `02-node-groups.tf` |
| 공식 binary image build/push | `extensions/image-build/01-codebuild.tf` |
| AWS Load Balancer Controller·workload·HPA/PDB | `application/01-platform.tf`, `02-workloads.tf` |
| ALB·access log·endpoint·이미지·WAF | `application/03-routing.tf` |
| 추가 workload·ALB 경로 | `extensions/additional-application/01-workloads.tf`, `02-routing.tf` |
| Fluent Bit·로그·지표·오류 탐지 | `extensions/monitoring/01-observability.tf` |

주요 고정값은 VPC `10.30.0.0/16`, EKS EC2 `t3.medium`, 애플리케이션 TCP 8080이다. core node group은 기본 2대, `dedicated=stress:NoSchedule` taint가 있는 stress node group은 기본 1대다. RDS는 `apdev-rds-instance`, MySQL 8.0, Multi-AZ, `db.t3.micro`, gp3를 사용한다.

## 변수와 output 전달

- `config.common`: 공통값과 실제 응시자 `candidate_id`
- `config.modules`: foundation, application과 extension 직접 입력
- `config.outputs.foundation`: additional-infrastructure, image-build, application과 monitoring에 전달할 foundation output
- `config.outputs.additional_infrastructure`: image-build, additional-application과 monitoring에 전달할 추가 ECR/node group map
- `config.outputs.application`: monitoring에 전달할 ALB·CloudFront·WAF output

foundation 적용 후 다음 값을 실제 `terraform.tfvars`에 복사한다.

- `cluster_name`, `vpc_id`, `public_subnet_ids`
- `node_role_arn`, `core_node_group_name`, `stress_node_group_name`
- `database_secret_arn`
- `image_bucket_name`
- `product_pod_role_arn`
- `ecr_repository_urls`

additional-infrastructure 적용 뒤 `ecr_repository_urls`, `node_group_names`을 기록한다. application 적용 뒤 `alb_arn_suffix`, `cloudfront_distribution_id`, `waf_web_acl_name`을 `config.outputs.application`에 기록하고 monitoring을 적용한다.

`config.modules.foundation.node_groups`에서 core/stress의 `instance_types`, `capacity_type`, `disk_size`, `min/desired/max_size`를 지정한다. 문제지 요구를 보호하기 위해 `instance_types`는 `t3.medium`만 검증을 통과한다.

`config.modules.application.blocked_user_agents`에는 WAF에서 대소문자를 무시하고 완전 일치시킬 User-Agent를 최대 50개까지 지정한다. `blocked_user_agent_action`은 기본 `BLOCK`이며 사전 관찰 시에는 `COUNT`로 바꾼다. 빈 목록이면 사용자 정의 UA 규칙을 만들지 않는다.

`config.modules.extensions.additional_workloads`의 map key가 workload 이름이다. 항목별 `binary_object_key`, `route_path`를 지정하면 ECR, taint가 있는 전용 node group, Deployment, Service, HPA, PDB와 공유 ALB rule이 생성된다. `environment`는 바이너리에 일반 환경변수를 전달하고, `use_database = true`이면 기본 application의 `database` Secret에서 `MYSQL_*` 값을 주입한다. `node_group`과 `resources` 객체에서 인스턴스 수·디스크·Pod 요청량을 조정할 수 있으며 인스턴스 타입은 문제지 기준에 따라 `t3.medium`만 허용한다. 기존 `/v1/user`, `/v1/product`, `/v1/stress`, `/healthcheck`, `/images` 경로는 사용할 수 없다.

후속 module은 foundation state를 직접 읽지 않는다.

## CodeBuild 공식 바이너리 image build/push

`extensions/image-build`는 입력 S3 버킷, CodeBuild 프로젝트, 최소 IAM과 CloudWatch build log를 독립 state로 관리한다. Terraform은 `assets/shared/Dockerfile.binary`와 변수로 생성한 build target manifest를 입력 버킷에 올린다. 공식 linux/amd64 바이너리는 저장소에 복사하지 않고 지급받은 원본을 각 `binary_object_key`에 업로드한다.

```powershell
$BuildBucket = terraform -chdir=extensions/image-build output -raw source_bucket_name
$BuildProject = terraform -chdir=extensions/image-build output -raw project_name

aws s3 cp <user-binary> "s3://$BuildBucket/binaries/user"
aws s3 cp <product-binary> "s3://$BuildBucket/binaries/product"
aws s3 cp <stress-binary> "s3://$BuildBucket/binaries/stress"
# additional_workloads.example.binary_object_key가 binaries/example인 경우
aws s3 cp <example-binary> "s3://$BuildBucket/binaries/example"

$BuildId = aws codebuild start-build --region ap-northeast-2 --project-name $BuildProject --query "build.id" --output text
aws codebuild batch-get-builds --region ap-northeast-2 --ids $BuildId --query "builds[0].{Status:buildStatus,Logs:logs.deepLink}" --output table
```

CodeBuild는 privileged Docker 환경에서 manifest의 기본·추가 target을 순회해 `linux/amd64` 이미지를 만들고 각 ECR에 push한다. 기본 앱은 `config.modules.extensions.image_build.image_tag`, 추가 앱은 해당 `additional_workloads.<name>.image_tag`를 사용한다. 기본 앱 입력 object key, build image, compute type과 로그 보존 기간은 `image_build`에서 변경한다. 바이너리와 Dockerfile 입력은 기본 1일 뒤 S3 lifecycle로 제거된다.

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
- user/product와 AWS Load Balancer Controller는 core node에, stress는 전용 stress node에만 배치됐는지 확인한다.
- 추가 workload가 각자의 taint/label 전용 node group에만 배치되고 ALB 경로가 정상인지 확인한다.
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

`/v1/none`은 ALB fixed response 404여야 한다. WAF가 차단하면 403이 반환될 수 있으므로 정상 load test가 차단되는지도 sampled requests에서 확인한다.

ALB access log는 `application` 소유 S3 버킷의 `alb/AWSLogs/...`에 저장되고 1일 뒤 만료된다. 현재 고정된 AWS Provider 5.x는 ALB의 신규 CloudWatch Logs 직접 전송을 지원하지 않으므로 대시보드는 `AWS/ApplicationELB`의 p95/p99와 상태 코드 지표를 사용한다. Fluent Bit은 `apdev` namespace의 바이너리 stdout/stderr만 `/aws/eks/<cluster>/application`으로 전송하며 전체 Container Insights 애드온은 설치하지 않는다.

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
2. `additional-application`
3. `application`
4. `image-build`
5. `additional-infrastructure`
6. `foundation`

```powershell
terraform -chdir=extensions/monitoring destroy -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/additional-application destroy -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=application destroy -input=false "-var-file=../terraform.tfvars"
terraform -chdir=extensions/image-build destroy -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/additional-infrastructure destroy -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=foundation destroy -input=false "-var-file=../terraform.tfvars"
```

additional-application과 application을 먼저 제거해야 AWS Load Balancer Controller가 만든 rule, ALB, target group과 ENI가 node group/VPC보다 먼저 삭제된다.
image-build를 제거하기 전에 실행 중인 CodeBuild build가 없는지 확인한다.
foundation의 S3와 ECR은 실습 정리를 위해 `force_destroy`를 사용한다.
Secrets Manager secret은 즉시 삭제하며 customer-managed KMS key는 만들지 않는다.

각 state가 비었는지 확인하고 EKS, RDS, ALB, target group, ECR, S3, NAT/EIP, ENI, CloudFront, WAF, CloudWatch 및 IAM 잔존 여부를 실제 AWS API에서 확인한다. 다른 응시자의 리소스는 삭제하지 않는다.

## 입력 자산 및 관련 문서

- `assets/shared/Dockerfile.binary`: 공식 바이너리 공용 패키징
- [assets/README.md](assets/README.md): 자산 배치 원칙
- [REQUIREMENTS.md](REQUIREMENTS.md): 문제·채점 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 미확인 정정과 오류 후보

특정 root module만 사용하는 입력은 `assets/foundation/`, `assets/application/`, `assets/extensions/<이름>/`에 둔다. 공식 바이너리는 수정하지 않으며 이미지, ZIP, plan 파일은 `assets/`에 커밋하지 않는다.
