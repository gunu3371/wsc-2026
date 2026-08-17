# 3과제 요구사항 대조표

재확인일: 2026-08-17

기준 자료:

- `2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_문제지_v1.0.0.pdf`
- `2026 클라우드컴퓨팅 직종 과제출제 기준 및 양식 등_260524수정(파일오류 수정등)/(붙임3) 2026_클라우드컴퓨팅_직종 과제출제 기준 등/2026년_전국대회_3과제_채점기준표_v1.0.0.pdf`

| 구분 | 요구사항 | 구현 위치 |
|---|---|---|
| 리전 | `ap-northeast-2` | 모든 root module의 `versions.tf`, `variables.tf` |
| DB | `apdev-rds-instance`, MySQL Community 8.0, Multi-AZ, `db.t3.micro`, gp3, DB `dev` | `foundation/04-database.tf` |
| 컨테이너 | EKS, EC2 `t3.medium`만 사용, ECR | `foundation/03-cluster.tf`, `05-artifacts.tf` |
| 애플리케이션 | user/product/stress, TCP/8080, 공식 x86 바이너리 이미지 | `application/02-workloads.tf` |
| API | `/v1/user`, `/v1/product`, `/v1/stress`, `/healthcheck` | `application/03-routing.tf` |
| S3 | product 이미지 업로드, 동일 endpoint의 `/images/<object path>` 다운로드 | S3 + CloudFront OAC + CloudFront Function |
| 단일 endpoint | 프로토콜과 호스트만 제출 | CloudFront `endpoint` output |
| 비정상 요청 | WAF 차단 시 403, 미정의 API는 ingress 기본 404 | WAF managed rules/rate rule, nginx ingress |
| 가용성 | 2-AZ, 앱별 2 replicas, PDB, HPA, Multi-AZ DB | foundation/application |
| 성능 | API 캐시 비활성, 정적 이미지 캐시, HPA | CloudFront cache behaviors, HPA |
| 모니터링 | 컨테이너 로그/지표, 오류 탐지, 대시보드 | `extensions/monitoring` |
| 비용 | 단일 NAT, EC2 2대에서 시작, 최대 6대/앱 | foundation/application |

채점표는 실행 중 생성되는 `results_<비번호>.log`의 image download, Exception Handling, API별 availability/performance, cost ratio를 확인합니다. 이 파일은 채점 부하의 비공개 패턴을 하드코딩하지 않고 일반적인 확장·차단·관측 구성을 제공합니다.
