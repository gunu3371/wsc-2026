# 00003 Terraform 구현 및 운영 안내

## 기준 자료

- 문제지: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003/01_최종제출본/61회 전국기능경기대회/1과제/클라우드컴퓨팅 1과제.pdf`
- 채점 자료와 스크립트: 같은 경로의 `1과제/채점/`
- 오류 후보 및 공식 자료 불일치: [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)
- 배포·채점·정리 과정의 기록: [LESSONS_LEARNED.md](LESSONS_LEARNED.md)

## 구조와 state 경계

| root module | 역할 | state |
| --- | --- | --- |
| `task1/platform` | VPC, NAT, KMS, EKS, DynamoDB, ECR, S3, Lambda, CloudFront, WAF | 독립 |
| `task1/addons` | Kubernetes 애플리케이션, AWS Load Balancer Controller, Helm 관측성 구성 | 독립 |
| `task1/extensions/observability-fix` | Grafana CloudWatch 연결, 대시보드, 알림, Fluent Bit metric 보완 | 독립 |
| `task1/extensions/grading-bastion` | 채점 전용 SSM 베스천 | 독립, 필요할 때만 생성 |

같은 디렉터리의 모든 `.tf` 파일은 하나의 root module과 state를 이룬다. 각 root module의 state를 보존해야 하며, 특히 `addons` state 없이 platform을 먼저 삭제하면 Kubernetes가 생성한 ELB와 IAM 리소스가 남을 수 있다.

리전은 `ap-northeast-2`이며, VPC CIDR은 `192.168.0.0/16`이다.

## 단일 변수 파일과 배포 순서

과제 루트에서 예시를 한 번만 복사한다. `config.common`은 공통값, `config.modules`는 모듈 직접 입력, `config.outputs.platform`은 platform 적용 후 복사할 output이다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform -chdir=platform init -input=false
terraform -chdir=platform validate
terraform -chdir=platform plan -input=false -var-file=../terraform.tfvars
```

platform 적용 후 `terraform -chdir=platform output`으로 값을 확인해 같은 `terraform.tfvars`의 `outputs.platform`을 갱신한다. 이후 addons와 extension을 검증한다.

```powershell
terraform -chdir=addons plan -input=false -var-file=../terraform.tfvars
terraform -chdir=extensions/observability-fix plan -input=false -var-file=../../terraform.tfvars
terraform -chdir=extensions/grading-bastion plan -input=false -var-file=../../terraform.tfvars
```

적용 순서는 `platform → addons → observability-fix`이며, addons와 extension은 private EKS endpoint에 접근 가능한 CloudShell 또는 VPC 내부 환경에서 실행한다.

## 안전한 정리

정리 순서는 `observability-fix → addons → platform`이다. S3 버전 객체, ECR 이미지 및 DynamoDB 삭제 보호까지 처리하려면 platform에서 아래 두 단계를 모두 실행한다.

```powershell
terraform -chdir=extensions/observability-fix destroy -var-file=../../terraform.tfvars
terraform -chdir=addons destroy -var-file=../terraform.tfvars
# terraform.tfvars의 config.modules.platform.cleanup_mode를 true로 변경한 뒤 실행한다.
terraform -chdir=platform apply -var-file=../terraform.tfvars
terraform -chdir=platform destroy -var-file=../terraform.tfvars
```

`cleanup_mode` 기본값은 `false`다. `true`일 때만 DynamoDB 삭제 보호를 해제하고 S3의 모든 객체 버전 및 ECR 이미지를 제거할 수 있다. KMS 키는 AWS 정책에 따라 7일 삭제 예약 상태로 남는다. 정리 후 state, EKS/VPC/ELB/ENI/NAT/EIP, S3/ECR/DynamoDB/Lambda, CloudWatch Log Group, IAM, KMS 예약 상태를 AWS API로 교차 확인한다.

## Terraform 입력 자산

Terraform 입력 자산은 과제 루트 `assets/`에서 관리한다.

- `platform`은 `assets/platform/`의 정적 웹 파일과 Lambda 소스를 사용한다.
- `addons`와 `extensions/observability-fix`는 `assets/addons/`의 Grafana dashboard template, alert manifest, Fluent Bit Lua 스크립트를 공유한다.
- 공식 원본은 변경하지 않으며, Lambda ZIP 등 Terraform 생성 산출물은 `assets/`에 넣지 않는다.
