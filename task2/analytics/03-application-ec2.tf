resource "aws_iam_role" "ec2" {
  name = "wsc2026-analytics-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "kinesis" {
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["kinesis:PutRecord", "kinesis:PutRecords"], Resource = aws_kinesis_stream.orders.arn
    }]
  })
}
resource "aws_iam_instance_profile" "ec2" {
  name = "wsc2026-analytics-ec2-profile"
  role = aws_iam_role.ec2.name
}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  user_data = templatefile("${path.module}/../assets/analytics/user_data.sh.tftpl", {
    app = base64encode(file("${path.module}/../assets/analytics/app.py")), requirements = base64encode(file("${path.module}/../assets/analytics/requirements.txt")), region = "ap-northeast-2", stream = aws_kinesis_stream.orders.name
  })
  tags = {
    Name = "wsc2026-analytics-ec2"
  }
}
