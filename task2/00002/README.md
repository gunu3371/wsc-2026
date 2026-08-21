# 2과제 00002 Terraform 구현

과제번호 `00002`의 2과제만 다룬다. 네 서비스는 서로 다른 리전과 수명주기를 가지며 각각 독립된 root module과 state를 사용한다.

## 기준 자료 및 확인 상태

- 기존 문제·채점 자료: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/2과제/`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/2과제 00002/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

수정본의 공식 게시 여부는 로그인 전용 채널에서 추가 확인해야 한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상과 AWS CLI v2
- 네 대상 리전의 리소스를 만들 수 있는 AWS 자격 증명
- 실제 `terraform.tfvars`, state, plan, 생성 ZIP과 비밀값은 Git에 커밋하지 않는다.

### 변수 파일 준비

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 검증과 적용

각 module은 독립적이다. 필요한 module만 선택해 실행할 수 있다.

```powershell
terraform -chdir=workflow init -input=false
terraform -chdir=workflow validate
terraform -chdir=workflow plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=analytics init -input=false
terraform -chdir=analytics validate
terraform -chdir=analytics plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=cloud-event init -input=false
terraform -chdir=cloud-event validate
terraform -chdir=cloud-event plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=msk init -input=false
terraform -chdir=msk validate
terraform -chdir=msk plan -input=false "-var-file=../terraform.tfvars"
```

모든 plan을 검토한 후 필요한 module만 적용한다.

```powershell
terraform -chdir=workflow apply "-var-file=../terraform.tfvars"
terraform -chdir=analytics apply "-var-file=../terraform.tfvars"
terraform -chdir=cloud-event apply "-var-file=../terraform.tfvars"
terraform -chdir=msk apply "-var-file=../terraform.tfvars"
```

## 구조와 state 경계

| root module | 리전 | 주요 단계 |
| --- | --- | --- |
| `workflow` | ap-southeast-1 | S3, Lambda, Step Functions, S3 trigger |
| `analytics` | ap-northeast-2 | VPC, Kinesis, EC2, ALB, Flink |
| `cloud-event` | eu-west-1 | EC2, CloudTrail, SNS, Lambda, EventBridge, Config |
| `msk` | ap-northeast-1 | VPC, MSK, S3 destination, producer, consumer |

같은 디렉터리의 모든 `.tf` 파일은 하나의 root module로 평가된다. 네 module 사이에는 Terraform output 전달 관계가 없다.

## 변수와 output 전달

- `config.common`: 과제 공통값
- `config.modules.workflow`: Workflow 입력
- `config.modules.analytics`: Analytics 입력
- `config.modules.cloud_event`: Cloud Event 입력
- `config.modules.msk`: MSK 입력

모든 module이 과제 루트의 같은 `terraform.tfvars`를 읽지만 각자 필요한 객체만 사용한다.

## 수정본 반영사항

| 모듈 | 확인할 값 |
| --- | --- |
| Workflow | Lambda `wsc2026-student-score-function` |
| Analytics | systemd unit `app`, IAM role `wsc2026-analytics-ec2-role` |
| Cloud Event | 복구 결과 확인 전 최소 60초 대기 |
| MSK | projection 결과의 `sensorId`, ISO 8601 KST `timestamp` |

## 채점 전 확인

- 대상 계정과 module별 리전을 다시 확인한다.
- 원본 채점 스크립트는 수정하지 않는다.
- MSK 수정 PDF의 잘못된 student-score 버킷명은 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)의 기록을 따른다.
- producer, 이벤트 소스와 테스트 데이터가 채점 전 준비됐는지 확인한다.

## 역순 정리

module 간 종속성은 없지만 각 module 내부의 producer와 이벤트 소스를 먼저 중지한다.

```powershell
terraform -chdir=msk destroy "-var-file=../terraform.tfvars"
terraform -chdir=cloud-event destroy "-var-file=../terraform.tfvars"
terraform -chdir=analytics destroy "-var-file=../terraform.tfvars"
terraform -chdir=workflow destroy "-var-file=../terraform.tfvars"
```

정리 후 S3 객체, CloudWatch Logs, 네트워크 리소스, IAM 및 KMS 삭제 예약 상태를 각 리전의 AWS API로 확인한다.

## 입력 자산 및 관련 문서

- `assets/workflow/`: Lambda와 S3 테스트 데이터
- `assets/analytics/`: EC2 애플리케이션과 user-data
- `assets/cloud-event/`: remediation Lambda
- `assets/msk/`: producer, consumer, 제공 바이너리와 user-data
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 문서·스크립트 불일치

공식 원본은 수정하지 않는다. Terraform 생성 ZIP은 각 module에만 만들고 `assets/`에 커밋하지 않는다.
