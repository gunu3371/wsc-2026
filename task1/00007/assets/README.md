# Terraform asset layout

Terraform 입력 파일은 소유 root module 경로에 맞춰 둔다. `foundation/`에는 공식 웹 파일, `addons/`에는 Lambda·로그 변환·Grafana dashboard, `shared/book-image/`에는 공식 book 바이너리와 CodeBuild용 Dockerfile을 둔다. 생성 ZIP과 빌드 산출물은 `assets/`에 두지 않는다.

2026-08-23 최종 수정 후보 자산 대조 결과:

- `shared/book-image/book`은 `1과제 촤종수정본/asset/book-linux-amd64_v1.0.1`과 SHA-256 `2DAF6413950E1FF58256D6ECB978BEB86EF44007BAAFC08EAA98C4EC48EC4826`으로 일치한다.
- `foundation/main.jpeg`는 최종 후보 `asset/main.jpeg`와 SHA-256 `84D3C06330A0F08F77E44B84960F7708505F7816AF9310AD64DFB11C4A2C1D0A`로 일치한다.
- 최종 후보 asset 폴더에는 `index.html`이 없으므로 기존 공식 제공본을 유지했다. `foundation/index.html`은 기존 공식본과 SHA-256 `E36D98F52EECC96321BBC6F6BBB7597955D44F4E18C04284822695BB9485B5B6`으로 일치한다.
