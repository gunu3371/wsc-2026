data "aws_caller_identity" "current" {}
locals {
  az      = ["a", "d"]
  public  = ["192.168.0.0/24", "192.168.1.0/24"]
  private = ["192.168.10.0/24", "192.168.11.0/24"]
  # 채점표 원문 오류(비활성): BUCKET_NAME="wsc2026-student-score-bucket-<비번호>"
  # 기존 구현(비활성): bucket = "wsc2026-sensor-alert-bucket-${local.input.task_id}"
  # 정정 적용: MSK 문제지의 sensor-alert 이름과 실제 비번호를 사용
  bucket           = "wsc2026-sensor-alert-bucket-${local.input.candidate_number}"
  kafka_layer_path = "${path.module}/.build/kafka-python-layer.zip"
}
