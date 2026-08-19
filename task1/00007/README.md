# 00007 Terraform 구현 안내

## 기준 자료

- 최종 문제·채점·제공 파일: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/01_최종제출본/2026_전국기능경기대회_과제/`
- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00007/00_최종본_안내.txt` (기준일 2026-07-28, 마지막 첨부 2026-06-14)
- 참고: `docs/2026-07-31 직종협의회.md`

최신성 판단과 로그인 제한은 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)에 기록한다.

## 구조와 state 경계

| 범위 | root module | 역할 |
| --- | --- | --- |
| 1과제 기반 | `task1/foundation` | VPC, KMS, 데이터/네트워크 |
| 1과제 클러스터 | `task1/cluster` | EKS 제어 영역·노드 그룹 |
| 1과제 워크로드 | `task1/addons` | Kubernetes, Helm, 앱·관측성 |
| 2과제 | `task2/nosql`, `cdn`, `scaling`, `o11y` | 각 독립 root module |

단일-state 레거시 구현은 제거했으며, 신규 적용과 관리는 위 분리 root module만 사용한다. 주요 1과제 리전은 `ap-northeast-2`, VPC CIDR은 `10.97.0.0/16`이다.

## 단일 변수 파일과 실행 순서

과제 루트에서 `Copy-Item terraform.tfvars.example terraform.tfvars`를 한 번 실행한다. `config.common`은 과제 공통값, `config.modules`는 직접 입력, `config.outputs`는 선행 root module의 output이다. 이미지에는 tag가 아닌 실제 digest URI를 사용한다.

```powershell
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false -var-file=../terraform.tfvars
# foundation 적용 후 outputs.foundation을 갱신한다.
terraform -chdir=cluster plan -input=false -var-file=../terraform.tfvars
# cluster 적용 후 outputs.cluster를 갱신한다.
terraform -chdir=addons plan -input=false -var-file=../terraform.tfvars
```

## 실행·채점·정리

1과제는 `foundation → cluster → addons` 순서다. addons는 private EKS API에 접근 가능한 CloudShell에서 foundation/cluster output과 `app_image`을 전달해 실행한다. 제공 Dockerfile·Python·HTML은 `assets/`에서 그대로 사용한다. 원본 `mark.sh`, `mark1.sh`~`mark4.sh`는 수정하지 않고 CloudShell에서 최대 3회만 실행·수정한다.

삭제는 `addons → cluster → foundation` 순서이며 모든 명령에 `-var-file=../terraform.tfvars`를 전달한다. 2과제는 각 독립 module을 제거한다. 데이터 생산자를 먼저 중지하고 AWS API로 S3/CloudWatch/EKS/ENI/NAT/EIP/ELB/IAM/KMS alias의 잔존 여부 및 KMS 삭제 예약일을 확인한다.

## Terraform 입력 자산

Terraform 입력 자산은 과제 루트 `assets/`에서 관리한다.

- `foundation`은 `assets/foundation/index.html`을 사용한다.
- `addons`는 `assets/addons/`의 Dockerfile, 애플리케이션과 Lambda 소스를 사용한다.
- 공식 배포 자산은 원본 폴더에서 수정하지 않고, Terraform용 사본을 이동할 때만 hash를 대조한다. Terraform이 생성하는 ZIP은 `assets/`에 넣지 않는다.
