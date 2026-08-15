# 00008 Terraform 구현 안내

## 기준 자료

- 1·2과제 문제지·채점지·스크립트·제공 파일: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00008/01_최종제출본/national-skills-v7/`
- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00008/00_최종본_안내.txt` (기준일 2026-07-28, 마지막 첨부 2026-06-12)
- 운영 참고: `docs/2026-07-31 직종협의회.md`

로그인이 필요한 공식 게시물의 이후 정정은 이 저장소만으로 확인할 수 없으며, 범위와 오류 후보는 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)에 기록한다.

현재 `00008/`에는 2과제 구현만 있다. 원본 1과제 파일이 작업 트리에서 삭제된 상태이므로, 원본을 복구하거나 공식 최종본에서 다시 확보하기 전에는 1과제를 임의로 재구현하지 않는다.

## 구조와 state 경계

| 과제 | root module | 역할 |
| --- | --- | --- |
| 2과제 모듈 1 | `task2/documentdb` | DocumentDB, client EC2, 제공 데이터/클라이언트 |
| 2과제 모듈 2 | `task2/lattice` | 서비스/클라이언트 VPC와 VPC Lattice |
| 2과제 모듈 3 | `task2/cloud-event` | CloudTrail, EventBridge, SNS, 보안 그룹 복구 Lambda |
| 2과제 모듈 4 기반 | `task2/sqs-eks/infra` | EKS, SQS, ECR, IAM/OIDC/Fargate 기반 |
| 모듈 4 컨트롤러 | `task2/sqs-eks/addons/controllers` | KEDA/Karpenter controller |
| 모듈 4 워크로드 | `task2/sqs-eks/addons/workloads` | worker, KEDA, NodePool/Class |

각 디렉터리는 독립 state이다. `infra`는 AWS 기반만 소유하고 Kubernetes/Helm 객체는 addons가 소유한다. local state 경로를 바꾸거나 이미 적용된 주소를 이동하지 말고, 운영 시에는 안정적인 remote backend 또는 명시적 output 입력으로 전환한다.

주요 리전은 모듈별로 문제지의 `ap-northeast-2`, `ap-northeast-1`, `ap-southeast-1`, `us-west-2`를 따른다. 제공 `worker.py`, `docdb_client.py`, `retail_dataset.json`, Lambda 및 Lattice 애플리케이션은 `assets/`/`lambda/`에서 내용 변경 없이 사용한다.

## 실행·채점·정리

각 root module에서 다음 순서로 실행한다.

```powershell
terraform init -input=false
terraform fmt -check
terraform validate
terraform plan -input=false -var-file=terraform.tfvars
```

SQS/EKS는 `infra → controllers → workloads` 순서다. infra 적용 후 worker 이미지를 ECR에 push하고 immutable digest를 workloads에 전달한다. Kubernetes 채점은 CloudShell에서 `aws sts get-caller-identity`, 대상 리전, `aws eks update-kubeconfig`, `kubectl` 접근을 확인한 뒤 원본 `asgmt*_check.sh`를 수정 없이 실행한다. apply와 채점은 요청된 경우에만 수행하며 채점·수정은 기본 최대 3회다.

삭제는 `workloads → controllers → infra` 후 다른 2과제 module 순서다. CloudTrail/이벤트/애플리케이션 등 producer를 먼저 멈추고, S3·CloudWatch·EKS·ENI/NAT/EIP·ELB·IAM·KMS alias를 AWS API로 교차 확인한다. KMS는 삭제 예약일을 남긴다.
