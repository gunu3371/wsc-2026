# 3과제 오류·누락 후보

- 재확인일: 2026-08-17
- 대조 원본: 문제지 v1.0.0, 채점기준표 v1.0.0
- 공식 채널 확인 범위: 저장소에 보관된 PDF/HWP, `docs/2026-07-31 직종협의회.md`, 2026-08-17 공개 웹 검색. 공개 마이스터넷 자료실 검색에서는 동일 파일명이나 정정 게시물을 찾지 못했다.
- 확인하지 못한 범위: 로그인이 필요한 마이스터넷 게시물의 마지막 댓글과 최신 첨부. 따라서 공식 정정이 없다고 단정하지 않는다.

| 상태 | 페이지/문항 | 현재 문구 | 오류라고 판단한 이유 | 제안 변경 문구 | 영향받는 채점 항목 |
|---|---|---|---|---|---|
| 미확인 | 문제지 5쪽 product PUT | `include an small image file.` | Content-Type, multipart field명, body 구조, S3 object key 규칙이 없다. 공식 바이너리의 수용 형식을 Terraform에서 확정할 수 없다. | PUT 요청 형식과 저장 object key를 예제로 명시 | 1-1~1-4 image download, product availability/performance |
| 미확인 | 문제지 5~6쪽 product/S3 | product 환경변수 표에 S3 bucket/region key가 없음 | bucket 이름은 자유인데 실행 바이너리에 전달하는 공식 인터페이스가 정의되지 않았다. | S3 bucket과 region 환경변수 이름 명시 | image download, product API 전체 |
| 미확인 | 문제지 3쪽 DB | `load_user.dump` 사용 지시 | 현재 수집된 공식 3과제 폴더에 dump와 user/product/stress 바이너리가 없다. | 전체 지급 파일명과 체크섬을 공지 | user/product availability/performance |
| 미확인 | 채점표 10~11쪽 3-17 | `(product) performance >= 90.0%` | 일련번호상 3-17부터 stress 항목이어야 하며 3-18~3-24는 stress로 표기된다. | `(stress) performance >= 90.0%` | 3-17 |
| 미확인 | 문제지 7쪽 비정상 요청 | 비정상 `/v1/user`는 403, 미제공 `/v1/none`은 404 | 비정상 판정 기준(User-Agent, body, rate 등)이 공개되지 않아 유일한 WAF 규칙을 결정할 수 없다. | 정상/비정상 판정 범위 또는 허용되는 관측 기반 대응 절차 명시 | 1-5~1-8 Exception Handling |
