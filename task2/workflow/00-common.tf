locals {
  # 기존 구현(비활성): 과제번호를 전역 고유 S3 버킷 접미사로 사용
  # bucket = "wsc2026-student-score-bucket-${local.input.task_id}"
  # 정정 적용: 대회에서 부여된 비번호를 버킷 접미사로 사용
  bucket = "wsc2026-student-score-bucket-${local.input.candidate_number}"
}
