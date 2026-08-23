# 클라우드컴퓨팅 과제 Terraform 작업 지침

이 문서는 저장소의 클라우드컴퓨팅 과제를 Terraform으로 조사·구현·검증·채점·정리할 때 적용하는 공통 지침이다. 과제번호와 구조를 추측하지 말고 현재 체크아웃된 저장소와 대상 과제의 최신 공식 자료를 기준으로 작업한다. 다른 과제 구현과 `docs/2026-07-31 직종협의회.md`는 참고 자료이며, 이후 배포된 공식 공지와 정정 자료가 항상 우선한다.

## 1. 작업 시작과 허용 범위

1. 사용자 요청에서 대상 task, 과제번호와 작업 단계를 확인한다. 단계는 조사, 문서화, 구현, 로컬 검증, AWS 적용, 채점, 정리로 구분한다.
2. 저장소 루트에서 `git status --short`를 확인한다. 기존 수정과 새 파일은 사용자 작업으로 간주하고 요청과 무관한 변경을 수정·삭제·포맷하지 않는다.
3. `rg --files`와 디렉터리 조회로 실제 과제, 원본 자료, Terraform root module, README와 채점 자료를 찾는다. 다른 과제의 이름·리전·계정별 값·네트워크 구성을 복사하지 않는다.
4. 사용자가 “plan까지만” 요청하면 `terraform apply`, `terraform destroy`, AWS CLI 변경 명령과 채점 스크립트를 실행하지 않는다.
5. 실제 AWS `apply`는 사용자가 명시적으로 요청한 경우에만 실행한다. 조사·구현·로컬 검증 요청은 AWS 변경 권한을 포함하지 않는다.
6. 정리는 사용자가 요청한 대상 과제와 이번 작업에서 생성한 리소스로만 제한한다. 이름, 태그 또는 state 소유권이 불명확하면 삭제하지 않는다.

## 2. 공식 자료 선택과 요구사항 대조

### 2.1 자료 우선순위

대상 과제의 원본은 일반적으로 `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-<과제번호>/`에 있다. 실제 경로와 파일을 먼저 확인하고 다음 순서로 요구사항을 판단한다.

1. 마이스터넷 등 공식 채널의 오류 정정과 변경 공지
2. 최신 과제 문제지 PDF
3. 최신 채점 기준 PDF와 실제 채점 스크립트
4. 공식 배포 파일과 안내 문서
5. HWP/HWPX 자료
6. 직종협의회 메모와 다른 과제 구현

같은 종류의 파일이 여러 개이면 문서 내부 버전, 작성일, 최종본 안내, 공식 게시물 수정일과 마지막 첨부 댓글 작성일을 비교한다. 저장소 수집일은 원본 발행일이나 최신성의 근거로 사용하지 않는다.

로그인이 필요한 공식 댓글·첨부는 가능한 인증된 환경에서 마지막 댓글과 최신 첨부까지 확인한다. 접근할 수 없다면 공개 검색만으로 “정정 없음” 또는 “최신 확인 완료”라고 단정하지 않는다. 확인 시각, 접근 제한, 확인 범위와 추가 확인 대상을 오류 후보 문서와 완료 보고에 기록한다. 협의회 메모의 72시간 답변 원칙은 기대 시간일 뿐 자동 승인 기준이 아니다.

### 2.2 구현 전 대조표

문제지의 각 단계에 대해 다음 항목을 표로 정리한 뒤 구현한다.

- 페이지와 문항
- 리전, 가용 영역 수와 CIDR
- 리소스 이름, 태그와 네트워크 연결
- 포트, 프로토콜과 경로
- 런타임, 버전과 암호화
- 입력·출력 위치와 공식 배포 자산
- 대응하는 채점 항목과 채점 스크립트 검사값

문제지와 채점 자료가 다르면 가능한 범위에서 둘 다 만족시킨다. 명확히 충돌하거나 문제지 밖의 추가 요구로 보이는 내용은 숨은 정답으로 단정하지 않는다.

### 2.3 오류 후보

오류 후보는 원본을 수정하지 않고 과제 루트의 `ERROR_CANDIDATES.md` 또는 별도 텍스트 문서에 기록한다. 문서 머리에는 재확인일, 대조한 원본의 버전·날짜, 공식 채널 확인 범위와 접근하지 못한 범위를 적는다. 각 항목은 다음 필드를 사용한다.

- `상태`: `미확인`, `유지`, `해소` 중 하나
- `페이지/문항`
- `현재 문구`
- `오류라고 판단한 이유`
- `제안 변경 문구`
- `영향받는 채점 항목`

최신 문제지, 채점 기준, 실제 채점 스크립트, 공식 Markdown·코드를 함께 대조한다. AWS 콘솔 표시명과 API 식별자 차이처럼 서비스 명칭 문제일 수 있으면 AWS 공식 문서도 확인한다. 단순 모호성, 문서 간 충돌과 채점에 영향 없는 오타를 같은 수준의 확정 오류로 표현하지 않는다.

공식 정정으로 해소된 항목은 즉시 삭제하지 않는다. 먼저 `해소(정정일·정정 문구·첨부명)`로 기록하고, 새 전체교체본 반영 후 문제지·채점 기준·스크립트·구현이 일치하는지 재검증한 다음 제거한다.

## 3. 현재 구조와 Terraform 경계

### 3.1 과제 인벤토리

다음 표는 이 문서의 최신 정비 시점에 확인한 구조다. 작업할 때 다시 조회하며, 표와 실제 저장소가 다르면 공식 자료와 현재 파일을 기준으로 표도 갱신한다.

| 과제 루트 | root module/state 경계 |
|---|---|
| `task1/00002` | `foundation`, `application`, `extensions/image-build`, 선택적 `extensions/grading-bastion` |
| `task1/00003` | `platform`, `extensions/image-build`, `addons`, `delivery`, 선택적 `extensions/grading-bastion` |
| `task1/00007` | `foundation`, `extensions/image-build`, `cluster`, `addons` |
| `task2` (과제번호 `00002`) | 독립 서비스 `workflow`, `analytics`, `msk` |
| `task3` | `foundation`, `application`, `extensions/monitoring` |

`task1`은 과제번호 하위 디렉터리를 사용한다. `task2`는 과제번호 `00002`만 남아 `task2/` 자체가 과제 루트이며, 제외된 `00007` 구현은 유지하지 않는다. `task3`도 현재 단일 공통 과제이므로 `task3/` 자체가 과제 루트다. 새 공식 과제가 구조를 변경하면 기존 예시를 억지로 적용하지 않는다.

### 3.2 root module과 state 분리

- 같은 디렉터리의 모든 `.tf`는 하나의 root module/state로 평가된다. 단계별 파일 분리는 가독성을 위한 것이며 state 분리는 디렉터리 경계로 만든다.
- 함께 생성·변경·삭제되는 리소스는 같은 root module에 둔다. 수명주기, 권한, provider 접근 방식 또는 독립 삭제 요구가 다를 때만 state를 나눈다.
- VPC, IAM, KMS, EKS 같은 공유 기반과 Kubernetes/Helm처럼 cluster API가 필요한 구성을 가능한 별도 root module로 둔다.
- 독립 서비스가 여러 개인 `task2`는 서비스별 root module을 유지한다. 모든 과제를 `foundation/application` 이름으로 강제하지 않는다.
- 추가 요구는 가능한 `extensions/<추가과제명>`에 둔다. extension은 기존 리소스 소유권을 가져오거나 같은 리소스를 중복 선언하지 않으며 단독 `plan`, `apply`, `destroy`가 가능해야 한다.
- 여러 `enable_*` 조건을 기존 module에 누적하기보다 독립 extension을 우선한다. 반드시 원자적으로 생성·삭제돼야 할 때만 feature flag를 사용한다.
- `grading-bastion`은 필요한 경우에만 만드는 독립 extension이다.

이미 적용된 리소스는 구조 정리만을 위해 이동하지 않는다. 주소 이동이 꼭 필요하면 `moved` block 또는 검증된 `terraform state mv` 계획을 사용하고, plan에서 불필요한 destroy/create가 0건인지 확인한다.

### 3.3 파일 역할과 내부 module

신규 root module은 현재 과제의 명명과 수명주기에 맞추되 파일 역할을 다음처럼 분리한다.

- `00-common.tf`: 계정·리전 data source와 공통 locals
- `00-inputs.tf`: 과제 루트의 `config`를 module별 local로 투영하는 입력 처리
- `versions.tf`: Terraform/provider 버전과 provider 설정
- `variables.tf`: 입력 변수만
- `outputs.tf`: 출력만
- 번호가 붙은 `.tf`: 문제지 단계별 리소스

기존 module의 `main.tf`는 구조 정리만을 위해 분해하지 않는다. 새 module에 provider, 변수, data source, 리소스와 output을 모두 담은 단일 `main.tf`를 만들지 않는다. 두 곳 이상에서 반복되고 인터페이스가 안정된 구성만 과제 루트의 `modules/`로 추출하며 작은 rule까지 과도하게 모듈화하지 않는다. child module은 backend를 선언하지 않고 provider configuration도 가급적 소유하지 않는다.

### 3.4 root module 간 값 전달

- root module 사이에는 VPC ID, subnet ID, cluster name, endpoint처럼 필요한 최소 output만 전달한다.
- 과제 루트에는 `config.common`, `config.modules`, `config.outputs` 구조의 단일 `terraform.tfvars.example`만 둔다.
- 선행 module 적용 후 `terraform output` 결과를 실제 `terraform.tfvars`의 해당 `config.outputs` 객체에 기록한다. placeholder에는 output 이름과 조회 명령을 주석으로 설명한다.
- 후속 module은 선행 module의 로컬 state 파일을 직접 읽지 않는다.
- root module 사이에서 local backend 또는 상대 state 경로를 사용하는 `terraform_remote_state`를 만들지 않는다.
- endpoint와 CA처럼 AWS API에서 조회 가능한 값은 적절한 AWS data source로 재조회할 수 있다.
- 같은 task의 EKS root module은 `eks_endpoint_public_access`와 `eks_public_access_cidrs` 입력명을 공통으로 사용한다. private endpoint는 항상 활성화하고 public endpoint는 기본적으로 비활성화한다. 임시로 열 때는 실제 접속 IP의 `/32` CIDR만 허용하며 채점 전에 다시 비활성화한다.

## 4. 자산과 구현 규칙

### 4.1 Terraform 입력 자산

- Lambda 소스, 웹 자산, 컨테이너 파일, 사용자 데이터, 테스트 데이터와 템플릿은 과제 루트의 `assets/` 아래에 둔다.
- 기본 경로는 `<과제루트>/assets/<root-module-경로>/...`이다. 신규 중첩 module에도 디렉터리 경로를 그대로 반영한다.
- 둘 이상의 root module이 실제로 공유하는 자산만 `assets/shared/`에 둔다.
- root module 내부에 새로운 `assets/`, `lambda/` 또는 루트 단독 소스 파일을 두지 않는다.
- root module이 다른 root module 소유 자산을 참조하지 않게 한다.
- 실행 중 생성되는 ZIP, plan, cache와 build 산출물은 `assets/`에 넣지 않는다.

공식 원본 폴더의 배포 자산은 이동하거나 수정하지 않는다. Terraform용 자산을 과제 디렉터리 안에서 옮길 때는 이동 전후 Git blob hash 또는 SHA-256으로 동일성을 확인한다. 바이너리, 이미지, 샘플 데이터와 Lambda 코드를 임의 대체하지 않는다.

### 4.2 리소스 구현

- 리전, CIDR, 가용 영역 수, 포트, 경로, 이름, 버전, 암호화와 태그는 최신 문제지와 채점 자료의 정확한 값을 따른다.
- 계정 ID, 파티션과 caller ARN처럼 환경마다 다른 값은 data source로 얻는다.
- 과제번호가 이름에 포함되면 `task_id` 같은 변수의 기본값 또는 예시를 대상 번호와 일치시킨다.
- 전역 고유 이름은 문제의 명명 규칙을 해치지 않는 범위에서만 계정 ID나 과제번호를 덧붙인다.
- 가능한 리소스에 `Project`, `TaskId`, `ManagedBy = Terraform` 같은 공통 식별 태그를 적용한다.
- provider 수명주기와 참조 관계를 사용하고 `depends_on`을 남발하지 않는다.
- 실습용 S3 버킷은 요구에 반하지 않을 때 `force_destroy = true`를 고려한다. 계속 쓰이는 버킷은 producer를 먼저 중지한 뒤 비운다.
- 대회 계정은 root가 아닐 수 있다. 권한 부족을 임의 IAM 확대나 root 전용 작업으로 우회하지 않는다.
- Amazon Q CLI, Amazon Q Developer, Kiro 등 대회에서 허용되지 않은 도구를 전제로 구현하거나 문서화하지 않는다.
- 협의회에서 언급한 추가 과제 예시는 확장 가능한 구조의 근거일 뿐 확정 문제나 정답이 아니다.

변경 후 깨진 한글, 잘못된 따옴표, 보이지 않는 제어 문자와 잘린 HCL block을 확인한다. Terraform과 Markdown은 UTF-8로 저장한다.

## 5. README와 변수 파일

각 과제 루트 README는 UTF-8 한국어로 작성하고 실제 구조에 맞춰 다음을 포함한다.

- 사용한 원본 문제지·채점 자료의 상대 경로와 버전
- root module별 구조, state 경계와 의존 관계
- 문제 단계와 `.tf` 파일 대응표
- 리전, 주요 CIDR과 고정 리소스 이름
- 사전 준비와 도구 버전
- 단일 `terraform.tfvars.example`의 `config.common/modules/outputs` 설명
- root module별 `-var-file` 실행 방법
- `assets/` 소유 경로와 공식 원본 비수정 원칙
- `init`, `fmt`, `validate`, `plan`, `apply` 순서와 image build/push 등 중간 절차
- 채점 환경·방법과 전제 조건
- 정확한 destroy 순서와 잔존 리소스 확인 방법
- extension 독립 `plan/apply/destroy` 방법
- KMS처럼 즉시 삭제되지 않는 리소스의 동작

README 명령은 표시한 디렉터리에서 그대로 실행 가능해야 한다. 저장소 루트에서 실행하는 예시는 다음과 같다.

```powershell
terraform -chdir=foundation plan -input=false -var-file=../terraform.tfvars
terraform -chdir=extensions/monitoring plan -input=false -var-file=../../terraform.tfvars
```

PowerShell에서는 `-var-file=...` 전체를 큰따옴표로 감싼다. PowerShell과 WSL/Bash 명령을 섞지 말고 실행 환경을 표시한다. root module 내부에 별도 tfvars 예시를 만들지 않으며 실제 `terraform.tfvars`는 커밋하지 않는다.

## 6. 로컬 Terraform 검증

각 root module을 README의 의존 순서로 검증한다. `foundation → application → extensions`는 해당 구조를 쓰는 과제의 기본 순서일 뿐이다. `task1/00003`은 `platform → extensions/image-build → addons → delivery`, `task1/00007`은 `foundation → extensions/image-build → cluster → addons` 순서이며, 서로 독립인 `task2` 서비스는 각각 별도 검증한다.

```powershell
terraform -chdir=foundation fmt -check
terraform -chdir=foundation init -input=false
terraform -chdir=foundation validate
terraform -chdir=foundation plan -input=false
```

실제 plan에는 과제 루트의 `terraform.tfvars`를 root module 깊이에 맞는 명시적 `-var-file` 인수로 전달한다.

1. 먼저 `fmt -check`로 HCL 파싱과 형식을 확인한다. 포맷 변경이 요청 범위에 포함될 때만 `terraform fmt -recursive`를 실행한다.
2. `init` 실패는 provider 버전, 네트워크 접근과 lock 파일 문제로 구분한다.
3. `validate` 오류는 파일과 줄 단위로 해결한다.
4. 모든 관련 root module의 plan이 성공하기 전에 AWS에 적용하지 않는다.
5. extension은 각각 독립 plan이 가능한지 확인한다.
6. plan에서 예상하지 않은 삭제, 다른 과제번호 리소스, 기본 VPC 변경, 주소 이동과 과도한 IAM 권한을 검토한다.

검증이 `.terraform/`, lock 파일, plan 또는 build 산출물을 만들 수 있음을 고려한다. 커밋 대상 여부를 기존 정책과 diff로 확인하며 요청과 무관한 생성물을 남기지 않는다.

## 7. AWS 적용

실제 AWS 변경은 사용자의 명시적 요청이 있을 때만 수행한다.

1. `aws sts get-caller-identity`로 계정과 caller ARN을 확인한다.
2. 각 root module의 provider 리전과 대상 과제번호를 확인한다.
3. 다른 사용자·과제 리소스와 이름 또는 태그가 겹치지 않는지 조회한다.
4. README의 의존 순서대로 기반, 애플리케이션, 필요한 extension과 데이터를 적용한다.
5. EKS, MSK, Flink, NAT Gateway 같은 장시간 리소스는 완료 상태까지 확인하고 중간 실패를 기록한다.
6. apply 뒤에는 Terraform output뿐 아니라 AWS 서비스 API로 상태와 endpoint를 검증한다.
7. 테스트 데이터와 채점 실행이 만든 객체·로그도 정리 대상으로 기록한다.

권한 부족이 발생하면 필요한 권한과 실패 명령을 보고한다. 사용자 승인 없이 권한을 확대하거나 다른 계정·리전으로 우회하지 않는다.

## 8. 채점과 수정 반복

### 8.1 사전 점검과 실행 환경

1. 대상 task와 과제번호에 정확히 대응하는 채점 스크립트를 찾는다.
2. 원본 스크립트를 읽어 shell, AWS profile/region, `jq`, `kubectl` 등 전제 조건과 파괴적 명령 유무를 확인한다.
3. 채점 스크립트는 어떤 경우에도 수정하지 않는다. 오류로 판단되면 위치, 재현 절차와 근거를 보고한다.
4. Kubernetes/EKS 채점은 원칙적으로 대상 AWS 계정의 CloudShell에서 실행한다.
5. 실행 전 caller identity, 기본 리전과 대상 cluster를 다시 확인한다.
6. 필요한 스크립트와 공식 배포 파일만 CloudShell로 옮긴다.
7. EKS는 CloudShell에서 `aws eks update-kubeconfig` 후 `kubectl` 접근이 성공하도록 미리 구성한다.

문제지가 방식을 지정하지 않았다면 IRSA, `aws-auth`, Pod Identity, Access Entry 중 하나를 정답처럼 강제하지 않고 실제 접근 성공을 기준으로 한다. Windows에서 Bash 스크립트를 사전 점검할 때는 WSL 또는 Git Bash의 경로 변환을 확인한다. 로컬 점검은 실제 채점을 대체하지 않는다.

### 8.2 채점용 베스천

Kubernetes 채점에 꼭 필요한 경우에만 대상 VPC에 `grading-bastion` extension을 미리 생성할 수 있다.

- 채점 도중 즉석 생성하지 않는다.
- 가능하면 퍼블릭 SSH 대신 Systems Manager Session Manager를 사용한다.
- SSH가 필수이면 source CIDR과 포트를 최소 범위로 제한한다.
- instance, role, instance profile, security group과 연결은 Terraform으로 관리하고 과제 태그를 적용한다.
- 채점 도구와 파일만 설치하고 자격 증명이나 비밀을 영구 저장하지 않는다.
- 다른 채점 항목의 편의를 위해 추가하지 않는다.
- 채점 후 성공 여부와 관계없이 먼저 destroy하고 실제 잔존 여부를 확인한다.

### 8.3 반복 횟수와 기록

사용자가 횟수를 지정하지 않으면 채점과 구현 수정은 최대 3회다. 각 시도마다 실행 스크립트와 대상, 실행 환경·계정·리전, 실패 항목과 오류, 원인, 수정 파일, 재검증·재적용 범위를 기록한다.

Terraform 또는 애플리케이션 구현이 원인일 때만 해당 파일을 수정하고 필요한 최소 범위에 다시 plan/apply한다. 성공하거나 3회 실패하면 반복을 끝낸다. 사용자가 성공·실패 후 정리를 요청했다면 결과와 무관하게 정리한다.

### 8.4 task3 비공개 동적 채점

- 비공개 트래픽과 점수 기준을 역추적해 특정 값만 하드코딩하지 않는다.
- CloudWatch 등 기본 관측성을 준비해 현장에서 로그와 metric으로 원인을 판별할 수 있게 한다.
- 정해지지 않은 정상 입력에도 안전하게 동작하고 명확한 오류 응답과 낮은 지연을 제공한다.
- 요구 성능을 만족하는 최소 구성을 우선하며 불필요한 상시 고비용 리소스를 늘리지 않는다.
- WAF, subscription filter, Firehose와 S3 적재는 실제 문제와 관찰된 트래픽에 근거해 선택한다.
- 빠진 명세는 합리적인 기본값과 일반 형식을 수용하고 공식 질의 후보로 기록한다.

## 9. 리소스 정리

### 9.1 destroy 순서

1. 새 데이터를 만드는 producer, CloudTrail, 이벤트 소스와 애플리케이션을 중지한다.
2. Kubernetes Service/Ingress, Helm release와 EKS 내부 리소스처럼 외부 AWS 리소스를 생성하는 항목을 먼저 제거한다.
3. `grading-bastion`과 추가 extension을 각각 제거한다.
4. 나머지는 README에 정의된 적용 순서의 정확한 역순으로 destroy한다.
5. S3 `BucketNotEmpty`가 발생하면 producer 중지를 확인하고 대상 버킷만 비운 뒤 재시도한다.
6. Terraform 밖에서 자동 생성된 log group은 이름·태그로 소유권을 확인한 뒤 삭제한다.
7. KMS key는 대상이 확실할 때만 최소 허용 대기 기간으로 삭제 예약하고 예정일을 보고한다.

destroy 오류를 state 제거로 숨기지 않는다. 실제 리소스가 사라진 것을 서비스 API로 확인한 경우에만 state 정합성을 처리한다.

### 9.2 잔존 리소스 검사

모든 사용 리전과 전역 서비스에서 다음을 확인한다.

- 각 Terraform state의 관리 리소스 수
- EC2, EBS, VPC, subnet, ENI, security group, NAT Gateway, Elastic IP
- ELB/ALB/NLB와 target group
- EKS, MSK, Kinesis/Flink, Lambda, Step Functions
- DynamoDB, S3, ECR, CloudFront
- CloudTrail, EventBridge, AWS Config, SNS, CloudWatch Log Group
- IAM role, instance profile, customer-managed policy
- KMS alias와 삭제 예약 key

Resource Groups Tagging API는 삭제된 ARN을 일시적으로 반환할 수 있다. 태깅 결과만 사용하지 말고 각 서비스 API에서 `terminated`, `deleted` 또는 `NotFound` 상태를 확인한다.

기본 VPC, 다른 과제번호, 다른 프로젝트와 사용자가 만든 리소스는 건드리지 않는다. 삭제 전에 계정 ID, 리전, 리소스 ID, 이름과 태그를 확인한다. 로컬 Terraform 소스와 README는 AWS 정리 대상이 아니며 사용자가 명시적으로 요청하지 않으면 삭제하지 않는다.

## 10. 완료 보고

완료 보고에는 요청 범위에 해당하는 항목만 포함한다.

- 수정한 파일과 구현 범위
- 사용한 공식 원본과 확인하지 못한 공식 채널 범위
- `fmt`, `init`, `validate`, `plan` 결과
- apply한 계정·리전과 결과
- 채점 시도 횟수와 최종 결과
- destroy 결과와 서비스 API 잔존 조회 결과
- 삭제 예약된 KMS key와 최종 삭제 예정일
- 실행하지 못한 항목과 이유

성공하지 않은 검증이나 접근하지 못한 자료를 완료한 것처럼 보고하지 않는다.

## 11. 최종 체크리스트

### 조사와 설계

- [ ] 대상 task와 과제번호, 사용자 허용 범위를 확인했다.
- [ ] 작업 전 Git 상태와 기존 사용자 변경을 확인했다.
- [ ] 최신 문제지, 채점 기준, 채점 스크립트와 공식 배포 자산을 대조했다.
- [ ] 저장소 수집일과 공식 자료 날짜를 구분했다.
- [ ] 로그인 전용 자료의 확인 여부와 접근 제한을 기록했다.
- [ ] 충돌·누락 명세를 원본 수정 없이 오류 후보로 기록했다.
- [ ] 단계별 요구사항 대조표를 작성했다.

### 구현과 로컬 검증

- [ ] 실제 과제 구조에 맞게 root module/state를 분리했다.
- [ ] 과제 단계와 `.tf` 파일을 대응시켰다.
- [ ] extension이 기존 소유권을 침범하지 않고 독립 동작한다.
- [ ] 공식 자산을 수정하지 않고 올바른 `assets/` 경로에서 사용했다.
- [ ] README와 예시 변수 파일을 현재 구현에 맞췄다.
- [ ] 모든 root module에서 `fmt`, `init`, `validate`, `plan`을 확인했다.
- [ ] 예상치 못한 삭제·주소 이동·과도한 권한을 검토했다.

### AWS, 채점과 정리

- [ ] 사용자 요청 범위 안에서만 AWS를 변경했다.
- [ ] 계정, caller, 리전과 리소스 소유권을 확인했다.
- [ ] 채점 스크립트 원본을 수정하지 않았다.
- [ ] 허용 횟수 안에서 채점하고 시도별 결과를 기록했다.
- [ ] CloudShell에서 필요한 EKS/Kubernetes 접근을 확인했다.
- [ ] 요청된 경우 의존 관계의 역순으로 destroy했다.
- [ ] Terraform state와 실제 AWS API를 모두 확인했다.
- [ ] 예약 삭제 리소스와 잔존 여부를 보고했다.

## 12. 저장소에 남기지 않을 파일

- `terraform.tfstate*`
- 실제 `terraform.tfvars`
- 저장된 plan 파일
- `.terraform/`
- 실행 중 생성한 ZIP과 임시 build 산출물
- AWS 자격 증명, token, private key와 비밀값

`.gitignore`에 있다는 이유만으로 민감정보 저장이 허용되는 것은 아니다. 출력이나 완료 보고에도 비밀값을 노출하지 않는다.
