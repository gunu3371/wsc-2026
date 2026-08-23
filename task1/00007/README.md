# 1과제 00007 Terraform 구현

과제번호 `00007`의 1과제만 다룬다. 과제번호 `00007`의 2과제는 제외되었으므로 별도 `task2` 구현을 두지 않는다.

## 기준 자료 및 확인 상태

- 문제지·채점·제공 파일: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/01_최종제출본/2026_전국기능경기대회_과제/1과제/`
- 재변환 수정본: `2026년 전국기능경기대회 hwp 수정본/1과제 00007/`
- 최종 수정 후보: `1과제 촤종수정본/day1-07-release-candidate-tp.pdf`, `day1-07-release-candidate-marking.pdf`, `d1-07-mark.sh`, `asset/`
- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/00_최종본_안내.txt`

최종 수정 후보 PDF 전 페이지와 `d1-07-mark.sh`를 2026-08-23에 다시 대조했다. 폴더명이 release candidate이므로 공식 게시물의 최종 승인 여부는 별도로 확인해야 한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm
- `ap-northeast-2` 대상 AWS 자격 증명
- private EKS API에 접근 가능한 `addons` 실행 환경
- 실제 선수등번호

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

`candidate_id`와 placeholder를 실제 값으로 바꾼다.

### 1. foundation

```powershell
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=foundation apply "-var-file=../terraform.tfvars"
terraform -chdir=foundation output
```

VPC, subnet, KMS, S3, DynamoDB와 ECR 출력값을 `config.outputs.foundation`에 기록한다.

### 2. 공식 book 이미지 생성

Windows에 Docker나 WSL2가 없어도 CodeBuild에서 이미지를 생성할 수 있다.

```powershell
terraform -chdir=extensions/image-build init -input=false
terraform -chdir=extensions/image-build validate
terraform -chdir=extensions/image-build plan -input=false "-var-file=../../terraform.tfvars"
terraform -chdir=extensions/image-build apply "-var-file=../../terraform.tfvars"
powershell -ExecutionPolicy Bypass -File .\Start-BookImageBuild.ps1
```

스크립트가 출력하는 digest URI를 `config.outputs.image_build.image_uri`에 기록한다. CodeBuild는 `v1.0.0`과 `latest`를 만들며 이미 고정 태그가 있으면 다시 덮어쓰지 않는다. 기존 고정 태그에 스캔 이력이 없으면 digest 기준으로 기본 스캔을 시작한다. LOW 이상 취약점이 하나라도 있거나 스캔 완료를 확인하지 못하면 스크립트가 실패한다.

### 3. cluster

```powershell
terraform -chdir=cluster init -input=false
terraform -chdir=cluster validate
terraform -chdir=cluster plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=cluster apply "-var-file=../terraform.tfvars"
terraform -chdir=cluster output
```

cluster 출력값을 `config.outputs.cluster`에 기록한다.

### 4. addons

```powershell
terraform -chdir=addons init -input=false
terraform -chdir=addons validate
terraform -chdir=addons plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=addons apply "-var-file=../terraform.tfvars"
terraform -chdir=addons output
```

## 구조와 state 경계

| root module | 역할 |
| --- | --- |
| `foundation` | VPC, endpoint, Flow Logs, KMS, S3, DynamoDB, ECR |
| `extensions/image-build` | 공식 바이너리 CodeBuild와 ECR 이미지 생성 |
| `cluster` | private EKS, KMS EBS, app/addon nodegroup |
| `addons` | 애플리케이션, Lambda, ALB, CloudFront, WAF, 감사 역할, 관측성 |

각 root module은 독립 state를 사용한다. 후속 module은 선행 state를 직접 읽지 않고 과제 루트의 단일 `terraform.tfvars`로 output을 전달받는다.

## 변수와 output 전달

- `config.common.task_id`: 과제번호 `00007`
- `config.common.candidate_id`: 실제 선수등번호
- `config.common.region`, `aws_profile`, `tags`: 모든 root module의 공통 실행 환경
- `config.outputs.foundation`: VPC, subnet, KMS, 버킷과 ECR 정보
- `config.outputs.image_build.image_uri`: 공식 이미지 digest URI
- `config.outputs.cluster`: cluster endpoint, CA와 보안 그룹

선수등번호는 감사 역할 External ID `unicorn-audit-2026<선수등번호>`와 Grafana 계정에 사용된다.

### EKS API endpoint

`config.modules.cluster`에서 EKS endpoint 접근을 제어한다. private endpoint는 항상 활성화되며 정상 구성과 채점 전에는 다음 값을 유지한다.

```hcl
eks_endpoint_public_access = false
eks_public_access_cidrs    = []
```

로컬 PC에서 임시로 접근해야 할 때만 public endpoint를 활성화한다. CIDR은 실제 공인 IP `/32`로 제한하고 `0.0.0.0/0`은 사용하지 않는다. `203.0.113.10/32`는 형식 설명용 주소다. 작업이 끝나면 두 값을 기본값으로 되돌려 cluster를 다시 적용하고 채점 전에 public endpoint가 비활성화됐는지 확인한다.

## 수정본 반영사항

| 항목 | 구현값 |
| --- | --- |
| S3 | 공식 `index.html`, `main.jpeg`, data KMS |
| ECR | scan-on-push, `IMMUTABLE_WITH_EXCLUSION`, 변경 가능한 `latest`, `v1.0.0`, 사전 스캔 확인 |
| EKS 인증 | private endpoint와 `API` 인증을 유지한다. public endpoint는 로컬 작업용 선택값이며 채점 전 비활성화한다. 최종 문제지에서 Access Entry/aws-auth 방식 강제는 삭제됨 |
| EC2 노드 태그 | launch template의 instance `Name` 태그를 app/addon 지정값으로 설정 |
| 애플리케이션 | 공식 바이너리와 최소 정적 sleep만 포함한 distroless Debian 13 digest, ClusterIP 채점 Service, NodePort ALB bridge |
| CloudFront·S3 | `/health`를 ALB VPC origin으로 전달, OAC bucket policy에 Distribution `AWS:SourceArn` 적용 |
| 종료 처리 | grace period 45초, 최소 정적 `/bin/sleep 15` |
| WAF | XSS와 50회/60초 rate limit 모두 `403 Request blocked by Unicorn WAF`; 최종 스크립트의 동시 부하와 재시도에 대응 |
| 로그 | `/health` 제외, 정확히 `client_ip,method,path,status_code,timestamp` |
| Grafana | 선수별 계정, 지정된 5개 패널, 전용 `unicorn-grafana-alb` |

## 채점 전 확인

- ECR에 `latest`, `v1.0.0`이 있고 `v1.0.0` 스캔 이력이 존재하며 LOW 이상 취약점 수가 모두 0이어야 한다.
- app node가 2개 이상이고 `unicorn-book-app-deploy`가 2/2 Ready여야 한다.
- `unicorn-book-app-svc`는 ClusterIP여야 한다.
- CloudFront `/health`, POST `/v1/book`, Lambda GET이 성공해야 한다.
- WAF XSS 응답과 rate-limit 응답의 코드·본문을 확인한다.
- CloudWatch 최신 애플리케이션 로그의 키가 정확히 다섯 개인지 확인한다.
- Grafana 5개 패널에 No Data가 없어야 한다.
- 원본 `mark.sh`는 수정하지 않고 최대 3회만 실행한다.

최종 `d1-07-mark.sh`의 rate-limit 검사는 60초를 기다린 뒤 250개 요청을 동시 배치로 보내고 최대 12회 재시도한다. Terraform의 rule 값은 문제지대로 `limit=50`, `evaluation_window_sec=60`을 유지한다.

## 역순 정리

1. `addons`
2. `cluster`
3. `extensions/image-build`
4. `foundation`

```powershell
terraform -chdir=addons destroy "-var-file=../terraform.tfvars"
terraform -chdir=cluster destroy "-var-file=../terraform.tfvars"
terraform -chdir=extensions/image-build destroy "-var-file=../../terraform.tfvars"
```

마지막으로 `config.modules.foundation.cleanup_mode = true`로 변경한다.

```powershell
terraform -chdir=foundation apply "-var-file=../terraform.tfvars"
terraform -chdir=foundation destroy "-var-file=../terraform.tfvars"
```

## 입력 자산과 관련 문서

- `assets/foundation/`: 공식 `index.html`, `main.jpeg`
- `assets/shared/book-image/`: 공식 `book` 바이너리와 최소 컨테이너 Dockerfile
- `assets/addons/`: Lambda, Fluent Bit 변환과 Grafana dashboard
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 최신성 및 충돌 기록

공식 원본은 수정하지 않는다. `terraform.tfvars`, state, plan, `.terraform/`, 생성 ZIP과 자격 증명은 Git에 커밋하지 않는다.
