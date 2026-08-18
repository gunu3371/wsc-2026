# 00008 시행착오와 재발 방지

재확인일: 2026-08-17
대상: 00008 2과제 Terraform 정리 작업

## 확인된 이슈

| 상황 | 원인 | 개선 |
| --- | --- | --- |
| EKS 기반 destroy가 오래 걸림 | Fargate profile, EKS, NAT Gateway는 AWS 비동기 삭제이며 기존 Fargate profile 간 불필요한 순차 의존성이 있었음 | profile 간 의존성을 제거하고, addons를 먼저 제거한 뒤 상태를 AWS API로 확인한다. |
| ECR repository destroy가 실패할 수 있음 | immutable image가 남아 있으면 ECR 저장소 삭제가 차단됨 | `cleanup_mode`에서 `force_delete = true`를 사용한다. |
| CloudTrail S3 bucket destroy가 실패할 수 있음 | CloudTrail 로그 객체가 계속 생성되고 bucket이 비어 있지 않음 | trail을 먼저 중지하고 `cleanup_mode`에서 `force_destroy = true`를 사용한다. |
| DocumentDB destroy가 최종 스냅샷을 요구함 | 기본 `skip_final_snapshot=false`에 final snapshot identifier가 없음 | `cleanup_mode`에서 final snapshot을 생략한다. 운영용 삭제는 별도 snapshot identifier 설계가 필요하다. |
| Secrets Manager secret이 30일간 남음 | 기본 복구 대기 기간이 30일임 | `cleanup_mode`에서 `recovery_window_in_days=0`으로 즉시 삭제한다. |
| KMS 키가 즉시 삭제되지 않음 | AWS KMS는 삭제 예약만 지원함 | `cleanup_mode`는 최소 7일로 예약하고, 키 ID와 예정일을 완료 보고에 남긴다. |
| Windows에서 장시간 Terraform 실행이 중단될 수 있음 | 실행 환경의 시간 제한과 AWS 비동기 삭제 시간이 겹침 | Terraform state를 임의로 조작하지 말고, AWS API에서 실제 상태를 확인한 뒤 동일 destroy를 재실행한다. |

## 표준 정리 절차

1. CloudTrail, 메시지 producer, Kubernetes workload처럼 새 데이터를 만드는 대상을 먼저 중지한다.
2. `workloads → controllers → grading-bastion → infra` 순서로 EKS 관련 state를 제거한다.
3. 독립 모듈은 `cleanup_mode=true`을 지정해 데이터·이미지·비밀 때문에 destroy가 막히지 않게 한다.
4. 상태 파일에 남은 항목과 AWS API 결과가 일치할 때까지 재검증한다. 실제 리소스가 사라지기 전에는 state에서 제거하지 않는다.
5. KMS 삭제 예약 키는 ID와 삭제 예정일을 기록한다.
