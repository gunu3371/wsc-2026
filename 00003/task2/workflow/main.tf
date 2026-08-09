resource "aws_s3_bucket" "orders" { bucket = "wsc2026-order-pipeline" }
resource "aws_s3_bucket_public_access_block" "orders" { bucket = aws_s3_bucket.orders.id
block_public_acls = true
block_public_policy = true
ignore_public_acls = true
restrict_public_buckets = true }
resource "aws_s3_bucket_versioning" "orders" { bucket = aws_s3_bucket.orders.id
versioning_configuration { status = "Enabled" } }
resource "aws_s3_object" "sample" { bucket = aws_s3_bucket.orders.id
key = "incoming/sample-orders.json"
source = "${path.module}/${var.orders_file}"
etag = filemd5("${path.module}/${var.orders_file}") }

resource "aws_dynamodb_table" "orders" { name = "wsc2026-orders"
billing_mode = "PAY_PER_REQUEST"
hash_key = "order_id"
attribute { name = "order_id"
type = "S" }
point_in_time_recovery { enabled = true } }
resource "aws_dynamodb_table" "inventory" { name = "wsc2026-inventory"
billing_mode = "PAY_PER_REQUEST"
hash_key = "product_id"
attribute { name = "product_id"
type = "S" }
point_in_time_recovery { enabled = true } }
resource "aws_dynamodb_table" "history" { name = "wsc2026-pipeline-history"
billing_mode = "PAY_PER_REQUEST"
hash_key = "execution_id"
range_key = "started_at"
attribute { name = "execution_id"
type = "S" }
attribute { name = "started_at"
type = "S" }
ttl { attribute_name = "expires_at"
enabled = true } }
locals { inventory = jsondecode(file("${path.module}/${var.inventory_file}")) }
resource "aws_dynamodb_table_item" "inventory" { for_each = { for item in local.inventory : item.product_id => item }
table_name = aws_dynamodb_table.inventory.name
hash_key = aws_dynamodb_table.inventory.hash_key
item = jsonencode({ product_id = { S = each.value.product_id }, product_name = { S = each.value.product_name }, stock = { N = tostring(each.value.stock) }, category = { S = each.value.category } }) }

data "aws_iam_policy_document" "lambda_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["lambda.amazonaws.com"] } } }
resource "aws_iam_role" "lambda" { name = "wsc2026-order-lambda-role"
assume_role_policy = data.aws_iam_policy_document.lambda_assume.json }
resource "aws_iam_role_policy_attachment" "lambda_logs" { role = aws_iam_role.lambda.name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" }
data "archive_file" "validator" { type = "zip"
source_file = "${path.module}/assets/validator.py"
output_path = "${path.module}/validator.zip" }
data "archive_file" "payment" { type = "zip"
source_file = "${path.module}/assets/payment.py"
output_path = "${path.module}/payment.zip" }
resource "aws_lambda_function" "validator" { function_name = "wsc2026-order-validator"
role = aws_iam_role.lambda.arn
runtime = "python3.13"
handler = "validator.handler"
filename = data.archive_file.validator.output_path
source_code_hash = data.archive_file.validator.output_base64sha256 }
resource "aws_lambda_function" "payment" { function_name = "wsc2026-payment-processor"
role = aws_iam_role.lambda.arn
runtime = "python3.13"
handler = "payment.handler"
filename = data.archive_file.payment.output_path
source_code_hash = data.archive_file.payment.output_base64sha256 }

data "aws_iam_policy_document" "sfn_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["states.amazonaws.com"] } } }
resource "aws_iam_role" "sfn" { name = "wsc2026-order-pipeline-role"
assume_role_policy = data.aws_iam_policy_document.sfn_assume.json }
resource "aws_iam_policy" "sfn" { name = "wsc2026-order-pipeline-policy"
policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.orders.arn}/incoming/*" }, { Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [aws_lambda_function.validator.arn, aws_lambda_function.payment.arn, "${aws_lambda_function.validator.arn}:*", "${aws_lambda_function.payment.arn}:*"] }, { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"], Resource = [aws_dynamodb_table.orders.arn, aws_dynamodb_table.inventory.arn, aws_dynamodb_table.history.arn] }] }) }
resource "aws_iam_role_policy_attachment" "sfn" { role = aws_iam_role.sfn.name
policy_arn = aws_iam_policy.sfn.arn }
resource "aws_sfn_state_machine" "orders" { name = "wsc2026-order-pipeline"
role_arn = aws_iam_role.sfn.arn
type = "STANDARD"
definition = templatefile("${path.module}/assets/pipeline.asl.json.tftpl", { validator_arn = aws_lambda_function.validator.arn, payment_arn = aws_lambda_function.payment.arn, orders_table = aws_dynamodb_table.orders.name, inventory_table = aws_dynamodb_table.inventory.name, history_table = aws_dynamodb_table.history.name }) }

output "state_machine_arn" { value = aws_sfn_state_machine.orders.arn }
output "input_example" { value = jsonencode({ bucket = aws_s3_bucket.orders.id, key = aws_s3_object.sample.key }) }
