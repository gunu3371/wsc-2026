# 2과제 00002 최종수정본 요구사항 대조표

- 재확인일: 2026-08-24
- 문제지: `../2과제 최종수정본/day2-release-candidate-tp.pdf`
- 채점 기준: `../2과제 최종수정본/day2-release-candidate-marking.pdf`
- 배포 자산: 기존 과제번호 00002 공식 배포 폴더

| 페이지/문항 | 리전·네트워크 | 리소스·동작 | 채점 항목 | 구현 |
| --- | --- | --- | --- | --- |
| 문제 2~3쪽, Workflow 1~6 | ap-southeast-1 | 비번호 S3와 input/processed/error, DynamoDB PK/SK, Python 3.12 Lambda, Standard Step Functions, S3 자동 trigger | 1-1~1-6 | `workflow/01-storage.tf`~`04-s3-trigger.tf`, `assets/workflow/` |
| 문제 3~5쪽, Analytics 1~6 | ap-northeast-2, `10.20.0.0/16`, public/private 2AZ, NAT | private t3.small EC2, systemd `app`, ALB 80→5000, on-demand Kinesis, Studio Notebook | 2-1~2-7 | `analytics/01-network.tf`~`05-flink.tf`, `assets/analytics/` |
| 문제 5~6쪽, MSK 1~7 | ap-northeast-1, `192.168.0.0/16`, public/private a/d, NAT | Kafka 3.6.0, t3.small broker/producer, IAM auth, raw 3/2·alert 1/2 topic, Python 3.14 consumers, DynamoDB·S3·SNS | 3-1~3-6 | `msk/01-network.tf`~`05-consumers.tf`, `assets/msk/` |

## 세부 검사값

| 항목 | 문제지·채점값 | 구현 결정 |
| --- | --- | --- |
| Workflow 버킷 | `wsc2026-student-score-bucket-<비번호>` | `candidate_number` 사용 |
| Workflow 결과 | STU1020 평균 96.6/A, processed CSV 497바이트, 오류 JSON 4건 | 공식 CSV blob과 완성 Lambda 사용 |
| Analytics 접근 | CloudShell에서 ALB `/order`, `/health` 호출 | ALB HTTP 80을 `0.0.0.0/0`에 공개 |
| Flink runtime | 문제지 Flink 1.19, 채점 `ZEPPELIN-FLINK-3_0` | 채점값 우선, 오류 후보 기록 |
| MSK topics | raw 3/2, alert 1/2 | AWS provider의 `aws_msk_topic`으로 선행 생성 |
| MSK 처리 | raw Lambda가 모든 레코드 저장, 이상 데이터만 alert topic 전달 | Kafka Python layer와 IAM OAUTHBEARER 사용 |
| MSK 조회값 | DynamoDB `temperature`와 `status`는 String, timestamp는 ISO 8601 KST | 숫자 필드를 문자열로 저장하고 `+09:00` 유지 |

세 root module은 독립 state다. 공식 PDF와 배포 자산·채점 문서는 수정하지 않는다.
