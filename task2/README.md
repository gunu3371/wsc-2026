# 2과제 Terraform 구현 (과제번호 00002)

`task2/` 자체가 과제 루트다. 2026-08-24 최종수정본에 남은 Workflow, Real-time Data Analytics, MSK를 서로 독립된 root module과 state로 관리한다. 최종본에서 제외된 Cloud Event는 구현과 실행 흐름에 포함하지 않는다.

## 기준 자료

- 최신 문제지: `../2과제 최종수정본/day2-release-candidate-tp.pdf`
- 최신 채점 기준: `../2과제 최종수정본/day2-release-candidate-marking.pdf`
- 기존 공식 배포 자산: `../37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00002/01_최종제출본/제61회전국기능경기대회_vf/2과제/과제지&배포파일/배포파일/`
- 요구사항 대조: `REQUIREMENTS.md`
- 문서 충돌과 확인 제한: `ERROR_CANDIDATES.md`

최종수정본 폴더에는 새 배포 자산과 채점 스크립트가 없으므로 기존 과제번호 00002의 공식 배포 자산을 사용한다. 원본 폴더는 수정하지 않는다.

## 구조와 state 경계

| root module | 리전 | 주요 리소스 | 의존 관계 |
| --- | --- | --- | --- |
| `workflow` | ap-southeast-1 | S3, DynamoDB, Lambda, Standard Step Functions | 독립 |
| `analytics` | ap-northeast-2 | VPC, EC2, ALB, Kinesis, Flink Studio | 독립 |
| `msk` | ap-northeast-1 | VPC, MSK, Kafka topics, EC2 producer, Lambda consumers, DynamoDB, S3, SNS | 독립 |

같은 디렉터리의 `.tf` 파일은 하나의 state를 공유한다. module 간 output 전달은 없다.

## 문제 단계와 구현 파일

| 문제 | 구현 |
| --- | --- |
| Workflow S3·DynamoDB | `workflow/01-storage.tf` |
| Workflow Lambda·IAM | `workflow/02-lambda.tf` |
| Step Functions | `workflow/03-step-functions.tf` |
| S3 trigger와 공식 CSV | `workflow/04-s3-trigger.tf` |
| Analytics VPC | `analytics/01-network.tf` |
| Kinesis | `analytics/02-kinesis.tf` |
| EC2 애플리케이션 | `analytics/03-application-ec2.tf` |
| ALB | `analytics/04-load-balancer.tf` |
| Flink Studio | `analytics/05-flink.tf` |
| MSK VPC·cluster·topics | `msk/01-network.tf`, `msk/02-msk-cluster.tf` |
| MSK 저장소·producer | `msk/03-destinations.tf`, `msk/04-producer.tf` |
| MSK Lambda·trigger | `msk/05-consumers.tf` |

## 고정 구성

- Workflow: `ap-southeast-1`, Python 3.12, `wsc2026-student-score-*`
- Analytics: `ap-northeast-2`, VPC `10.20.0.0/16`, ALB HTTP 80 공개, target port 5000
- MSK: `ap-northeast-1`, VPC `192.168.0.0/16`, Kafka 3.6.0, `kafka.t3.small`, Python 3.14
- 공통 `task_id`: `00002`; S3 이름 접미사는 별도 `candidate_number`를 사용한다.

## 입력 파일 준비

PowerShell에서 과제 루트 `task2`로 이동한 뒤 실행한다.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`의 `config.common.candidate_number`를 실제 비번호로 바꾼다. `task_id`는 과제번호 `00002`로 유지한다. 실제 tfvars, state, plan, 생성 ZIP과 자격 증명은 커밋하지 않는다.

MSK plan 전에 Python 3.14용 Kafka layer를 만든다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-msk-lambda-layer.ps1
```

스크립트는 `assets/msk/lambda/requirements.txt`의 고정 버전을 `msk/.build/kafka-python-layer.zip`으로 패키징한다. 이 경로는 Git에서 제외된다.

## 로컬 검증

각 module에서 다음 순서를 지킨다.

```powershell
terraform -chdir=workflow fmt -check
terraform -chdir=workflow init -input=false
terraform -chdir=workflow validate
terraform -chdir=workflow plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=analytics fmt -check
terraform -chdir=analytics init -input=false
terraform -chdir=analytics validate
terraform -chdir=analytics plan -input=false "-var-file=../terraform.tfvars"

terraform -chdir=msk fmt -check
terraform -chdir=msk init -upgrade -input=false
terraform -chdir=msk validate
terraform -chdir=msk plan -input=false "-var-file=../terraform.tfvars"
```

단위 테스트는 다음과 같이 실행한다.

```powershell
py -3.14 -m unittest discover -s tests -v
```

## 적용과 중간 절차

실제 AWS 적용은 계정, caller ARN, 리전과 비번호를 확인한 뒤 사용자가 명시적으로 요청한 경우에만 수행한다. 세 module은 독립적이므로 필요한 module만 적용할 수 있다.

```powershell
terraform -chdir=workflow apply "-var-file=../terraform.tfvars"
terraform -chdir=analytics apply "-var-file=../terraform.tfvars"
terraform -chdir=msk apply "-var-file=../terraform.tfvars"
```

Workflow apply 후 S3 event와 Step Functions 처리가 끝날 때까지 기다린 뒤 DynamoDB 5건, 오류 JSON 4건과 `processed/test.csv`를 확인한다. MSK apply 후에는 cluster와 두 topic이 ACTIVE인지, 두 event source mapping이 Enabled인지, producer systemd가 active/enabled인지 확인한다.

## Flink Studio SQL

채점표가 확인하는 runtime `ZEPPELIN-FLINK-3_0`을 사용한다. Studio Notebook에서 문제지의 두 SQL을 실행한다.

```sql
SELECT COUNT(*) AS order_count
FROM order_stream
WHERE event_time > CURRENT_TIMESTAMP - INTERVAL '1' MINUTE;

SELECT product_name, SUM(price * quantity) AS total_revenue
FROM order_stream
GROUP BY product_name;
```

문제지의 Apache Flink 1.19 표기와 Studio runtime의 충돌은 `ERROR_CANDIDATES.md`에 기록했다.

## 정정 대비 전환 지점

오류로 판단한 원문 값은 Terraform 파일과 `terraform.tfvars.example`에서 비활성 주석으로 보존했다. 기본 적용값은 채점표와 현재 AWS에서 실행 가능한 값이다.

- `config.common.candidate_number`: S3 버킷 접미사. 기존 `task_id` 사용식은 각 module의 `00-common.tf`에 주석으로 보존한다.
- `config.modules.analytics.alb_ingress_cidrs`: 기본값 `0.0.0.0/0`. 공식 채점 출발지 CIDR이 고정되면 목록만 교체한다.
- `config.modules.analytics.flink_runtime_environment`: 기본값 `ZEPPELIN-FLINK-3_0`. 공식 정정 시 지원되는 Studio runtime 식별자로 교체한다.

채점표의 잘못된 명령은 원본 PDF를 수정하지 않고 아래처럼 해석한다.

```bash
# 원문 오류(비활성): BUCKET_NAME="wsc2026-student-score-bucket-<비번호>"
BUCKET_NAME="wsc2026-sensor-alert-bucket-<비번호>"

# 원문 오류(비활성): awsapi head-bucket / 일반 버킷에서 BucketArn 필수 확인
aws s3api head-bucket --bucket "$BUCKET_NAME"
aws s3api get-bucket-location --bucket "$BUCKET_NAME"

# 원문 오류(비활성): instance type과 subnet ID를 함께 --subnet-ids로 전달
SUBNET_ID=$(aws ec2 describe-instances --instance-ids "$EC2_ID" --query \
  "Reservations[0].Instances[0].SubnetId" --output text)
aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" --query \
  "Subnets[0].Tags[?Key=='Name'].Value|[0]" --output text
```

## 자산 소유 경로

- `assets/workflow/`: 완성한 Lambda 코드와 원본과 동일한 497바이트 `test.csv`
- `assets/analytics/`: 공식 Flask 애플리케이션, requirements와 user-data
- `assets/msk/`: 공식 Go producer, Lambda 코드, wrapper, requirements와 user-data

생성 ZIP은 `assets/`에 두지 않는다. 작업 종료 후 `msk/.build/`와 module 디렉터리의 생성 ZIP을 삭제해도 소스에는 영향이 없다.

## 채점 전 확인

- 채점은 module별 지정 리전의 CloudShell에서 실행한다.
- 채점표 원본은 수정하지 않는다.
- MSK 채점 준비 명령의 버킷 변수 오류는 실제 sensor-alert 버킷명으로 읽어야 한다.
- `HeadBucket` 출력 차이는 AWS CLI 버전에 따라 별도 확인하고 버킷 존재 여부와 리전을 서비스 API로 검증한다.

## 정리

각 module 내부 producer와 테스트 데이터 생성을 먼저 중지한 뒤 독립적으로 destroy한다. 예시는 적용 순서의 역순이다.

```powershell
terraform -chdir=msk destroy "-var-file=../terraform.tfvars"
terraform -chdir=analytics destroy "-var-file=../terraform.tfvars"
terraform -chdir=workflow destroy "-var-file=../terraform.tfvars"
```

destroy 후 각 state의 관리 리소스 수와 실제 AWS API에서 VPC, NAT Gateway, EIP, ENI, ALB, MSK, Lambda, DynamoDB, S3, SNS, IAM role과 log group 잔존 여부를 확인한다.
