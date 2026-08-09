locals { bucket="wsc2026-student-score-bucket-${var.candidate_id}" }
resource "aws_s3_bucket" "this" { bucket=local.bucket }
resource "aws_s3_bucket_public_access_block" "this" { bucket=aws_s3_bucket.this.id
 block_public_acls=true
 ignore_public_acls=true
 block_public_policy=true
 restrict_public_buckets=true }
resource "aws_s3_object" "folders" { for_each=toset(["input/","processed/","error/"])
 bucket=aws_s3_bucket.this.id
 key=each.value
 content="" }
resource "aws_dynamodb_table" "this" { name="wsc2026-student-score"
 billing_mode="PAY_PER_REQUEST"
 hash_key="studentId"
 range_key="examDate"
 attribute {name="studentId"
type="S"}
 attribute {name="examDate"
type="S"} }

data "archive_file" "processor" { type="zip"
 source_file="${path.module}/lambda/processor.py"
 output_path="${path.module}/processor.zip" }
data "archive_file" "trigger" { type="zip"
 source_file="${path.module}/lambda/trigger.py"
 output_path="${path.module}/trigger.zip" }
resource "aws_iam_role" "lambda" { name="wsc2026-lambda-student-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy" "lambda" { role=aws_iam_role.lambda.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["s3:GetObject","s3:PutObject","s3:DeleteObject"],Resource="${aws_s3_bucket.this.arn}/*"},{Effect="Allow",Action=["dynamodb:PutItem"],Resource=aws_dynamodb_table.this.arn},{Effect="Allow",Action=["states:StartExecution"],Resource=aws_sfn_state_machine.this.arn},{Effect="Allow",Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],Resource="*"}]}) }
resource "aws_lambda_function" "processor" { function_name="wsc2026-student-score-function"
 role=aws_iam_role.lambda.arn
 runtime=var.lambda_runtime
 handler="processor.handler"
 filename=data.archive_file.processor.output_path
 source_code_hash=data.archive_file.processor.output_base64sha256
 environment {variables={S3_BUCKET=aws_s3_bucket.this.id,DDB_TABLE=aws_dynamodb_table.this.name}} }
resource "aws_lambda_function" "trigger" { function_name="wsc2026-student-score-trigger"
 role=aws_iam_role.lambda.arn
 runtime=var.lambda_runtime
 handler="trigger.handler"
 filename=data.archive_file.trigger.output_path
 source_code_hash=data.archive_file.trigger.output_base64sha256
 environment {variables={STATE_MACHINE_ARN=aws_sfn_state_machine.this.arn}} }

resource "aws_iam_role" "sfn" { name="wsc2026-stepfunction-student-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="states.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy" "sfn" { role=aws_iam_role.sfn.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["s3:GetObject","s3:PutObject","s3:DeleteObject"],Resource="${aws_s3_bucket.this.arn}/*"},{Effect="Allow",Action="lambda:InvokeFunction",Resource=aws_lambda_function.processor.arn}]}) }
resource "aws_sfn_state_machine" "this" {
  name="wsc2026-student-score-workflow"
 type="STANDARD"
 role_arn=aws_iam_role.sfn.arn
  definition=jsonencode({Comment="Student score workflow",StartAt="CheckS3File",States={
    CheckS3File={Type="Task",Resource="arn:aws:states:::aws-sdk:s3:headObject",Parameters={Bucket=aws_s3_bucket.this.id,"Key.$"="$.key"},ResultPath="$.head",Catch=[{ErrorEquals=["States.ALL"],Next="FileNotFound"}],Next="ProcessStudentData"},
    ProcessStudentData={Type="Task",Resource="arn:aws:states:::lambda:invoke",Parameters={FunctionName=aws_lambda_function.processor.arn,"Payload.$"="$"},OutputPath="$.Payload",Retry=[{ErrorEquals=["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException"],IntervalSeconds=2,MaxAttempts=4,BackoffRate=2}],Next="CheckResult"},
    CheckResult={Type="Choice",Choices=[{Variable="$.statusCode",NumericEquals=200,Next="CopyProcessed"}],Default="CopyError"},
    CopyProcessed={Type="Task",Resource="arn:aws:states:::aws-sdk:s3:copyObject",Parameters={Bucket=aws_s3_bucket.this.id,"CopySource.$"="States.Format('${aws_s3_bucket.this.id}/{}', $.key)","Key.$"="States.Format('processed/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"},Next="DeleteProcessedSource"},
    DeleteProcessedSource={Type="Task",Resource="arn:aws:states:::aws-sdk:s3:deleteObject",Parameters={Bucket=aws_s3_bucket.this.id,"Key.$"="$.key"},End=true},
    CopyError={Type="Task",Resource="arn:aws:states:::aws-sdk:s3:copyObject",Parameters={Bucket=aws_s3_bucket.this.id,"CopySource.$"="States.Format('${aws_s3_bucket.this.id}/{}', $.key)","Key.$"="States.Format('error/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"},Next="DeleteErrorSource"},
    DeleteErrorSource={Type="Task",Resource="arn:aws:states:::aws-sdk:s3:deleteObject",Parameters={Bucket=aws_s3_bucket.this.id,"Key.$"="$.key"},Next="ProcessingFailed"},
    FileNotFound={Type="Fail",Error="S3FileNotFound"},ProcessingFailed={Type="Fail",Error="StudentProcessingFailed"}
  }})
}
resource "aws_lambda_permission" "s3" { statement_id="AllowS3Invoke"
 action="lambda:InvokeFunction"
 function_name=aws_lambda_function.trigger.function_name
 principal="s3.amazonaws.com"
 source_arn=aws_s3_bucket.this.arn }
resource "aws_s3_bucket_notification" "trigger" { bucket=aws_s3_bucket.this.id
 lambda_function { lambda_function_arn=aws_lambda_function.trigger.arn
 events=["s3:ObjectCreated:*"]
 filter_prefix="input/"
 filter_suffix=".csv" }
 depends_on=[aws_lambda_permission.s3] }

