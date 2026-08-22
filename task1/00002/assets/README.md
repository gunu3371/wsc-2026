# 00002 Terraform 자산

Terraform 입력 파일은 이 디렉터리에서 root module별로 관리한다. `foundation`은 `assets/foundation/...`을 읽고, 둘 이상의 root module이 사용하는 공식 book 바이너리와 Dockerfile은 `assets/shared/book-image/`에 둔다. 생성 ZIP은 `assets/` 밖의 실행 산출물이다.

2026-08-23에 `1과제 촤종수정본/asset/`과 비교한 결과 다음 파일은 바이트 단위로 동일했다.

| 파일 | SHA-256 |
| --- | --- |
| `assets/shared/book-image/book` | `2DAF6413950E1FF58256D6ECB978BEB86EF44007BAAFC08EAA98C4EC48EC4826` |
| `assets/foundation/main.jpeg` | `84D3C06330A0F08F77E44B84960F7708505F7816AF9310AD64DFB11C4A2C1D0A` |

최종 asset 폴더에는 `index.html`이 없으므로 기존 공식 `assets/foundation/index.html`을 유지한다. 공식 원본과 최종 release candidate 폴더는 수정하지 않는다.
