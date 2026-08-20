# 00003 시행착오 및 재발 방지 기록

재확인일: 2026-08-17
대상: `00003/task1`
범위: 배포, 공식 채점, 정리 과정에서 실제로 확인한 문제와 개선 사항

## 확인된 사항

| 상태 | 상황 | 원인 | 재발 방지 |
| --- | --- | --- | --- |
| 해소 | 관측성 extension을 private EKS API에 적용·삭제하기 어려웠다. | 로컬 실행 환경은 private endpoint에 도달할 수 없었다. | CloudShell 또는 VPC 내부 관리 환경을 우선 사용한다. 임시 public endpoint가 필요하면 현재 관리 CIDR 하나만 허용하고, 작업 직후 private-only로 복구한다. |
| 해소 | `addons` state가 없어서 Kubernetes가 만든 ALB, Classic ELB, target group, 보안 그룹, IAM 역할/정책이 platform destroy 뒤에 남았다. | root module state 경계는 분리됐지만 addons state 보존·destroy 절차가 지켜지지 않았다. | addons state를 보존하고 반드시 `observability-fix → addons → platform` 순서로 destroy한다. ALB Ingress에 `Project`, `ManagedBy` 태그를 전파한다. |
| 해소 | S3 버전 객체와 ECR 이미지가 버킷·저장소 삭제를 막았다. | 일반 배포 설정은 데이터 보호를 위해 강제 삭제를 사용하지 않았다. | `cleanup_mode=true`일 때만 `force_destroy`/`force_delete`를 켜고, 파괴 작업 전에 대상 이름과 버전을 확인한다. |
| 해소 | DynamoDB 삭제 보호가 켜진 상태에서는 테이블을 삭제할 수 없었다. | `terraform destroy`는 보호 설정을 자동으로 해제하지 않는다. | 정리 시 먼저 `cleanup_mode=true`으로 apply하여 삭제 보호를 끈 뒤 destroy한다. 정상 배포 기본값은 계속 보호 활성화다. |
| 해소 | CloudFront, EKS, NAT Gateway는 삭제 시간이 길어 Terraform 실행 제한에 걸렸다. | AWS 비동기 삭제 대기 시간이 로컬 명령 제한보다 길었다. | 긴 destroy는 CloudShell/CI 등 장시간 실행 환경에서 수행하고, 중단되면 AWS API로 실제 진행 상태와 Terraform state lock을 확인한다. |
| 유지 | KMS 키는 즉시 삭제되지 않는다. | AWS 최소 삭제 대기 기간(7일). | alias와 사용 리소스를 먼저 삭제하고 삭제 예약일을 완료 보고에 기록한다. |

## 표준 정리 절차

아래 명령은 각각 해당 디렉터리에서 실행한다. `cleanup_mode`는 파괴 작업 전용이며 평상시 apply에는 사용하지 않는다.

```powershell
# 1. Kubernetes 및 Helm 리소스 제거 (state가 있는 경우)
terraform -chdir=task1/extensions/observability-fix destroy -auto-approve
terraform -chdir=addons destroy "-var-file=../terraform.tfvars"

# 2. 데이터 보호 해제 및 버킷/ECR 강제 정리 기능 반영
terraform -chdir=platform apply "-var-file=../terraform.tfvars"

# 3. 기반 인프라 제거
terraform -chdir=platform destroy "-var-file=../terraform.tfvars"
```

`addons`의 state가 없거나 destroy가 실패했을 때는 VPC ID, EKS cluster 태그, Ingress 태그로 ALB/NLB, target group, ENI, 보안 그룹, IAM 역할·정책을 **조회하여 소유권을 확인한 뒤에만** 정리한다. 다른 과제나 기본 VPC 리소스는 삭제하지 않는다.
