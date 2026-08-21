# 2과제 00007 Terraform 구현

과제번호 `00007`의 2과제를 네 개의 독립 서비스 root module로 구성한다.

## 기준 자료 및 확인 상태

- 기존 문제·채점 자료: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/01_최종제출본/2026_전국기능경기대회_과제/2과제/`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/2과제 00007/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

수정본의 공식 게시 여부와 기존 스크립트의 문자 오류는 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)에 기록한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm, `jq`, `curl`
- 각 module 리전에 대한 AWS 권한
- scaling worker 이미지와 o11y 컨테이너 입력 자산

### 변수 파일 준비

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 검증과 적용

각 module은 독립적으로 실행한다.

```powershell
terraform -chdir=cdn init -input=false
terraform -chdir=cdn validate
terraform -chdir=cdn plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=nosql init -input=false
terraform -chdir=nosql validate
terraform -chdir=nosql plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=o11y init -input=false
terraform -chdir=o11y validate
terraform -chdir=o11y plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=scaling init -input=false
terraform -chdir=scaling validate
terraform -chdir=scaling plan -input=false "-var-file=../terraform.tfvars"
```

검토가 끝난 module만 적용한다.

```powershell
terraform -chdir=cdn apply "-var-file=../terraform.tfvars"
terraform -chdir=nosql apply "-var-file=../terraform.tfvars"
terraform -chdir=o11y apply "-var-file=../terraform.tfvars"
terraform -chdir=scaling apply "-var-file=../terraform.tfvars"
```

`o11y`와 `scaling`의 Kubernetes·Helm 작업은 각 EKS API에 접근 가능한 실행 환경에서 수행한다.

## 구조와 state 경계

| root module | 리전 | 주요 기능 |
| --- | --- | --- |
| `cdn` | us-east-1 | S3 정적 콘텐츠, CloudFront, edge function |
| `nosql` | ap-southeast-1 | NoSQL, Lambda, EC2 애플리케이션 |
| `o11y` | ap-northeast-1 | EKS, Loki, OpenTelemetry, Grafana |
| `scaling` | ap-northeast-2 | EKS, KEDA, Karpenter 자동 확장 |

각 디렉터리는 자체 state를 사용한다. `o11y`와 `scaling`의 Kubernetes·Helm 리소스는 해당 module의 AWS 기반 리소스보다 먼저 제거해야 한다.

## 변수와 output 전달

- `config.common`: 과제번호와 공통값
- `config.modules.cdn`, `nosql`, `o11y`, `scaling`: module별 직접 입력

네 module 사이에는 선행 output 전달 관계가 없다. 같은 변수 파일에서 각자의 입력 객체만 읽는다.

## 수정본 반영사항

| 항목 | 확인 내용 |
| --- | --- |
| CDN | `skillsphone-cdn-ab-distribution`은 Distribution Comment |
| Scaling | Pod와 Node의 scale-out·scale-in이 모두 2분 이내 발생 |
| 시간 | UTC 또는 KST 모두 허용 |
| O11y | Loki query URL과 option 사이에 정상 ASCII 공백 사용 |

실제 AWS 부하 시험 전에는 KEDA와 Karpenter의 시간을 추측으로 변경하지 않는다.

## 채점 전 확인

- 원본 `mark1.sh`~`mark4.sh`는 수정하지 않는다.
- scaling 시험에서는 Pod와 Node의 각 전환 시간을 별도로 기록한다.
- 수정 PDF의 Loki 명령을 사용한다. 기존 `mark4.sh`의 NBSP는 오류 후보로 취급한다.
- CloudFront, Loki, EKS 외부 리소스와 worker 이미지가 준비됐는지 확인한다.

## 역순 정리

각 module의 producer와 Kubernetes 외부 리소스를 먼저 중지한다.

```powershell
terraform -chdir=scaling destroy "-var-file=../terraform.tfvars"
terraform -chdir=o11y destroy "-var-file=../terraform.tfvars"
terraform -chdir=nosql destroy "-var-file=../terraform.tfvars"
terraform -chdir=cdn destroy "-var-file=../terraform.tfvars"
```

정리 후 S3, CloudWatch Logs, EKS, ELB, ENI 및 KMS 예약 상태를 실제 AWS API로 확인한다.

## 입력 자산 및 관련 문서

- `assets/cdn/`: HTML과 CloudFront function JavaScript
- `assets/nosql/`: Lambda, 애플리케이션과 user-data
- `assets/o11y/`: Loki, OpenTelemetry, Grafana 구성
- `assets/scaling/`: worker 애플리케이션과 Dockerfile
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 시간 및 문자 오류 기록

공식 원본은 수정하지 않는다. Terraform 생성 ZIP 등 산출물은 `assets/`에 저장하지 않는다.
