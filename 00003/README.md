# 00003 Terraform 구현 안내

## 기준 자료

- 문제지: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003/01_최종제출본/61회 전국기능경기대회/1과제/클라우드컴퓨팅_1과제.pdf`
- 채점 자료·스크립트: 같은 경로의 `1과제/채점/`
- 최종본 안내: `37_클라우드컴퓨팅/클라우드컴퓨팅-2026-00003/00_최종본_안내.txt` (기준일 2026-07-28, 마지막 첨부 2026-07-27)
- 운영 참고: `docs/2026-07-31 직종협의회.md`

로그인이 필요한 공식 게시물의 댓글·첨부는 이 저장소만으로 재확인할 수 없다. 확인 범위와 불명확한 사항은 [ERROR_CANDIDATES.md](ERROR_CANDIDATES.md)에 기록한다.

현재 `00003/`에는 1과제 구현만 있다. 공식 최종본의 2과제 자료는 보관돼 있으나 대응 Terraform root module은 아직 없으므로, 이 문서는 존재하는 1과제 범위만 설명한다.

## root module과 state 경계

`task1/platform`은 네트워크, KMS, EKS, 데이터·엣지 기반을 소유한다. `task1/addons`는 생성된 클러스터에 접속하는 Kubernetes/Helm 워크로드와 관측성을 소유한다. 두 경계는 별도 state이며, 같은 디렉터리의 모든 `.tf` 파일은 하나의 root module이다.

| 과제 단계 | 파일 | 경계 |
| --- | --- | --- |
| 공통/provider | `platform/versions.tf`, `variables.tf` | platform |
| 네트워크·KMS·EKS | `network.tf`, `kms.tf`, `eks.tf` | platform |
| 데이터·ECR·S3/Lambda·CDN | `data_registry.tf`, `storage_lambda.tf`, `cdn.tf` | platform |
| Kubernetes 애플리케이션·관측성 | `addons/application.tf`, `observability.tf` | addons |

리전은 `ap-northeast-2`, 플랫폼 VPC CIDR은 `192.168.0.0/16`이다. `candidate_id`, 이미지 digest/URI, AWS profile은 커밋하지 않는 `terraform.tfvars`로 전달한다.

## 실행·채점·정리

각 root module에서 `terraform init -input=false`, `terraform fmt -check`, `terraform validate`, `terraform plan -input=false -var-file=terraform.tfvars` 순으로 실행한다. `platform` 적용 후 immutable 이미지 digest를 확보하고, private EKS API에 접근 가능한 CloudShell에서 platform output과 이미지 URI를 전달해 `addons`를 실행한다. 실제 apply는 요청된 경우에만 수행한다.

원본 `mark.sh`는 수정하지 않는다. CloudShell에서 caller identity, 리전, `aws eks update-kubeconfig` 및 `kubectl` 접근을 확인한 뒤 실행한다. 삭제는 `addons → platform` 순서이며, 데이터 생산자를 먼저 멈추고 S3/CloudWatch/ENI/NAT/EIP/EKS/KMS alias를 AWS API로 재확인한다. KMS 삭제 예약일도 기록한다.
