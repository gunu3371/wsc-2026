# wsc-2026-2

과제번호별 구현은 1과제와 2과제를 서로 독립된 루트로 관리한다.

- 1과제: `task1/00002`, `task1/00003`, `task1/00007`
- 2과제: `task2/00002`, `task2/00007`
- 3과제: `task3`

같은 과제번호라도 `task1/<과제번호>`와 `task2/<과제번호>`는 디렉터리, `terraform.tfvars`, Terraform root module/state, 적용·채점·정리 절차를 공유하지 않는다. 각 과제의 `README.md`를 기준으로 해당 과제 디렉터리에서 실행한다.
