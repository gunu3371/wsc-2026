# 00002 요구사항 대조표

## 1과제

| 단계 | 리전·네트워크·이름·버전 | 구현 파일 |
|---|---|---|
| 1 Network | ap-northeast-2, VPC `172.16.0.0/16`, public `1/24·2/24`, private `201/24·202/24`, AZ c/d, AZ별 NAT | `task1/foundation/01-network.tf` |
| 2 S3 | `wskorea26-concert-bucket-<응시번호>`, `web/main/index.html`, `web/main/main.jpeg`, KMS alias `wskorea26-s3-key`, public 차단 | `task1/foundation/02-static-storage.tf` |
| 3 ECR | `wskorea26-book-repo`, private, scan on push, KMS, `stable` 이미지 | `foundation/03-container-registry.tf`, `assets/shared/book-image/`, `extensions/image-build/` |
| 4 DynamoDB | `wskorea26-data-table`, PK `client_id(S)`, 삭제 방지, KMS alias `wskorea26-dynamodb-key` | `task1/foundation/04-database.tf` |
| 5 EKS | `wskorea26-cluster` 1.35, private endpoint, 전체 control-plane log, secrets KMS, private c/d, addon/app t3.medium nodegroup와 label/taint | `task1/foundation/05-eks.tf`, `task1/application/01-application.tf` |
| 6 Lambda | `wskorea26-book-lambda`, Python 3.14, `TABLE_NAME`, GET query와 400/200 처리 | `task1/foundation/06-lambda.tf`, `task1/foundation/lambda/book.py` |
| 7 ALB | `wskorea26-book-alb`, internet-facing HTTP 80, `/book`, 검증 header 없으면 403 | `task1/foundation/07-application-load-balancer.tf` |
| 8 CloudFront | S3 기본 origin, `/book*` ALB origin, HTTP→HTTPS, OAC, `X-Origin-Verify` | `task1/foundation/08-cloudfront.tf` |
| 9 Application | POST booking과 GET query, KST `created_at`, 빈 결과 `[]` | 4·6·7·8단계 및 `task1/application/01-application.tf` |
| 10 Monitoring | addon nodegroup의 kube-prometheus-stack, Grafana NodePort/ALB, 5개 지정 패널 | `task1/foundation/10-monitoring.tf`, `task1/application/02-monitoring.tf`, `dashboard.json` |

## 2과제

| 모듈 | 리전·핵심 요구사항 | 구현 파일 |
|---|---|---|
| Workflow | ap-southeast-1, S3 input/processed/error, DynamoDB 복합키, Python 3.12, Standard Step Functions, 정상 5건·오류 4건 | `task2/workflow/01-storage.tf`~`04-s3-trigger.tf`, `lambda/` |
| Analytics | ap-northeast-2, VPC `10.20.0.0/16`, public `0/24·1/24`, private `100/24·101/24`, private EC2 t3.small, ALB:80→TG:5000, on-demand Kinesis, Studio Notebook | `task2/analytics/01-network.tf`~`05-flink.tf` |
| Cloud Event | eu-west-1, VPC `172.16.0.0/16`, public `0/24·1/24`, t3.micro, management CloudTrail, SNS, 정책 위반 탐지/복구 Lambda와 EventBridge | `task2/cloud-event/01-network-ec2.tf`~`05-config.tf`, `lambda/index.py` |
| MSK | ap-northeast-1, VPC `192.168.0.0/16`, public `0/24·1/24`, private `10/24·11/24`, Kafka 3.6.0, kafka.t3.small, IAM, raw 3/2·alert 1/2 topic, Python 3.14 consumers | `task2/msk/01-network.tf`~`05-consumers.tf`, `lambda/`, `assets/` |

원본 배포 이미지·바이너리·CSV·Go 실행 파일은 내용 변경 없이 재사용한다. Terraform이 생성하는 ZIP만 빌드 산출물로 취급한다.
