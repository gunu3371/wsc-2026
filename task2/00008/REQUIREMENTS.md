# 2과제 00008 수정본 요구사항 대조표

2026-08-21에 기존 문제·채점 PDF와 `asgmt2_module1_check.sh`~`asgmt2_module4_check.sh`를 `2026년 전국기능경기대회 hwp 수정본/2과제 00008/` PDF와 대조했다. 문제지는 렌더링·추출 텍스트가 기존본과 동일하고 채점지는 9쪽에서 15쪽으로 확장됐다.

| 모듈 | 수정 채점지의 핵심 조건 | 구현 위치 |
| --- | --- | --- |
| DocumentDB | 암호화·백업·KMS, secret의 raw endpoint hostname, BSON date, index와 TTL | `documentdb/main.tf` |
| Lattice | service EC2 public IP 금지, TCP 8080을 Lattice managed prefix list에서만 허용 | `lattice/main.tf` |
| Cloud Event | 직접 Lambda 복구가 180초 이내 성공하며 CloudTrail 전달 지연은 미채점 | `cloud-event/main.tf` |
| SQS | Visibility Timeout 30초 이상 | `sqs-eks/infra/main.tf` |
| KEDA | min 0, max 6, polling ≤15, cooldown ≤30, queueLength 2, `podIdentity.provider=aws-eks` | `sqs-eks/addons/workloads/02-autoscaling.tf` |
| Karpenter | NodePool label·NodeClassRef·consolidation 및 role/instanceProfile | `sqs-eks/addons/workloads/03-karpenter.tf` |
| Scaling | 메시지 12개 전송 후 180초 안에 worker 증가와 Ready Karpenter node 확인 | 실제 AWS 채점 단계 |

공식 스크립트와 지급 자산은 수정하지 않는다.
