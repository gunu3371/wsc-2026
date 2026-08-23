# 2과제 00002 공식 질의 후보

- 재확인일: 2026-08-24
- 대조 원본: `day2-release-candidate-tp.pdf`, `day2-release-candidate-marking.pdf`, 기존 00002 배포 자산
- 공식 채널 확인 범위: 저장소와 사용자 제공 최종수정본 폴더
- 확인하지 못한 범위: 로그인 전용 마이스터넷 게시물의 마지막 댓글과 이후 첨부, 최종본용 신규 배포 자산·채점 스크립트

| 상태 | 페이지/문항 | 현재 문구 | 오류라고 판단한 이유 | 제안 변경 문구 | 영향받는 채점 항목 |
| --- | --- | --- | --- | --- | --- |
| 미확인 | 전체 | 로컬 최종수정본 PDF 2개만 존재 | 로그인 전용 공식 채널의 이후 정정과 첨부를 확인하지 못함 | 최종 게시물 수정일, 마지막 댓글과 최신 첨부명을 명시 | 전체 |
| 유지 | 문제지 Analytics 5 / 채점 2-5 | 문제지는 Apache Flink 1.19, 채점은 `ZEPPELIN-FLINK-3_0` | Flink 1.19 일반 application runtime과 Studio Zeppelin runtime은 다른 계약이며 Studio는 Flink 1.19를 지원하지 않음 | Studio Notebook에서 사용할 하나의 runtime 식별자로 통일 | 2-5 |
| 유지 | 채점 MSK 3-1 준비 명령 | `BUCKET_NAME`에 `wsc2026-student-score-bucket-<비번호>` 사용 | MSK 문제지와 예상 출력은 `wsc2026-sensor-alert-bucket-<비번호>`를 요구함 | 준비 명령의 버킷명을 sensor-alert 버킷으로 수정 | 3-1 |
| 유지 | 채점 MSK 3-1 예상 출력 | 일반 S3 버킷의 `HeadBucket` 결과에 `BucketArn` 기대 | AWS 문서상 `BucketArn`은 directory bucket에만 지원되며 일반 버킷은 CLI 버전에 따라 빈 값 또는 제한된 출력이 가능함 | 존재 여부는 종료 코드로, 리전은 `get-bucket-location` 등으로 별도 검사 | 3-1 |
| 유지 | 채점 1번 준비·1-2, 3번 준비·3-3 | 닫는 따옴표 `“`, `—query`, `—output`, `grep –A2` 사용 | 유니코드 따옴표와 대시는 POSIX shell/AWS CLI 옵션으로 해석되지 않아 그대로 실행하면 실패함 | ASCII `"`, `--query`, `--output`, `grep -A2`로 변경 | 1-1~1-2, 3-1~3-3 |
| 유지 | 채점 Analytics 2-1 | instance type과 subnet ID를 함께 `describe-subnets --subnet-ids`로 전달 | `t3.small`이 subnet ID 인수에 포함되어 첫 명령이 실패하고 `||` 뒤의 우회 명령에 의존함 | subnet ID만 먼저 변수에 저장해 조회 | 2-1 |
| 유지 | 문제지 Workflow 1·6 | `/input/test.csv`와 `input/test.csv`를 혼용 | S3 key의 선행 `/` 유무가 달라 trigger filter와 처리 대상이 달라질 수 있으며 채점 출력은 `input/`을 기대함 | `input/test.csv`, `processed/`, `error/`로 통일 | 1-1, 1-5, 1-6 |
| 유지 | 문제지 MSK 7 | `awsapi head-bucket` | 유효한 AWS CLI 명령이 아님 | `aws s3api head-bucket`으로 변경 | 3-1 |
| 미확인 | 문제지 공통 유의사항 7·10 | 채점용 Bastion 생성과 모든 Resource 접근 요구 | 리전·VPC·이름·사양이 없고 실제 채점 절차는 CloudShell과 SSM을 사용함 | Bastion 요구를 삭제하거나 정확한 module별 사양과 채점 용도를 추가 | 전체 |

공식 정정이 확인되면 즉시 삭제하지 않고 `해소(정정일·정정 문구·첨부명)`로 바꾼 뒤 문제지, 채점 기준, 배포 자산과 구현을 다시 대조한다.
