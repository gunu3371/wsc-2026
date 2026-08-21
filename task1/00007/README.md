# 1과제 00007 Terraform 구현

과제번호 `00007`의 1과제만 다룬다. 2과제는 `task2/00007`에서 별도 변수 파일, state, 적용 및 정리 절차로 관리한다.

## 기준 자료 및 확인 상태

- 기존 문제·채점·제공 파일: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/01_최종제출본/2026_전국기능경기대회_과제/1과제/`
- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/00_최종본_안내.txt`
- 저장소 내 수정본: `2026년 전국기능경기대회 hwp 수정본/1과제 00007/`
- 운영 참고: `docs/2026-07-31 직종협의회.md`

최종본 안내 기준일은 2026-07-28이며 기록된 마지막 첨부는 2026-06-14다. 로그인 전용 공식 게시물의 최신 첨부 여부는 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)에 기록한다.

## 빠른 실행

### 사전 준비

- Terraform 1.8 이상, AWS CLI v2, `kubectl`, Helm
- `ap-northeast-2` 대상 AWS 자격 증명
- tag가 아닌 실제 digest 형식의 `app_image`

### 변수 파일 준비

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 검증과 적용 순서

1. `foundation`
2. foundation output을 `terraform.tfvars`에 기록
3. `cluster`
4. cluster output을 `terraform.tfvars`에 기록
5. `addons`

```powershell
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=foundation apply "-var-file=../terraform.tfvars"
terraform -chdir=foundation output

terraform -chdir=cluster init -input=false
terraform -chdir=cluster validate
terraform -chdir=cluster plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=cluster apply "-var-file=../terraform.tfvars"
terraform -chdir=cluster output

terraform -chdir=addons init -input=false
terraform -chdir=addons validate
terraform -chdir=addons plan -input=false "-var-file=../terraform.tfvars"
terraform -chdir=addons apply "-var-file=../terraform.tfvars"
```

실제 apply는 각 plan과 output 전달값을 검토한 뒤 실행한다.
`cluster`와 `addons`의 Kubernetes provider 작업은 private EKS API에 접근 가능한 실행 환경에서 수행한다.

## 구조와 state 경계

| 범위 | root module | 역할 |
| --- | --- | --- |
| 기반 | `foundation` | VPC, KMS, 데이터와 네트워크 |
| 클러스터 | `cluster` | EKS 제어 영역과 node group |
| 워크로드 | `addons` | Kubernetes, 애플리케이션, ALB, CloudFront, WAF, 관측성 |

root module마다 독립 state를 사용한다. 주요 리전은 `ap-northeast-2`, VPC CIDR은 `10.97.0.0/16`이다.

## 변수와 output 전달

- `config.common`: 과제 공통값
- `config.modules`: foundation, cluster, addons 직접 입력
- `config.outputs.foundation`: VPC, subnet, KMS 등 foundation output
- `config.outputs.cluster`: cluster 이름, endpoint, node 정보 등 cluster output

후속 module은 선행 state를 직접 읽지 않는다. 각 `terraform output` 결과를 과제 루트의 실제 `terraform.tfvars`에 복사한다.

## 수정본 반영사항

| 항목 | 값 |
| --- | --- |
| 채점 대상 Service | `unicorn-book-app-svc`, `ClusterIP` |
| ALB 연결용 Service | `unicorn-book-app-alb`, NodePort `30097` |
| Pod Identity service account | `unicorn-book-app-sa` |
| 종료 처리 | grace period 45초, preStop `sleep 15` |
| CloudFront 식별값 | Distribution Comment `unicorn-svc-cf` |
| Timestamp | UTC 또는 KST 허용 |

ALB instance target 경로는 별도 NodePort Service로 유지하고, 채점 대상 Service 형식은 수정본을 따른다.

## 채점 전 확인

- foundation과 cluster output 및 `app_image` digest가 실제 값인지 확인한다.
- `unicorn-book-app-deploy`가 2/2 Ready인지 확인한다.
- Service, probe, graceful shutdown 및 Pod Identity 값을 확인한다.
- 원본 1과제 `mark.sh`는 수정하지 않고 최대 3회만 실행한다.

## 역순 정리

1. `addons`
2. `cluster`
3. `foundation`

```powershell
terraform -chdir=addons destroy "-var-file=../terraform.tfvars"
terraform -chdir=cluster destroy "-var-file=../terraform.tfvars"
terraform -chdir=foundation destroy "-var-file=../terraform.tfvars"
```

producer를 먼저 중지한다. 정리 후 S3, CloudWatch, EKS, ENI, NAT/EIP, ELB, IAM, KMS alias 및 각 state를 실제 AWS API와 함께 확인한다.

## 입력 자산 및 관련 문서

- `assets/foundation/index.html`: foundation 정적 웹 자산
- `assets/addons/`: Dockerfile, 애플리케이션과 Lambda 소스
- [REQUIREMENTS.md](REQUIREMENTS.md): 수정본 요구사항 대조
- [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md): 최신성 및 충돌 기록

공식 배포 자산은 원본 폴더에서 수정하지 않는다. Terraform 생성 ZIP은 `assets/`에 넣지 않는다.
