# 00007 2과제 Terraform 구현

## 기준 자료와 구성

- 원본 문제·채점 자료: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/01_최종제출본/2026_전국기능경기대회_과제/2과제/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

각 디렉터리의 모든 `.tf` 파일은 하나의 독립 root module/state다.

| Module | 리전 | 주요 기능 |
| --- | --- | --- |
| `cdn` | us-east-1 | S3 정적 콘텐츠, CloudFront와 edge function |
| `nosql` | ap-southeast-1 | NoSQL, Lambda, EC2 애플리케이션 |
| `o11y` | ap-northeast-1 | EKS 기반 Loki, OpenTelemetry, Grafana 관측성 |
| `scaling` | ap-northeast-2 | EKS, KEDA, Karpenter 기반 자동 확장 |

## Terraform 입력 자산

입력 자산은 과제 루트 `assets/`에서 모듈별로 관리한다.

- `assets/cdn/`: HTML과 CloudFront function JavaScript
- `assets/nosql/`: Lambda·애플리케이션·user-data
- `assets/o11y/`: Loki, OpenTelemetry, Grafana 설정과 컨테이너 입력
- `assets/scaling/`: 워커 애플리케이션과 Dockerfile

공식 원본은 수정하지 않는다. Lambda ZIP 같은 Terraform 생성 산출물은 `assets/`에 저장하거나 커밋하지 않는다.

## 단일 변수 파일과 실행

과제 루트에서 `Copy-Item terraform.tfvars.example terraform.tfvars`를 한 번 실행한다. `cdn`, `nosql`, `o11y`, `scaling`은 같은 파일의 서로 다른 `config.modules` 구역을 사용한다.

```powershell
terraform -chdir=cdn init -input=false
terraform -chdir=cdn validate
terraform -chdir=cdn plan -input=false -var-file=../terraform.tfvars
terraform -chdir=nosql plan -input=false -var-file=../terraform.tfvars
terraform -chdir=o11y plan -input=false -var-file=../terraform.tfvars
terraform -chdir=scaling plan -input=false -var-file=../terraform.tfvars
```

모듈은 독립적으로 plan/apply/destroy한다. EKS API 접근이 필요한 `o11y`와 `scaling`은 먼저 기반 EKS와 인증 정보를 준비하고, Kubernetes·Helm 리소스를 AWS 기반 리소스보다 먼저 제거한다.

## 채점과 정리

채점 스크립트는 원본을 수정하지 않고 CloudShell에서 실행한다. destroy 전에는 CloudFront 또는 워크로드 등 producer를 먼저 중지하고, S3 객체·CloudWatch log·EKS 외부 리소스·KMS 삭제 예약 상태를 실제 AWS API로 확인한다.
