[CmdletBinding()]
param(
  [string]$Profile
)

$ErrorActionPreference = "Stop"

$taskRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectName = terraform "-chdir=$taskRoot/extensions/image-build" output -raw project_name
$imageUri = terraform "-chdir=$taskRoot/extensions/image-build" output -raw image_uri

if ([string]::IsNullOrWhiteSpace($projectName) -or [string]::IsNullOrWhiteSpace($imageUri)) {
  throw "image-build extension output을 읽지 못했습니다. 먼저 extension을 apply하십시오."
}

$awsArguments = @("--region", "ap-northeast-2")
if (-not [string]::IsNullOrWhiteSpace($Profile)) {
  $awsArguments += @("--profile", $Profile)
}

$buildId = & aws @awsArguments codebuild start-build --project-name $projectName --query "build.id" --output text
if ([string]::IsNullOrWhiteSpace($buildId) -or $buildId -eq "None") {
  throw "CodeBuild 시작에 실패했습니다. AWS CLI 자격 증명과 권한을 확인하십시오."
}

Write-Host "CodeBuild를 시작했습니다: $buildId"
do {
  Start-Sleep -Seconds 5
  $status = & aws @awsArguments codebuild batch-get-builds --ids $buildId --query "builds[0].buildStatus" --output text
  Write-Host "CodeBuild 상태: $status"
} while ($status -in @("IN_PROGRESS", "QUEUED"))

if ($status -ne "SUCCEEDED") {
  throw "이미지 빌드에 실패했습니다. CloudWatch Logs 그룹 /aws/codebuild/wskorea26-image-build 를 확인하십시오."
}

Write-Host "이미지를 푸시했습니다: $imageUri"
