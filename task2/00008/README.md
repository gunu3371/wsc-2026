# 2과제 00008 Terraform 구현

과제번호 `00008`의 2과제를 독립 서비스와 단계별 SQS/EKS root module로 구성한다.

## 기준 자료 및 확인 상태

- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00008/00_최종본 안내.txt`
- 기존 문제·채점·스크립트: 같은 경로의 `01_최종제출본/national-skills-v7/2과제/`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/2과제 00008/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

수정 문제지는 기존본과 내용이 같다. 수정 채점지는 9쪽에서 15쪽으로 확장되어 검증 명령과 합격 조건이 구체화됐다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm, `jq`, `curl`
- `ap-northeast-2`, `us-west-2` 등 module별 대상 리전 권한
- ECR에 push할 실제 worker 이미지

### 변수 파일 준비

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 독립 서비스 검증

```powershell
terraform -chdir=cloud-event init -input=false
terraform -chdir=cloud-event validate
terraform -chdir=cloud-event plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=documentdb init -input=false
terraform -chdir=documentdb validate
terraform -chdir=documentdb plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=lattice init -input=false
terraform -chdir=lattice validate
terraform -chdir=lattice plan -input=false "-var-file=../terraform.tfvars"
```

### SQS/EKS 검증과 적용 순서

1. `sqs-eks/infra`
2. infra output을 `terraform.tfvars`에 기록
3. `sqs-eks/addons/controllers`
4. `sqs-eks/addons/workloads`

```powershell
terraform -chdir=sqs-eks/infra init -input=false
terraform -chdir=sqs-eks/infra validate
terraform -chdir=sqs-eks/infra plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=sqs-eks/infra apply "-var-file=../../terraform.tfvars"
terraform -chdir=sqs-eks/infra output

terraform -chdir=sqs-eks/addons/controllers init -input=false
terraform -chdir=sqs-eks/addons/controllers validate
terraform -chdir=sqs-eks/addons/controllers plan -input=false "-var-file=../../../terraform.tfvars"
terraform -chdir=sqs-eks/addons/controllers apply "-var-file=../../../terraform.tfvars"

terraform -chdir=sqs-eks/addons/workloads init -input=false
terraform -chdir=sqs-eks/addons/workloads validate
terraform -chdir=sqs-eks/addons/workloads plan -input=false "-var-file=../../../terraform.tfvars"
terraform -chdir=sqs-eks/addons/workloads apply "-var-file=../../../terraform.tfvars"
```

독립 서비스는 plan을 검토한 뒤 필요한 module만 적용한다.

```powershell
terraform -chdir=cloud-event apply "-var-file=../terraform.tfvars"
terraform -chdir=documentdb apply "-var-file=../terraform.tfvars"
terraform -chdir=lattice apply "-var-file=../terraform.tfvars"
```

## 구조와 state 경계

| 범위 | root module | 주요 리소스 |
| --- | --- | --- |
| 독립 서비스 | `documentdb` | VPC, DocumentDB, Secrets Manager, EC2 |
| 독립 서비스 | `lattice` | 2개 VPC, EC2, VPC Lattice |
| 독립 서비스 | `cloud-event` | CloudTrail, EventBridge, SNS, Lambda |
| SQS/EKS 기반 | `sqs-eks/infra` | VPC, EKS, Fargate, SQS, ECR, IAM |
| SQS/EKS controller | `sqs-eks/addons/controllers` | KEDA, Karpenter, CoreDNS |
| SQS/EKS workload | `sqs-eks/addons/workloads` | worker, ScaledObject, NodePool |
| 선택 extension | `sqs-eks/extensions/grading-bastion` | 필요할 때만 만드는 SSM 베스천 |

각 디렉터리는 별도 state를 사용한다. SQS/EKS는 반드시 `infra → controllers → workloads` 순서로 적용한다.

## 변수와 output 전달

독립 서비스는 자신의 `config.modules` 구역만 사용한다. SQS/EKS는 infra 적용 후 다음 output을 `config.outputs.sqs_eks_infra`에 복사한다.

```powershell
terraform -chdir=sqs-eks/infra output
```

`controllers`, `workloads`, 선택적 `grading-bastion`은 같은 output 객체를 입력으로 사용하고 infra state를 직접 읽지 않는다.

<details>
<summary>선택적 grading-bastion 검증</summary>

```powershell
terraform -chdir=sqs-eks/extensions/grading-bastion init -input=false
terraform -chdir=sqs-eks/extensions/grading-bastion validate
terraform -chdir=sqs-eks/extensions/grading-bastion plan -input=false "-var-file=../../../terraform.tfvars"
terraform -chdir=sqs-eks/extensions/grading-bastion apply "-var-file=../../../terraform.tfvars"
```

필요할 때만 적용하고 채점 또는 진단이 끝나면 즉시 destroy한다.

</details>

## 수정본 반영사항

| 항목 | 조건 |
| --- | --- |
| DocumentDB | 암호화, 백업, KMS, raw endpoint hostname, BSON date, index와 TTL |
| Lattice | service EC2 public IP 금지, TCP 8080을 managed prefix list에서만 허용 |
| SQS | Visibility Timeout 30초 이상 |
| KEDA | min 0, max 6, polling 10초, cooldown 30초, queue length 2, `aws-eks` |
| Scaling | 메시지 12개 후 180초 안에 worker Pod와 Ready Karpenter node 증가 |

## 채점 전 확인

- ECR에 실제 worker 이미지가 존재하는지 확인한다.
- 원본 `asgmt2_module1_check.sh`~`asgmt2_module4_check.sh`는 수정하지 않는다.
- 수정 PDF의 스마트 따옴표가 포함된 명령은 복사하지 않고 원본 스크립트의 ASCII 명령을 사용한다.
- 상세 문자 오류는 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)를 확인한다.

## 역순 정리

CloudTrail과 SQS producer를 먼저 중지한다.

```powershell
terraform -chdir=sqs-eks/addons/workloads destroy "-var-file=../../../terraform.tfvars"
terraform -chdir=sqs-eks/addons/controllers destroy "-var-file=../../../terraform.tfvars"
terraform -chdir=sqs-eks/extensions/grading-bastion destroy "-var-file=../../../terraform.tfvars"
```

해당 module의 `cleanup_mode = true`를 실제 `terraform.tfvars`에 반영한 뒤 기반과 독립 서비스를 정리한다.

```powershell
terraform -chdir=sqs-eks/infra destroy "-var-file=../../terraform.tfvars"
terraform -chdir=cloud-event destroy "-var-file=../terraform.tfvars"
terraform -chdir=lattice destroy "-var-file=../terraform.tfvars"
terraform -chdir=documentdb destroy "-var-file=../terraform.tfvars"
```

정리 후 모든 state와 EKS, VPC, EC2/ENI, NAT/EIP, ECR, SQS, DocumentDB, Lattice, CloudTrail, Lambda, IAM, CloudWatch 및 KMS 상태를 확인한다.

## 입력 자산 및 관련 문서

- `assets/cloud-event/`
- `assets/documentdb/`
- `assets/lattice/`
- `assets/sqs-eks/addons/workloads/`
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 문서·스크립트 불일치
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md): 시행착오와 정리 기록

공식 원본은 수정하지 않는다. Lambda ZIP 등 생성 산출물은 각 module에만 두고 `assets/`에 커밋하지 않는다.
