# 1과제 00003 Terraform 구현

과제번호 `00003`의 1과제를 `platform`, `addons`, 독립 extension으로 나누어 구성한다. 각 디렉터리는 별도 Terraform state를 사용한다.

## 기준 자료 및 확인 상태

- 문제지: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003/01_최종제출본/61회 전국기능경기대회/1과제/클라우드컴퓨팅_1과제.pdf`
- 채점 자료와 `mark.sh`: 같은 경로의 `1과제/채점/`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/1과제 00003/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

수정본은 2026-08-21에 기존 PDF 및 스크립트와 대조했다. 로그인 전용 공식 게시물의 마지막 댓글과 최신 첨부는 확인하지 못했다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm, `jq`
- `ap-northeast-2` 대상 AWS 자격 증명
- 실제 `terraform.tfvars`, state, plan, 생성 ZIP과 자격 증명은 Git에 커밋하지 않는다.

### 변수 파일 준비

과제 루트 `task1/00003`에서 한 번만 실행한다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 검증과 적용 순서

1. `platform`을 적용한다.
2. `platform` output을 `terraform.tfvars`에 복사한다.
3. `addons`를 적용한다.
4. 필요한 경우 `observability-fix`를 적용한다.

```powershell
terraform -chdir=platform init -input=false
terraform -chdir=platform validate
terraform -chdir=platform plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=platform apply "-var-file=../terraform.tfvars"
terraform -chdir=platform output
```

`config.outputs.platform`을 갱신한 뒤 후속 root module을 실행한다.

```powershell
terraform -chdir=addons init -input=false
terraform -chdir=addons validate
terraform -chdir=addons plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=addons apply "-var-file=../terraform.tfvars"

terraform -chdir=extensions/observability-fix init -input=false
terraform -chdir=extensions/observability-fix validate
terraform -chdir=extensions/observability-fix plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/observability-fix apply "-var-file=../../terraform.tfvars"
```

실제 apply는 plan을 검토하고 대상 계정과 리전을 확인한 뒤 실행한다.
`addons`와 extension의 Kubernetes·Helm provider는 private EKS API에 접근 가능한 실행 환경에서 사용한다.

## 구조와 state 경계

| root module | 역할 | state |
| --- | --- | --- |
| `platform` | VPC, NAT, KMS, EKS, DynamoDB, ECR, S3, Lambda, CloudFront, WAF | 독립 |
| `addons` | Kubernetes 애플리케이션, AWS Load Balancer Controller, Helm 관측성 | 독립 |
| `extensions/observability-fix` | Grafana CloudWatch 연결, dashboard, alert, Fluent Bit 보완 | 독립 |
| `extensions/grading-bastion` | 필요할 때만 사용하는 SSM 베스천 | 독립 |

리전은 `ap-northeast-2`, VPC CIDR은 `192.168.0.0/16`이다. 같은 디렉터리의 모든 `.tf` 파일은 하나의 root module로 함께 평가된다.

## 변수와 output 전달

- `config.common`: 과제 공통값
- `config.modules`: 각 root module의 직접 입력
- `config.outputs.platform`: platform 적용 후 복사할 output

후속 module은 platform state를 직접 읽지 않는다. `terraform -chdir=platform output` 결과를 과제 루트의 실제 `terraform.tfvars`에 명시적으로 기록한다.

## 수정본 반영사항

| 구분 | 확인 내용 |
| --- | --- |
| Node | CPU, Memory, Available Nodes |
| 전체 Pod | CPU, Memory, Pending, Restarts |
| 애플리케이션 Pod | CPU, Memory, Running, Restarts, Pending |
| 트래픽 | Request Count, Response Time, Status Code, Application Logs |

`assets/addons/dashboard.json.tftpl`을 `addons`와 `observability-fix`가 공유한다.

<details>
<summary>선택적 grading-bastion 검증</summary>

실제 필요할 때만 독립 extension으로 검증하고 적용한다.

```powershell
terraform -chdir=extensions/grading-bastion init -input=false
terraform -chdir=extensions/grading-bastion validate
terraform -chdir=extensions/grading-bastion plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/grading-bastion apply "-var-file=../../terraform.tfvars"
```

사용했다면 `observability-fix`보다 먼저 destroy한다.

</details>

## 채점 전 확인

공식 `mark.sh`는 Grafana 확인 전에 다음 임시 워크로드를 만들고 약 180초 동안 데이터를 수집한다.

- `not-ready`, `error-gen`, `latency-gen`
- `crash-test`, `stress-cpu`, `stress-mem`

채점이 끝나면 해당 Pod를 삭제한다. 수정 PDF는 HighLatency Alert를 채점과 무관하다고 안내하지만 기존 스크립트에는 관련 부하와 출력이 남아 있다. 세부 불일치는 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)를 따른다.

## 역순 정리

1. 적용했다면 `grading-bastion`
2. `observability-fix`
3. `addons`
4. `platform`

```powershell
terraform -chdir=extensions/grading-bastion destroy "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/observability-fix destroy "-var-file=../../terraform.tfvars"
terraform -chdir=addons destroy "-var-file=../terraform.tfvars"
```

`config.modules.platform.cleanup_mode = true`로 변경한 뒤 platform을 정리한다.

```powershell
terraform -chdir=platform apply "-var-file=../terraform.tfvars"
terraform -chdir=platform destroy "-var-file=../terraform.tfvars"
```

정리 후 state와 실제 AWS의 EKS, VPC, ELB, ENI, NAT/EIP, S3, ECR, DynamoDB, Lambda, CloudWatch, IAM 및 KMS 예약 상태를 함께 확인한다.

## 입력 자산 및 관련 문서

- `assets/platform/`: 정적 웹 파일과 Lambda 소스
- `assets/addons/`: Grafana dashboard, alert manifest, Fluent Bit Lua 스크립트
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 공식 자료 불일치
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md): 배포·채점·정리 기록

공식 원본은 수정하지 않는다. Terraform이 생성하는 ZIP 등 산출물은 `assets/`에 넣지 않는다.
