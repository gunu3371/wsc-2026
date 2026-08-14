# 00002 공식 질의 후보

원본은 수정하지 않았으며, 실제 구현은 공개 채점에 영향을 주는 조건을 함께 만족하도록 구성했다.

| 페이지/문항 | 현재 문구 | 오류라고 판단한 이유 | 제안 변경 문구 | 영향받는 채점 항목 |
|---|---|---|---|---|
| 1과제 문제 3단계 ECR / 채점 3-1-A | 문제지는 private repository·scan만 요구하지만 채점 예시는 암호화 형식 `KMS`를 기대 | 문제지만으로 KMS 선택을 알 수 없음 | ECR repository는 customer managed KMS key로 암호화한다고 문제지에 명시 | 1과제 3-1-A |
| 1과제 Reference03 / 7~9단계 | Lambda 표의 경로는 `/reserv-query`로 보이나 ALB·CloudFront와 채점은 `/book`을 호출 | 외부 공개 경로와 Lambda 기능 경로가 불일치 | 외부 `/book` 요청을 Lambda에 전달한다고 통일하거나 path rewrite 여부 명시 | 7-2-A, 8-3-A, 9-1~3-A |
| 2과제 Analytics 5단계 / 채점 2-4 | 문제지는 `Apache Flink 1.19`, Studio Notebook을 함께 요구하고 채점은 `ZEPPELIN-FLINK-3_0`을 기대 | AWS Studio Notebook의 runtime 식별자와 일반 Flink runtime 표기가 다름 | 기대 API 값 `ZEPPELIN-FLINK-3_0`과 대응 Flink 버전을 함께 명시 | 2-4 |
| 2과제 Cloud Event 4단계·배포 lambda.md / 채점 3-1~3-5 | 문제·배포 문서는 SG/role/terminate/type 4종을 설명하지만 채점은 stop remediation, tag alert, AWS Config 규칙도 확인 | 공개 요구와 실제 점검 리소스 집합이 다름 | 필요한 6개 Lambda·EventBridge 및 2개 Config 규칙을 문제지에 모두 열거 | 3-1~3-5 |
| 2과제 MSK 채점기준 PDF 4-0 / mark2-4.sh | PDF의 준비 명령 일부가 student-score bucket 이름을 사용하지만 실제 스크립트는 sensor-alert bucket을 사용 | 모듈이 다른 버킷명이 복사된 것으로 보임 | `wsc2026-sensor-alert-bucket-<응시번호>`로 통일 | 4-1 |
