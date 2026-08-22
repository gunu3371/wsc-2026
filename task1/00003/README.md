# 1과제 00003 Terraform 구현

과제번호 `00003`의 1과제만 다룬다. `platform → image-build → addons → delivery` 순서로 적용하며 각 디렉터리는 별도 Terraform state를 사용한다.

## 기준 자료 및 확인 상태

- 문제지·채점·배포 파일: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003/01_최종제출본/61회 전국기능경기대회/1과제/`
- 재변환 수정본: `2026년 전국기능경기대회 hwp 수정본/1과제 00003/`
- 최종 release candidate: `1과제 촤종수정본/day1-03-release-candidate-tp.pdf`, `day1-03-release-candidate-marking.pdf`, `d1-03-mark.sh`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

최종 release candidate PDF와 같은 폴더의 채점 스크립트를 2026-08-23에 기존 자료 및 현재 구현과 대조했다. 로그인 전용 공식 게시물의 마지막 댓글과 최신 첨부는 확인하지 못했다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm
- `ap-northeast-2` 대상 AWS 자격 증명
- private EKS API에 접근 가능한 `addons` 실행 환경
- 실제 선수 비번호와 S3 버킷용 영문 소문자 네 자리

과제 루트에서 예시 파일을 복사하고 `candidate_id`, `candidate_letters`와 placeholder를 실제 값으로 바꾼다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 1. platform

VPC, KMS, DynamoDB, ECR, EKS, S3와 Lambda를 만든다.

```powershell
terraform -chdir=platform init -input=false
terraform -chdir=platform validate
terraform -chdir=platform plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=platform apply "-var-file=../terraform.tfvars"
terraform -chdir=platform output
```

출력값을 `config.outputs.platform`에 복사한다.

### 2. 공식 book 이미지 생성

CodeBuild와 빌드 입력을 만든다. Windows에 Docker나 WSL2가 없어도 된다.

```powershell
terraform -chdir=extensions/image-build init -input=false
terraform -chdir=extensions/image-build validate
terraform -chdir=extensions/image-build plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/image-build apply "-var-file=../../terraform.tfvars"
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1
```

마지막에 출력되는 `...wsc2026-book-ecr@sha256:...` 값을 `config.outputs.image_build.image_uri`에 기록한다. 이미 `v1.0.0`이 있으면 고정 태그를 덮어쓰지 않고 기존 digest를 사용한다. 기존 이미지에 스캔 이력이 없으면 스크립트가 digest 기준으로 기본 스캔을 시작하며 HIGH/CRITICAL 결과가 있거나 완료되지 않으면 실패한다. Dockerfile을 변경해 다시 빌드해야 할 때는 immutable `v1.0.0` 이미지를 명시적으로 삭제한 뒤 스크립트를 재실행한다.

현재 `v1.0.0`을 새 Dockerfile로 교체할 때만 다음 순서로 실행한다. `batch-delete-image`는 기존 이미지를 삭제하므로 repository와 tag를 다시 확인한다.

```powershell
terraform -chdir=extensions/image-build apply "-var-file=../../terraform.tfvars"
aws ecr batch-delete-image --region ap-northeast-2 --repository-name wsc2026-book-ecr --image-ids imageTag=v1.0.0
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1
```

### 3. addons

애플리케이션, ALB Controller, Grafana, Prometheus, Alertmanager와 Fluent Bit을 만든다.

```powershell
terraform -chdir=addons init -input=false
terraform -chdir=addons validate
terraform -chdir=addons plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=addons apply "-var-file=../terraform.tfvars"
terraform -chdir=addons output -raw alb_hostname
```

ALB hostname을 `config.outputs.addons.alb_hostname`에 기록한다.

### 4. delivery

CloudFront, WAF와 OAC 전용 S3 bucket policy를 만든다.

```powershell
terraform -chdir=delivery init -input=false
terraform -chdir=delivery validate
terraform -chdir=delivery plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=delivery apply "-var-file=../terraform.tfvars"
terraform -chdir=delivery output -raw cloudfront_domain
```

## 구조와 state 경계

| root module | 역할 |
| --- | --- |
| `platform` | VPC, NAT, KMS, DynamoDB, ECR, EKS, S3, Lambda |
| `extensions/image-build` | 공식 바이너리 CodeBuild와 ECR `v1.0.0` 생성 |
| `addons` | Kubernetes 애플리케이션, ALB, 관측성, CoreDNS |
| `delivery` | CloudFront, WAF, OAC와 S3 bucket policy |
| `extensions/grading-bastion` | 실제 필요할 때만 사용하는 선택적 SSM 베스천 |

`delivery`를 후단 state로 둬서 `platform`의 CloudFront가 아직 생성되지 않은 ALB 주소를 요구하던 순환 절차를 제거했다.

## 변수와 output 전달

- `config.common.task_id`: 과제번호 `00003`
- `config.common.candidate_id`: 실제 선수 비번호
- `config.common.candidate_letters`: S3 이름용 영문 소문자 네 자리
- `config.common.region`, `aws_profile`, `tags`: 모든 root module의 공통 실행 환경
- `config.outputs.platform`: platform 출력
- `config.outputs.image_build.image_uri`: ECR digest URI
- `config.outputs.addons.alb_hostname`: ALB DNS 이름

후속 root module은 선행 state를 직접 읽지 않는다. `terraform output` 결과를 과제 루트의 실제 `terraform.tfvars`에 명시적으로 복사한다.

### EKS API endpoint

`config.modules.platform`에서 EKS endpoint 접근을 제어한다. private endpoint는 항상 활성화되며 정상 구성과 채점 전에는 다음 값을 유지한다.

```hcl
eks_endpoint_public_access = false
eks_public_access_cidrs    = []
```

로컬 PC에서 임시로 접근해야 할 때만 public endpoint를 활성화한다. CIDR은 실제 공인 IP `/32`로 제한하고 `0.0.0.0/0`은 사용하지 않는다. `203.0.113.10/32`는 형식 설명용 주소다. 작업이 끝나면 두 값을 기본값으로 되돌려 platform을 다시 적용하고 채점 전에 public endpoint가 비활성화됐는지 확인한다.

## 수정본 반영사항

| 항목 | 구현값 |
| --- | --- |
| DynamoDB | PITR 35일, Pod 역할 `PutItem`, Lambda 역할 `Query`, 동일 권한의 resource policy |
| ECR | `MUTABLE_WITH_EXCLUSION`, `v1*`, 이미지 `v1.0.0` |
| S3 | `wsc2026-static-<영문4자리>-<선수 비번호>-bucket` |
| 애플리케이션 | 공식 바이너리, 스캔 가능한 distroless Debian 13 digest 이미지, `/booking` → `/v1/book` rewrite |
| CoreDNS | `wsc2026.skills.local`과 기존 `cluster.local` 병행 |
| 관측성 | dashboard, CloudWatch datasource, log metric과 5개 점수 대상 alert |
| CDN | S3만 캐시, ALB와 Lambda 캐시 비활성화 |

최종 문제지에는 `HighLatency`가 남아 있지만 최종 채점 PDF와 `d1-03-mark.sh`는 점수 대상에서 제외한다. 스크립트가 만드는 `latency-gen`은 트래픽 패널 확인용으로만 취급한다. 자세한 내용은 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)를 따른다.

## 채점 전 확인

- ECR에는 `v1.0.0`만 존재하고 스캔 결과에 High/Critical 취약점이 없어야 한다.
- DynamoDB PITR의 `RecoveryPeriodInDays`가 `35`인지 확인한다.
- Pod 역할과 Lambda 역할은 customer-managed 또는 inline policy 여부와 관계없이 각각 `dynamodb:PutItem`, `dynamodb:Query`만 필요한 범위로 허용해야 한다.
- `wsc2026-book-deploy`가 2/2 Ready인지 확인한다.
- ALB 직접 요청은 차단되고 CloudFront `/booking`, `/v1/book`이 성공해야 한다.
- CloudFront의 SQLi·XSS 요청과 60초 동안 200회를 넘긴 요청은 실제 HTTP `403`을 반환해야 한다.
- Grafana의 모든 패널과 로그에 빈값이 없어야 한다.
- 공식 `mark.sh`가 만든 임시 부하 Pod는 채점 후 삭제한다.

선택적 베스천이 실제 필요한 경우에만 다음 root module을 별도로 적용한다.

```powershell
terraform -chdir=extensions/grading-bastion plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/grading-bastion apply "-var-file=../../terraform.tfvars"
```

## 역순 정리

1. 적용했다면 `extensions/grading-bastion`
2. `delivery`
3. `addons`
4. `extensions/image-build`
5. `platform`

```powershell
terraform -chdir=extensions/grading-bastion destroy "-var-file=../../terraform.tfvars"
terraform -chdir=delivery destroy "-var-file=../terraform.tfvars"
terraform -chdir=addons destroy "-var-file=../terraform.tfvars"
terraform -chdir=extensions/image-build destroy "-var-file=../../terraform.tfvars"
```

마지막으로 `config.modules.platform.cleanup_mode = true`로 바꾸고 보호 리소스를 정리한다.

```powershell
terraform -chdir=platform apply "-var-file=../terraform.tfvars"
terraform -chdir=platform destroy "-var-file=../terraform.tfvars"
```

## 입력 자산과 관련 문서

- `assets/platform/`: 공식 정적 웹 파일과 Lambda 소스
- `assets/shared/book-image/`: 공식 `book` 바이너리와 최소 컨테이너 Dockerfile
- `assets/addons/`: dashboard, alert와 Fluent Bit 변환 파일
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 공식 자료 불일치
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md): 배포·채점 기록

공식 원본은 수정하지 않는다. `terraform.tfvars`, state, plan, `.terraform/`, 생성 ZIP과 자격 증명은 Git에 커밋하지 않는다.
