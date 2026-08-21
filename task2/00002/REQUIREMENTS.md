# 2과제 00002 요구사항 대조표

2026-08-21에 저장소의 기존 PDF와 `2026년 전국기능경기대회 hwp 수정본/2과제 00002/` PDF를 대조했다. 수정본의 공식 게시 여부는 로그인 전용 채널에서 추가 확인이 필요하다.

| 모듈 | 리전·핵심 요구사항 | 구현 파일 |
| --- | --- | --- |
| Workflow | ap-southeast-1, S3 input/processed/error, DynamoDB 복합키, Lambda `wsc2026-student-score-function`, Python 3.12, Standard Step Functions | `workflow/01-storage.tf`~`04-s3-trigger.tf`, `assets/workflow/` |
| Analytics | ap-northeast-2, VPC `10.20.0.0/16`, private EC2 t3.small, systemd `app`, IAM role `wsc2026-analytics-ec2-role`, ALB:80→TG:5000, Kinesis, Studio Notebook | `analytics/01-network.tf`~`05-flink.tf`, `assets/analytics/` |
| Cloud Event | eu-west-1, management CloudTrail, SNS, 정책 위반 탐지·복구 Lambda와 EventBridge, 복구 확인 전 60초 대기 | `cloud-event/01-network-ec2.tf`~`05-config.tf`, `assets/cloud-event/` |
| MSK | ap-northeast-1, Kafka 3.6.0, kafka.t3.small, IAM 인증, raw 3/2·alert 1/2 topic, Python 3.14 consumers, DynamoDB 조회 결과의 `sensorId`·ISO 8601 KST `timestamp` 확인 | `msk/01-network.tf`~`05-consumers.tf`, `assets/msk/` |

네 모듈은 서로 독립된 root module/state다. 공식 배포 자산과 채점 스크립트는 수정하지 않는다.
