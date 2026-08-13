resource "aws_iam_role" "sfn" {
  name = "wsc2026-stepfunction-student-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "states.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "sfn" {
  role = aws_iam_role.sfn.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.this.arn}/*"
      }, {
      Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_function.processor.arn
    }]
  })
}
resource "aws_sfn_state_machine" "this" {
  name     = "wsc2026-student-score-workflow"
  type     = "STANDARD"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    Comment = "Student score workflow", StartAt = "CheckS3File", States = {
      CheckS3File = {
        Type = "Task", Resource = "arn:aws:states:::aws-sdk:s3:headObject", Parameters = {
          Bucket = aws_s3_bucket.this.id, "Key.$" = "$.key"
          }, ResultPath = "$.head", Catch = [{
            ErrorEquals = ["States.ALL"], Next = "FileNotFound"
        }], Next        = "ProcessStudentData"
      },
      ProcessStudentData = {
        Type = "Task", Resource = "arn:aws:states:::lambda:invoke", Parameters = {
          FunctionName = aws_lambda_function.processor.arn, "Payload.$" = "$"
          }, OutputPath = "$.Payload", Retry = [{
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"], IntervalSeconds = 2, MaxAttempts = 4, BackoffRate = 2
        }], Next        = "CheckResult"
      },
      CheckResult = {
        Type = "Choice", Choices = [{
          Variable  = "$.statusCode", NumericEquals = 200, Next = "CopyProcessed"
        }], Default = "CopyError"
      },
      CopyProcessed = {
        Type = "Task", Resource = "arn:aws:states:::aws-sdk:s3:copyObject", Parameters = {
          Bucket      = aws_s3_bucket.this.id, "CopySource.$" = "States.Format('${aws_s3_bucket.this.id}/{}', $.key)", "Key.$" = "States.Format('processed/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"
        }, ResultPath = null, Next = "DeleteProcessedSource"
      },
      DeleteProcessedSource = {
        Type = "Task", Resource = "arn:aws:states:::aws-sdk:s3:deleteObject", Parameters = {
          Bucket = aws_s3_bucket.this.id, "Key.$" = "$.key"
        }, End   = true
      },
      CopyError = {
        Type = "Task", Resource = "arn:aws:states:::aws-sdk:s3:copyObject", Parameters = {
          Bucket      = aws_s3_bucket.this.id, "CopySource.$" = "States.Format('${aws_s3_bucket.this.id}/{}', $.key)", "Key.$" = "States.Format('error/{}', States.ArrayGetItem(States.StringSplit($.key, '/'), 1))"
        }, ResultPath = null, Next = "DeleteErrorSource"
      },
      DeleteErrorSource = {
        Type = "Task", Resource = "arn:aws:states:::aws-sdk:s3:deleteObject", Parameters = {
          Bucket = aws_s3_bucket.this.id, "Key.$" = "$.key"
        }, Next  = "ProcessingFailed"
      },
      FileNotFound = {
        Type = "Fail", Error = "S3FileNotFound"
        }, ProcessingFailed = {
        Type = "Fail", Error = "StudentProcessingFailed"
      }
    }
  })
}
