# Observability grading fix extension

이 root module은 기존 addons state의 리소스 소유권을 가져오지 않고 다음 항목만 추가 관리한다.

- Grafana 전용 CloudWatch Logs 읽기 IRSA 역할
- `cloudwatch` Grafana datasource
- 채점표 전체 패널과 임계치를 포함한 `wsc2026-grafana-dashboard`
- 수정된 6개 Prometheus alert rule

EKS API가 private-only이면 CIDR을 제한한 public endpoint를 배포 시간에만 임시 활성화하거나 VPC 내부에서 실행한다.

```powershell
terraform init -input=false
terraform validate
terraform plan -input=false
terraform apply -input=false
```
