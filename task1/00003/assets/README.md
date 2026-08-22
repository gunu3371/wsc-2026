# Terraform asset layout

Terraform 입력 파일은 소유 root module 경로에 맞춰 둔다. `platform/`에는 정적 웹과 Lambda 소스, `addons/`에는 관측성 파일, `shared/book-image/`에는 공식 book 바이너리와 CodeBuild용 Dockerfile을 둔다. 생성 ZIP과 빌드 산출물은 `assets/`에 두지 않는다.
