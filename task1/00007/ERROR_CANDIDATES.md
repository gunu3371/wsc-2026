# 00007 오류 후보 및 재확인 기록

- 재확인일: 2026-08-23
- 대조 원본: `01_최종제출본`(안내 기준일 2026-07-28), 재변환 수정본, `1과제 촤종수정본/`의 release candidate 문제지·채점지·`d1-07-mark.sh`·자산
- 공식 채널 확인 범위: 저장소의 최종본·CHANGELOG·배포 파일과 로컬 release candidate
- 확인하지 못한 범위: 인증이 필요한 공식 게시물의 마지막 댓글과 최신 첨부

| 상태 | 페이지/문항 | 현재 문구·현상 | 오류 후보 판단 이유 | 제안 변경 문구/대응 | 영향 채점 항목 |
| --- | --- | --- | --- | --- | --- |
| 미확인 | 최신 정정 여부 | 최종본 안내의 마지막 첨부는 2026-06-14 | 이후 비공개 댓글/첨부 유무를 확인하지 못함 | 공식 게시물의 마지막 댓글·첨부 재확인 | 전체 |
| 미확인 | release candidate 승인 상태 | `1과제 촤종수정본/`은 Git 미추적 폴더이고 PDF 이름도 release candidate임 | 내용은 기존 수정본보다 최신이지만 공식 채널의 최종 승인 여부를 로컬 파일만으로 확정할 수 없음 | 대회 전 공식 게시물의 최신 첨부명·게시일과 SHA-256 확인 | 전체 |
| 유지 | Kubernetes 채점 | private EKS의 채점 접속 경로는 실행 주체에 따라 다름 | 협의회 메모는 CloudShell 접근을 우선 안내 | 베스천은 실제 필요할 때만 독립 extension으로 만들고 CloudShell 접근부터 검증 | EKS |
| 해소(로컬 release candidate, 공식 게시 미확인) | EKS 인증 방식 | 기존 문제지는 EKS Access Entry 사용과 aws-auth 금지를 강제했으나 최종 후보 문제지에서 해당 문구가 삭제됨. 최종 `d1-07-mark.sh`에는 authentication mode 조회만 남음 | 채점 PDF에는 예상값과 배점 조건이 없으므로 특정 인증 방식이 더 이상 정답으로 강제되지 않음 | private endpoint를 유지하고 현재 Terraform의 `API` 인증은 적용 주체 접근을 위한 구현 선택으로 문서화 | 6-1-A, Kubernetes 채점 준비 |
| 유지(AWS 권한 모델 제약) | 11 Security / 감사 역할 | 문제지는 wildcard resource를 금지하지만 `ec2:DescribeVpcs`는 리소스 수준 ARN 제한을 지원하지 않음 | 실제 허용 테스트를 통과하려면 해당 action의 `Resource`가 `*`여야 함 | action은 `ec2:DescribeVpcs` 하나로 제한하고 나머지 DynamoDB/EKS는 정확한 ARN 사용 | 9-1-A, 9-2-A |
| 해소(로컬 수정본 PDF, 공식 게시 미확인) | WAF override | 기존 문구는 managed rule override와 custom response의 관계가 모호했음 | 수정 문제지는 custom response에 override가 필요할 수 있고 XSS로 채점한다고 명시 | 현재 custom response override 구현을 유지하고 공식 게시 여부 확인 | WAF |
| 해소(로컬 수정본 PDF, 공식 게시 미확인) | Timestamp UTC/KST | 기존 자료 사이에 UTC와 KST 기대값 차이가 있었음 | 수정 채점지는 Timestamp가 UTC 또는 KST일 수 있다고 명시 | 현재 UTC 애플리케이션 timestamp를 유지 | 12-1-A |

정정이 확인되면 행은 `해소(정정일·정정 문구·첨부명)`으로 보존하고 문제지·채점지·스크립트와 구현을 재검증한다.
