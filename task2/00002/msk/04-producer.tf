resource "aws_iam_role" "producer" {
  name = "wsc2026-msk-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "producer_ssm" {
  role       = aws_iam_role.producer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "producer" {
  role = aws_iam_role.producer.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"], Resource = aws_msk_cluster.this.arn
      }, {
      Effect = "Allow", Action = ["kafka-cluster:CreateTopic", "kafka-cluster:DescribeTopic", "kafka-cluster:WriteData"], Resource = "arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:topic/wsc2026-msk-cluster/*/*"
      }, {
      Effect = "Allow", Action = "s3:GetObject", Resource = aws_s3_object.producer.arn
    }]
  })
}
resource "aws_iam_instance_profile" "producer" {
  name = "wsc2026-sensor-producer-profile"
  role = aws_iam_role.producer.name
}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_instance" "producer" {
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.clients.id]
  iam_instance_profile   = aws_iam_instance_profile.producer.name
  user_data = templatefile("${path.module}/../assets/msk/user_data.sh.tftpl", {
    bucket = aws_s3_bucket.alert.id, bootstrap = aws_msk_cluster.this.bootstrap_brokers_sasl_iam, region = "ap-northeast-1", wrapper_base64 = base64encode(file("${path.module}/../assets/msk/producer-wrapper.sh"))
  })
  tags = {
    Name = "wsc2026-sensor-producer"
  }
  depends_on = [aws_s3_object.producer]
}
