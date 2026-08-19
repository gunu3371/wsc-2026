# 00002 2과제 Terraform 구현

## 기준 자료와 구성

- 원본 문제·채점 자료: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/2과제/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

각 디렉터리의 모든 `.tf` 파일은 하나의 독립 root module/state다.

| Module | 리전 | 주요 단계 |
| --- | --- | --- |
| `workflow` | ap-southeast-1 | S3, Lambda, Step Functions, S3 trigger |
| `analytics` | ap-northeast-2 | VPC, Kinesis, EC2, ALB, Flink |
| `cloud-event` | eu-west-1 | EC2, CloudTrail, SNS, Lambda, EventBridge, Config |
| `msk` | ap-northeast-1 | VPC, MSK, S3 destination, producer, consumer |

이 모듈들은 서로 리전과 수명주기가 달라 state를 공유하지 않는다.

## Terraform 입력 자산

입력 자산은 과제 루트 `assets/`에서 모듈별로 관리한다.

- `assets/workflow/`: Lambda 코드와 S3 테스트 데이터
- `assets/analytics/`: EC2 애플리케이션, requirements, user-data template
- `assets/cloud-event/`: remediation Lambda 코드
- `assets/msk/`: producer/consumer 코드, 제공 바이너리와 user-data template

공식 원본 `37_클라우드컴퓨팅/...`는 수정하지 않는다. Terraform이 생성하는 ZIP은 각 module에만 생성하며 `assets/`에 커밋하지 않는다.

## 단일 변수 파일과 실행

과제 루트에서 `Copy-Item terraform.tfvars.example terraform.tfvars`를 한 번 실행한다. 네 서비스는 `config.modules`에서 각자의 입력만 사용하며 선행 output 의존성이 없다.

```powershell
terraform -chdir=workflow init -input=false
terraform -chdir=workflow validate
terraform -chdir=workflow plan -input=false -var-file=../terraform.tfvars
terraform -chdir=analytics plan -input=false -var-file=../terraform.tfvars
terraform -chdir=cloud-event plan -input=false -var-file=../terraform.tfvars
terraform -chdir=msk plan -input=false -var-file=../terraform.tfvars
```

모든 plan 검토 후에만 사용자 요청에 따라 apply한다. `workflow`, `analytics`, `cloud-event`, `msk`는 서로 독립적으로 plan/apply/destroy할 수 있다.

## 채점과 정리

원본 채점 스크립트는 수정하지 않고 CloudShell에서 대상 리전·계정을 확인한 후 실행한다. 정리 시에는 각 모듈의 producer와 이벤트 소스를 먼저 중지하고, 해당 module에서 `terraform destroy`를 실행한다. S3 객체·CloudWatch log·KMS 삭제 예약 상태를 AWS API로 확인한다.
