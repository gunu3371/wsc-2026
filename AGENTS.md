# 클라우드컴퓨팅 과제 Terraform 작업 지침

이 파일은 저장소 루트 아래의 과제번호별 과제(`00002`, `00003`, `00007`, `00008` 등)를 Terraform으로 구현·검증·채점·정리할 때 공통으로 적용한다. 특정 과제의 리소스 이름이나 아키텍처를 다른 과제에 그대로 복사하지 말고, 항상 해당 과제번호의 최신 원본 문제지, 공식 오류 정정과 채점 자료를 기준으로 작업한다. `docs/2026-07-31 직종협의회.md`의 협의 내용을 운영 참고사항으로 함께 사용하되, 이후 배포된 공식 공지와 정정 자료가 우선한다.

## 1. 기준 자료와 작업 범위

1. 작업 대상이 `<과제번호>`라면 먼저 `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-<과제번호>/` 아래와 저장소의 `docs/`를 조사한다.
2. 같은 과제의 파일이 여러 버전이면 날짜, 버전, 최종본 안내를 확인하고 가장 최신인 자료를 선택한다. 저장소 수집일, 최종본 안내의 기준일, 공식 게시물 수정일, 마지막 첨부 댓글의 작성일을 서로 다른 값으로 구분하며, 저장소에 최근 추가되었다는 이유만으로 원본도 최신이라고 판단하지 않는다.
3. 요구사항의 우선순위는 다음과 같다.
   1. 마이스터넷 등 공식 채널에 게시된 오류 정정과 변경 공지
   2. 최신 과제 문제지 PDF
   3. 최신 채점 기준 PDF와 채점 스크립트
   4. 공식 배포 파일과 안내 문서
   5. HWP/HWPX 자료
   6. 직종협의회 메모와 다른 과제번호 구현
4. PDF의 단계, 리전, CIDR, 리소스 이름, 버전, 런타임, 암호화, 태그, 입출력 경로를 빠짐없이 표로 정리한 뒤 구현한다.
5. 문제지와 채점 스크립트가 다르면 실제 채점에 영향을 주는 요구사항을 가능한 범위에서 함께 만족시킨다. 서로 충돌하거나 문제지 밖의 추가 요구로 보이면 임의로 공식 파일을 고치지 말고 오류 후보로 기록한다.
6. 오류 후보는 `상태`, `페이지/문항`, `현재 문구`, `오류라고 판단한 이유`, `제안 변경 문구`, `영향받는 채점 항목` 형식의 별도 텍스트 또는 Markdown 문서로 정리한다. 문서 머리에는 재확인일, 대조한 원본의 버전·날짜, 공식 채널 확인 범위와 확인하지 못한 범위를 기록한다. 상태는 최소한 `미확인`, `유지`, `해소`를 구분하고, 단순 명세 모호성·문서 간 명확한 충돌·채점에 영향 없는 오타를 같은 수준의 확정 오류로 표현하지 않는다. 출제 의도를 추측해 원본 PDF, 채점표 또는 배포 파일을 직접 수정하지 않는다.
7. 오류 후보를 작성하거나 갱신할 때는 문제 PDF의 해당 페이지뿐 아니라 최신 채점기준 PDF, 실제 채점 스크립트, 공식 배포 Markdown·코드를 다시 대조한다. AWS 콘솔 표시명과 API runtime 식별자처럼 서비스 명칭 차이일 가능성이 있으면 AWS 공식 문서도 확인하여 실제 충돌인지 판별한다.
8. 공식 질의가 필요하면 마이스터넷 등 지정된 채널에 제출할 수 있도록 근거와 재현 절차를 준비한다. 협의회 메모의 72시간 답변 원칙은 기대 시간으로만 취급하며, 답변이 없다는 이유로 임의 변경하지 않는다.
9. 마이스터넷 과제출제 게시물의 댓글·첨부처럼 로그인이 필요한 공식 자료가 있으면 가능한 인증된 환경에서 마지막 댓글과 최신 첨부를 확인한다. 인증 환경이 없거나 접근할 수 없으면 일반 공개 검색 결과만으로 “정정 없음” 또는 “최신 확인 완료”라고 단정하지 말고, 확인 시각·접근 제한·추가 확인 대상을 오류 후보 문서와 완료 보고에 명시한다.
10. 공식 정정으로 오류 후보가 해소되어도 즉시 행을 삭제하지 않는다. 먼저 `해소(정정일·정정 문구·첨부명)` 상태로 기록하고, 새 전체교체본을 저장소에 반영한 뒤 문제지·채점기준·채점 스크립트가 실제로 일치하는지 재검증한 후 제거한다. 새 원본을 반영하면 요구사항 대조표, 구현, README와 모든 관련 root module 검증도 다시 수행한다.
11. 공식 배포 파일은 가능한 한 그대로 재사용한다. 바이너리, 이미지, 샘플 데이터, Lambda 코드의 내용을 임의로 대체하지 않는다.
12. 배포된 추가 Markdown이나 바이너리 실행 안내가 문제지 범위를 넘어서는 경우 숨은 요구사항으로 단정하지 말고, 문제지·채점표·공식 정정에서 근거를 찾아 오류 후보로 기록한다.
13. 다른 과제번호 폴더는 패턴 참고용으로만 읽을 수 있다. 대상 과제의 고정 이름, 리전, 계정별 값 또는 네트워크 구성을 다른 과제에서 가져오지 않는다.

## 2. 디렉터리와 Terraform 파일 구성

- 결과물은 저장소 루트의 `task1/<과제번호>`, `task2/<과제번호>` 아래에 둔다. `task3`는 과제가 하나뿐인 공통 과제이므로 과제번호 하위 디렉터리를 만들지 않고 `task3/`를 root module 경계로 사용한다. 여기서 `taskN`은 과제 구분이고 `<과제번호>`는 대회에서 사용될 수 있는 출제 과제 식별자다.
- `.tf` 파일을 단계별로 나누는 것만으로는 state나 적용 단위가 분리되지 않는다. 추가 과제 대응을 위해 **단계별 파일 분리 + 수명주기별 root module/state 분리 + 독립 extension 분리**를 함께 사용한다.
- `foundation`에는 VPC, IAM, KMS, EKS처럼 여러 단계가 공유하고 변경 비용이 큰 기반 리소스를 둔다.
- `application`에는 원래 과제의 워크로드, 서비스, 데이터 처리 코드를 둔다.
- `extensions/<추가과제명>`에는 모니터링, 추가 Lambda, 보안 대응 등 기존 과제와 독립적으로 추가·삭제할 수 있는 요구사항을 둔다.
- `grading-bastion`은 필요한 경우에만 만드는 extension이며 다른 애플리케이션 리소스와 state를 공유하지 않는다.
- 모든 과제 단계를 별도 state로 만들지는 않는다. 함께 생성·변경·삭제되는 리소스는 같은 root module에 두고, 수명주기·권한·provider 접근 방식이 다른 경계에서만 state를 분리한다.
- 두 곳 이상에서 반복되고 인터페이스가 안정된 구성만 `taskN/<과제번호>/modules/`의 재사용 모듈로 추출한다. security group rule 하나처럼 작은 리소스까지 과도하게 모듈화하지 않는다.
- 각 root module 안에서는 `00-common.tf`, `versions.tf`, `variables.tf`, `outputs.tf`를 분리하고, 과제지의 단계마다 번호가 붙은 개별 `.tf` 파일을 사용한다. 신규 root module에 `main.tf` 하나로 provider·변수·data source·리소스·output을 함께 두지 않는다.
- 새 과제의 권장 형식은 다음과 같다.

```text
taskN/
└── <과제번호>/
    ├── README.md
    ├── terraform.tfvars.example     # 과제 전체 root module이 공유하는 주석 포함 입력 예시
    ├── modules/                     # 선택: 재사용 가치가 있는 내부 모듈
    │   ├── network/
    │   ├── eks/
    │   ├── monitoring/
    │   └── grading-bastion/
    ├── assets/                      # Terraform 입력 자산의 과제 단위 저장소
    │   ├── foundation/
    │   ├── application/
    │   ├── extensions/
    │   └── shared/                  # 둘 이상의 root module이 공유하는 자산만 사용
    ├── foundation/                  # 독립 root module/state
    │   ├── 00-common.tf
    │   ├── 01-network.tf
    │   ├── 02-cluster.tf
    │   ├── versions.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── application/                 # 독립 root module/state
    │   ├── 01-workload.tf
    │   ├── 02-service.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── extensions/
        ├── monitoring/              # 추가 과제별 독립 root module/state
        ├── extra-lambda/
        └── grading-bastion/
```

`task2/<과제번호>/`처럼 독립 서비스가 여럿인 과제는 위의 `foundation`·`application` 대신 `<module-a>/`, `<module-b>/`를 둘 수 있으며, 각 모듈은 자체적인 foundation/application/extensions 경계를 가질 수 있다. 단일 공통 과제인 `task3/`는 과제번호 디렉터리 없이 이 원칙을 적용한다.

- `00-common.tf`에는 계정·리전 data source, 공통 locals 등만 둔다.
- `versions.tf`에는 Terraform/provider 버전과 provider 설정을 둔다.
- `variables.tf`와 `outputs.tf`에는 각각 입력과 출력만 둔다.
- Terraform이 읽는 Lambda 소스, 웹 자산, 컨테이너 파일, 사용자 데이터, 테스트 데이터와 템플릿은 과제 루트의 `assets/` 아래에 둔다. 기본 경로는 `task1/<과제번호>/assets/<root-module-경로>/...`, `task2/<과제번호>/assets/<root-module-경로>/...`, `task3/assets/<root-module-경로>/...`이며, 여러 root module이 공유하는 자산만 `assets/shared/`에 둔다. 중첩 root module은 디렉터리 경로를 그대로 반영한다. 예: `sqs-eks/addons/workloads`는 `assets/sqs-eks/addons/workloads/`를 사용한다.
- root module 내부의 `assets/`, `lambda/`, 루트 단독 소스 파일에 Terraform 입력 자산을 새로 두지 않는다. Terraform 코드는 과제 루트 `assets/`의 소유 경로만 참조하며, root module 사이에 자산 경로 의존성을 만들지 않는다.
- 공식 원본 폴더의 배포 자산은 이동하거나 수정하지 않는다. Terraform용 자산을 과제 디렉터리 안에서 옮길 때는 파일 내용을 바꾸지 않고, 이동 전후 Git blob hash 또는 SHA-256으로 동일성을 확인한다. Lambda ZIP처럼 Terraform 실행 중 생성되는 산출물은 `assets/`에 넣지 않는다.
- 파일 분리는 가독성을 위한 것이며 같은 디렉터리의 모든 `.tf`는 하나의 root module로 함께 평가된다는 점을 README에 명시한다.
- root module 사이에는 필요한 최소 값만 전달한다. `foundation`은 `vpc_id`, subnet IDs, cluster name, endpoint 등 안정적인 output 계약을 제공하고, `application`과 `extensions`는 이를 입력 변수로 받는다. 과제 루트에는 `config.common`, `config.modules`, `config.outputs` 구조의 단일 `terraform.tfvars.example`만 두고, 각 root module은 실행 시 과제 루트의 실제 `terraform.tfvars`를 명시적인 상대 `-var-file` 경로로 읽는다. `config.outputs`의 placeholder에는 값을 얻을 foundation/infra output 이름과 명령을 주석으로 설명한다.
- `modules/` 아래 child module에는 backend를 선언하지 않고 provider configuration도 가급적 두지 않는다. provider와 backend의 소유권은 이를 호출하는 root module에 둔다.
- backend와 state 위치가 안정적으로 관리될 때만 `terraform_remote_state`를 사용한다. 이 저장소의 root module 사이에서는 `backend = "local"` 또는 상대 경로(`../.../terraform.tfstate`)를 이용한 `terraform_remote_state`를 사용하지 않는다. 필요한 foundation/infra output은 소비 module의 명시적 변수로 전달하고, endpoint·CA처럼 AWS API에서 조회 가능한 값은 AWS data source를 함께 사용한다.
- extension은 기존 리소스의 소유권을 가져가거나 동일 리소스를 중복 선언하지 않는다. 추가 리소스와 필요한 연결만 소유하여 extension 단독 `plan`, `apply`, `destroy`가 가능해야 한다.
- 추가 과제를 기존 root module의 여러 `enable_*` 조건으로 누적하기보다 독립 extension을 우선한다. 기존 리소스와 반드시 원자적으로 생성·삭제되어야 할 때만 feature flag를 사용한다.
- 이미 apply된 기존 과제를 구조 정리만을 위해 이동하지 않는다. 추가 과제는 먼저 `extensions/`로 붙인다. 실제 리소스 주소를 옮겨야 한다면 `moved` block 또는 검증된 `terraform state mv` 계획을 사용하고, plan에서 불필요한 destroy/create가 0건인지 확인한다.
- `terraform.tfstate*`, 실제 `terraform.tfvars`, plan 파일, `.terraform/`, 생성 ZIP, 자격 증명과 비밀값은 커밋하지 않는다. 필요한 값은 과제 루트의 단일 `terraform.tfvars.example`에 안전한 예시와 한국어 주석으로 제공하고, root module 내부에는 별도 tfvars 예시를 만들지 않는다.

## 3. 구현 원칙

- 리소스 이름, 리전, CIDR, AZ 수, 포트, 경로, 태그는 문제지 및 채점 스크립트의 정확한 값을 따른다.
- 계정 ID, 현재 파티션, caller ARN처럼 실행 환경에 따라 달라지는 값은 data source로 구한다.
- 과제번호가 이름에 들어가는 경우 `task_id` 같은 변수로 만들고 기본값 또는 예시는 대상 번호와 일치시킨다.
- S3처럼 전역 고유 이름이 필요한 리소스는 문제의 명명 규칙을 해치지 않는 범위에서만 계정 ID나 과제번호를 사용한다.
- 모든 리소스에 가능한 한 과제 식별 태그를 공통 적용한다. 예: `Project`, `TaskId`, `ManagedBy = "Terraform"`. 정리 시 이 태그를 사용한다.
- provider가 지원하는 수명주기와 종속성을 명시적으로 구성한다. 단순히 `depends_on`을 남발하지 않는다.
- 삭제 시 내용이 생기는 실습용 S3 버킷은 요구사항에 반하지 않는다면 `force_destroy = true`를 고려한다. CloudTrail이나 애플리케이션이 계속 쓰는 버킷은 생산자를 먼저 중지한 뒤 비운다.
- EKS/Kubernetes/Helm처럼 클러스터 API 접근이 필요한 리소스는 기반 AWS 인프라와 별도 root module로 분리한다. 삭제는 애드온/워크로드 모듈부터 역순으로 수행한다.
- 코드 생성 후 깨진 한글, 잘못된 따옴표, 보이지 않는 제어 문자, 잘린 HCL 블록을 확인한다. 문서는 UTF-8로 저장한다.
- Terraform이 관리하지 않는 콘솔 수동 변경은 최소화한다. 불가피하면 README에 생성·검증·삭제 방법을 기록한다.
- 1·2·3과제는 공식 정정 또는 추가 문제로 기존 점수 기준에 최대 30%가 추가될 수 있다는 협의회 내용을 고려한다. 기존 구조를 과도하게 고정하거나 채점 스크립트의 현재 문자열에만 맞추지 말고, 단계별 모듈·변수·자산을 교체할 수 있게 구성한다.
- 기존 문제와 독립적인 EKS 모니터링, Lambda 추가 등의 요구가 붙을 수 있으므로 공통 기반과 추가 애플리케이션을 느슨하게 결합한다.
- 대회 계정은 root가 아니라 PowerUser 이상 수준일 수 있다. root 전용 작업에 의존하지 말고, apply 전에 caller identity와 실제 권한을 확인한다. 권한 부족을 우회하기 위해 권한을 임의 확대하지 않는다.
- 대회에서 허용되지 않는 Amazon Q CLI, Amazon Q Developer, Kiro 등의 도구를 전제로 구현·문서화하지 않는다. 자동화는 허용된 도구와 재현 가능한 Terraform/AWS CLI 명령으로 구성한다.

## 4. README 작성 기준

각 `task1/<과제번호>/README.md`와 `task2/<과제번호>/README.md`, 그리고 단일 공통 과제의 `task3/README.md`는 UTF-8 한국어로 작성하며 최소한 다음을 포함한다.

- 사용한 원본 문제지와 채점 자료의 상대 경로
- task와 모듈별 디렉터리 구조
- `foundation → application → extensions` 의존 관계와 각 root module의 state 경계
- 과제 단계와 `.tf` 파일의 1:1 대응표
- 리전, 주요 네트워크 대역, 고정 리소스 이름
- 사전 준비 사항과 필요한 도구 버전
- 과제 루트의 단일 `terraform.tfvars.example`에 있는 `common/modules/outputs` 변수 설명과 root module별 `-var-file` 사용법
- 과제 루트 `assets/`의 모듈별 경로와, 공식 원본을 수정하지 않고 재사용한다는 원칙
- `init`, `fmt`, `validate`, `plan`, `apply` 실행 순서
- 이미지 빌드/푸시나 별도 platform 적용 등 중간 절차
- 채점 스크립트 실행 방법과 전제 조건
- 모듈 간 정확한 destroy 순서 및 잔존 리소스 확인 방법
- 추가 과제 extension만 독립적으로 plan/apply/destroy하는 방법
- KMS처럼 즉시 삭제할 수 없는 리소스의 동작

README의 명령은 해당 디렉터리에서 그대로 실행 가능한 형태여야 한다. Windows 전용 경로와 Bash 명령이 섞일 때는 PowerShell/WSL 실행 위치를 분명히 적는다. PowerShell에서 상대 경로를 사용하는 Terraform 변수 파일 인수는 `"-var-file=../terraform.tfvars"`처럼 `-var-file=...` 전체를 큰따옴표로 감싸 Windows native argument 전달 오류를 방지한다.

## 5. 로컬 Terraform 검증

각 root module마다 다음 순서로 검사한다.

```bash
terraform fmt -recursive
terraform init -input=false
terraform validate
terraform plan -input=false
```

- 먼저 `terraform fmt -check -recursive` 또는 `terraform fmt -recursive`로 HCL 파싱과 형식을 확인한다.
- `init` 실패 시 provider 버전, 네트워크, lock 파일 문제를 구분한다.
- `validate` 오류는 파일·라인 단위로 수정한다.
- `plan`에는 과제에 필요한 변수 또는 `-var-file`을 빠짐없이 전달한다.
- 모든 root module의 plan이 성공할 때까지 실제 AWS에 적용하지 않는다.
- 검증 순서는 `foundation → application → extensions`로 하며, extension마다 독립적으로 plan이 성공하는지 확인한다.
- 사용자가 “plan까지만” 요청한 경우 `apply`, AWS CLI 생성/변경 명령, 채점 스크립트 실행은 하지 않는다.
- plan 결과에서 예상치 못한 삭제, 다른 과제번호 리소스, 기본 VPC 변경, 과도하게 넓은 IAM 권한을 검토한다.

## 6. AWS 적용 원칙

- 실제 `terraform apply`는 사용자가 명시적으로 요청한 경우에만 실행한다.
- 시작 전에 `aws sts get-caller-identity`와 각 module의 provider 리전을 확인한다.
- 다른 과제 또는 기존 사용자 리소스와 이름·태그가 겹치지 않는지 확인한다.
- `foundation → application → 필요한 extensions → 데이터 투입` 순으로 적용한다. 서로 독립적인 extension은 기반 output이 준비된 뒤 개별 적용할 수 있다.
- 장시간 생성되는 EKS, MSK, Flink, NAT Gateway 등은 완료 상태까지 기다리고 중간 실패를 확인한다.
- apply 후에는 Terraform output만 믿지 말고 AWS API로 실제 상태와 엔드포인트를 확인한다.
- 테스트 데이터나 채점 실행이 만드는 객체·로그도 이후 정리 대상에 포함한다.

## 7. 채점 스크립트 실행과 과제 구현 수정 반복

1. 대상 과제번호와 task1/task2 구분에 정확히 대응하는 채점 스크립트를 찾는다.
2. 스크립트를 읽어 필요한 셸, AWS profile/region, `jq`, `kubectl` 등의 전제 조건과 파괴적 명령 유무를 먼저 확인한다.
3. 채점 스크립트, 특히 Kubernetes 채점은 원칙적으로 AWS CloudShell에서 실행한다. 스크립트와 필요한 배포 파일을 CloudShell로 옮기고, 대상 AWS 계정과 리전이 맞는지 `aws sts get-caller-identity` 및 AWS CLI 설정으로 확인한 뒤 실행한다.
4. EKS는 채점 시 CloudShell에서 별도의 추가 설정 없이 접근할 수 있도록 미리 구성한다. 문제지가 특정 방식을 요구하지 않으면 IRSA, `aws-auth` ConfigMap, Pod Identity, EKS Access Entry 중 하나를 채점 정답처럼 강제하지 말고 실제 `aws eks update-kubeconfig`와 `kubectl` 접근 성공 여부를 우선한다.
5. 선수가 필요하다고 판단한 경우에만 Kubernetes 채점용 베스천 호스트를 대상 VPC에 만들 수 있다. 베스천은 채점 중 새로 생성할 수 없으므로 Terraform apply와 과제 풀이 단계에서 미리 생성·검증해야 한다. 베스천 생성으로 다른 채점 항목이나 리소스 수에 영향이 생기면 그 불이익을 감수해야 한다.
   - 가능하면 퍼블릭 SSH 대신 AWS Systems Manager Session Manager를 사용한다.
   - SSH가 꼭 필요하면 허용 CIDR과 포트를 채점에 필요한 최소 범위로 제한한다.
   - 베스천 호스트, IAM role, instance profile, security group과 관련 네트워크 리소스는 Terraform으로 관리하고 과제 식별 태그를 적용한다.
   - 베스천에는 채점에 필요한 도구와 파일만 설치하며 자격 증명이나 비밀값을 영구 저장하지 않는다.
   - 채점이 끝나면 성공 여부와 관계없이 베스천 관련 리소스를 즉시 destroy하고 실제 AWS에서 잔존 여부를 확인한다.
6. 다른 채점 항목의 편의를 위해 베스천을 추가하지 않는다. 문제지에서 명시한 경우를 제외하면 일반 서비스 채점은 CloudShell과 AWS 서비스 API로 수행한다.
7. 로컬 Windows에서 Bash 스크립트를 사전 점검해야 한다면 WSL 또는 Git Bash의 경로 변환을 확인한다. 로컬 점검은 CloudShell 또는 미리 준비한 베스천에서 수행하는 실제 채점을 대체하지 않는다.
8. 사용자가 별도 횟수를 지정하지 않았다면 채점과 수정은 최대 3회까지만 시도한다.
9. 각 시도에서 다음을 기록한다.
   - 실행한 스크립트와 대상 과제
   - 실행 환경(CloudShell 또는 베스천)과 대상 리전
   - 실패한 항목과 실제 오류
   - 원인
   - 수정한 파일
10. 오류가 Terraform/애플리케이션 구현에서 발생한 경우에만 파일을 수정하고 필요한 최소 범위에 다시 plan/apply한다.
11. 채점 스크립트는 어떤 경우에도 수정하지 않는다. 채점 스크립트에 오류나 환경 의존 문제가 있어도 원본 파일은 그대로 보존하고, 실행 환경을 맞추거나 Terraform·애플리케이션 코드를 수정하여 대응한다. 원본 오류로 판단되면 파일을 고치는 대신 오류 위치, 재현 방법과 근거를 사용자에게 보고한다.
12. 채점이 성공하거나 3회 실패하면 반복을 종료한다. 사용자가 정리를 요청했거나 “성공/실패 후 정리”를 포함했다면 결과와 관계없이 정리 단계로 진행한다.

### 3과제와 비공개 동적 채점

- 3과제는 공식 정정으로 변경될 수 있으며, 트래픽 패턴·User-Agent·요청 경로·공격 패턴·세부 점수 기준은 공개되지 않을 수 있다.
- 현재 채점 요청을 역추적해 특정 값만 하드코딩하지 않는다. 현장에서 로그와 메트릭을 관찰하고 원인을 판별할 수 있도록 CloudWatch 등 기본 관측성을 준비한다.
- 애플리케이션은 정해지지 않은 정상 입력에도 안전하게 동작하고, 오류 응답을 명확히 하며, 가능한 낮은 지연으로 처리하도록 구현한다.
- 불필요한 EC2와 상시 고비용 리소스를 늘리지 말고 요구 성능을 만족하는 최소 구성을 우선한다.
- WAF, subscription filter, Firehose, S3 적재 같은 대응은 실제 문제 요구와 관찰된 트래픽에 근거해 선택한다. 협의회에서 든 예시를 확정 문제나 정답으로 취급하지 않는다.
- S3 업로드 키, Content-Type, request body, 환경 변수처럼 명세가 빠진 항목은 임의의 유일 정답으로 고정하지 않는다. 합리적인 기본값과 여러 일반 형식을 수용하도록 설계하고 공식 질의 후보로 기록한다.

## 8. 리소스 정리 절차

정리는 대상 과제번호와 이번 작업에서 생성한 리소스로만 제한한다. 이름 또는 태그가 불명확한 리소스는 삭제하지 않는다.

1. 새 데이터를 계속 생성하는 producer, CloudTrail, 이벤트 소스, 애플리케이션을 먼저 중지한다.
2. EKS 내부 리소스, Helm release, Kubernetes Service/Ingress 등 외부 AWS 리소스를 만드는 항목을 먼저 destroy한다.
3. `extensions → application → foundation` 역순으로 `terraform destroy`한다. 베스천과 추가 과제 extension은 각각 독립적으로 먼저 제거한다.
4. S3 `BucketNotEmpty`가 발생하면 생산자가 중지되었는지 확인하고, 대상 버킷만 비운 뒤 destroy를 재시도한다.
5. Terraform 밖에서 자동 생성된 CloudWatch Log Group을 과제 이름/태그로 찾아 삭제한다.
6. KMS 키는 AWS 정책상 즉시 삭제할 수 없다. 대상 키가 확실한 경우 최소 허용 대기 기간으로 삭제 예약하고 최종 삭제 날짜를 보고한다.
7. destroy 오류를 state에서 임의 제거하여 숨기지 않는다. 실제 AWS 리소스가 사라진 것을 확인한 경우에만 state 정합성을 처리한다.

다음 항목을 모든 사용 리전과 전역 서비스에서 교차 검증한다.

- 각 Terraform state의 관리 리소스 수가 0인지
- EC2, EBS, VPC, subnet, ENI, security group, NAT Gateway, Elastic IP
- ELB/ALB/NLB와 target group
- EKS, MSK, Kinesis/Flink, Lambda, Step Functions
- DynamoDB, S3, ECR, CloudFront
- CloudTrail, EventBridge, AWS Config, SNS, CloudWatch Log Group
- IAM role, instance profile, customer-managed policy
- KMS alias와 삭제 예약 키

Resource Groups Tagging API는 삭제된 EC2/NAT/EBS ARN을 잠시 반환할 수 있다. 태깅 결과만으로 잔존 여부를 판단하지 말고 해당 서비스 API에서 `terminated`, `deleted`, `NotFound`인지 직접 확인한다.

## 9. 안전과 완료 보고

- AWS 계정 전체를 포괄하는 이름 없는 일괄 삭제를 하지 않는다.
- 기본 VPC, 다른 과제번호, 다른 프로젝트 또는 사용자가 만든 리소스는 건드리지 않는다.
- 삭제 전에는 계정 ID, 리전, 리소스 ID, 이름, 태그를 확인한다.
- 로컬 `.tf` 소스와 README는 리소스 정리 대상이 아니다. 사용자가 명시적으로 요청하지 않는 한 삭제하지 않는다.
- 완료 보고에는 다음을 간결하게 포함한다.
  - 수정한 파일과 구현 범위
  - `fmt`, `validate`, `plan`, apply 결과
  - 채점 시도 횟수와 최종 결과
  - destroy 결과와 실제 AWS 잔존 리소스 조회 결과
  - 삭제 예약 상태로 남은 KMS 키와 최종 삭제 예정일
  - 실행하지 못한 항목과 그 이유

## 10. 작업 체크리스트

- [ ] 대상 과제번호의 문제지·채점지·채점 스크립트를 확인했다.
- [ ] 최신 공식 오류 정정과 `docs/`의 협의회 참고사항을 확인했다.
- [ ] 저장소 수집일, 공식 게시물 수정일과 마지막 첨부 댓글의 날짜를 구분해 최신 원본을 판정했다.
- [ ] 로그인 전용 공식 자료의 확인 여부와 접근 제한을 기록했다.
- [ ] 문제지 충돌이나 누락 명세를 상태·재확인일·근거와 함께 원본 수정 없이 오류 후보 문서로 정리했다.
- [ ] 해소된 오류 후보는 새 원본의 문제지·채점기준·스크립트 일치 여부를 재검증했다.
- [ ] 과제 단계별로 `.tf` 파일을 분리했다.
- [ ] 기반·애플리케이션·추가과제를 수명주기별 root module/state로 분리했다.
- [ ] 각 extension이 기존 리소스 소유권을 침범하지 않고 독립적으로 plan/destroy 가능한지 확인했다.
- [ ] 공식 배포 자산을 올바른 위치에서 재사용했다.
- [ ] README를 UTF-8로 갱신했다.
- [ ] 모든 root module에서 `fmt`, `init`, `validate`, `plan`이 성공했다.
- [ ] 사용자 요청 범위 안에서만 apply했다.
- [ ] 채점 스크립트를 최대 허용 횟수 안에서 실행하고, 필요한 경우 과제 구현만 수정했다.
- [ ] 채점 스크립트 원본을 수정하지 않았으며, 오류는 환경 또는 과제 구현에서만 대응했다.
- [ ] CloudShell에서 EKS/Kubernetes 접근을 확인했고, 필요하면 베스천을 채점 전에 준비했다.
- [ ] 종속 관계의 역순으로 destroy했다.
- [ ] Terraform state와 실제 AWS API를 모두 확인했다.
- [ ] 삭제 예약 리소스와 잔존 여부를 사용자에게 보고했다.
