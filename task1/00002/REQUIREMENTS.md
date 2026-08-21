# 00002 요구사항 대조표

## 1과제

| 단계 | 리전·네트워크·이름·버전 | 구현 파일 |
|---|---|---|
| 1 Network | ap-northeast-2, VPC `172.16.0.0/16`, public `1/24·2/24`, private `201/24·202/24`, AZ c/d, AZ별 NAT | `task1/foundation/01-network.tf` |
| 2 S3 | `wskorea26-concert-bucket-<선수 비번호>`, `web/main/index.html`, `web/main/main.jpeg`, KMS alias `wskorea26-s3-key`, public 차단 | `task1/foundation/02-static-storage.tf` |
| 3 ECR | `wskorea26-book-repo`, private, scan on push, KMS, `stable` 이미지 | `foundation/03-container-registry.tf`, `assets/shared/book-image/`, `extensions/image-build/` |
| 4 DynamoDB | `wskorea26-data-table`, PK `client_id(S)`, GSI `concert_name-created_at-index`(`concert_name`/`created_at`), 삭제 방지, KMS alias `wskorea26-dynamodb-key` | `foundation/04-database.tf` |
| 5 EKS | `wskorea26-cluster` 1.35, private endpoint, 전체 control-plane log, secrets KMS, private c/d, addon/app t3.medium nodegroup와 label/taint | `task1/foundation/05-eks.tf`, `task1/application/01-application.tf` |
| 6 Lambda | `wskorea26-book-lambda`, Python 3.14, `TABLE_NAME`, GET query와 400/200 처리 | `task1/foundation/06-lambda.tf`, `task1/foundation/lambda/book.py` |
| 7 ALB | `wskorea26-book-alb`, internet-facing HTTP 80, `/book`의 GET·POST별 `X-Origin-Verify` 검증 규칙, 검증 header 없으면 403 | `task1/foundation/07-application-load-balancer.tf` |
| 8 CloudFront | S3 기본 origin `wskorea26-s3-origin`, `/book*` ALB origin `wskorea26-alb-origin`, HTTP→HTTPS, OAC, ALB `X-Origin-Verify: wskorea26-cf`, S3 `wskorea26-s3-access: true` | `foundation/08-cloudfront.tf` |
| 9 Application | POST booking과 GET query, KST `created_at`, 빈 결과 `[]` | 4·6·7·8단계 및 `task1/application/01-application.tf` |
| 10 Monitoring | addon nodegroup의 kube-prometheus-stack, Grafana NodePort/ALB, `book` 앱으로 범위를 제한한 CPU·메모리·실행 Pod·재시작·수신 네트워크 패널 | `foundation/10-monitoring.tf`, `application/02-monitoring.tf`, `assets/foundation/monitoring/dashboard.json` |

원본 배포 이미지와 바이너리는 내용 변경 없이 재사용한다. Terraform이 생성하는 ZIP만 빌드 산출물로 취급한다. 2과제 요구사항은 `task2/00002/REQUIREMENTS.md`에서 별도로 관리한다.
