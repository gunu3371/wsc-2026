# 00008 Terraform 구현 안내

## 기준 자료

- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00008/00_최종본 안내.txt`
- 문제지·채점지·공식 채점 스크립트: 같은 경로의 `01_최종출제본-national-skills-v7/2과제/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`
- 문서·스크립트 간 확인 사항: `ERROR_CANDIDATES.md`

## 모듈과 state 경계

| 모듈 | 경로 | 주요 리소스 |
| --- | --- | --- |
| DocumentDB | `task2/documentdb` | VPC, DocumentDB, Secrets Manager, EC2 |
| VPC Lattice | `task2/lattice` | 2개 VPC, EC2, VPC Lattice |
| Cloud Event | `task2/cloud-event` | CloudTrail, EventBridge, SNS, Lambda |
| SQS/EKS 기반 | `task2/sqs-eks/infra` | VPC, EKS, Fargate, SQS, ECR, IAM |
| SQS/EKS 컨트롤러 | `task2/sqs-eks/addons/controllers` | KEDA, Karpenter, CoreDNS 설정 |
| SQS/EKS 워크로드 | `task2/sqs-eks/addons/workloads` | worker, ScaledObject, NodePool |
| 채점용 extension | `task2/sqs-eks/extensions/grading-bastion` | 필요 시에만 생성하는 SSM 베스천 |

각 디렉터리는 독립 Terraform state를 사용한다. EKS는 `infra → controllers → workloads` 순서로 적용하고 반대 순서로 제거한다.

## 검증과 적용

각 root module에서 다음을 실행한다.

```powershell
terraform init -input=false
terraform fmt -check
terraform validate
terraform plan -input=false "-var-file=terraform.tfvars"
terraform apply -input=false "-var-file=terraform.tfvars"
```

실제 tfvars는 커밋하지 않으며, 제공된 `terraform.tfvars.example`을 복사해 사용한다.

## 정리

CloudTrail과 SQS producer를 먼저 중지한 뒤 다음 순서로 제거한다.

```powershell
terraform -chdir=task2/sqs-eks/addons/workloads destroy -auto-approve
terraform -chdir=task2/sqs-eks/addons/controllers destroy -auto-approve
terraform -chdir=task2/sqs-eks/extensions/grading-bastion destroy -auto-approve
terraform -chdir=task2/sqs-eks/infra destroy -auto-approve -var='cleanup_mode=true'
terraform -chdir=task2/cloud-event destroy -auto-approve -var='cleanup_mode=true'
terraform -chdir=task2/lattice destroy -auto-approve
terraform -chdir=task2/documentdb destroy -auto-approve -var='cleanup_mode=true'
```

`cleanup_mode=true`은 실습 정리 전용이다. ECR 이미지를 함께 삭제하고, CloudTrail S3 객체를 비우며, DocumentDB 최종 스냅샷과 Secrets Manager 복구 대기를 생략한다. DocumentDB KMS 키는 7일 삭제 예약 상태로 남으므로 최종 삭제일을 AWS API로 확인한다.

정리 후에는 모든 state의 리소스 수와 EKS, VPC, EC2/ENI, NAT/EIP, ECR, SQS, DocumentDB, VPC Lattice, CloudTrail, Lambda, IAM, CloudWatch Logs, KMS 상태를 각 서비스 API로 확인한다. 자세한 시행착오와 재발 방지책은 `LESSONS_LEARNED.md`에 기록했다.
