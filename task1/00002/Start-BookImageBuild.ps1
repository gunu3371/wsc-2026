[CmdletBinding()]
param(
  [string]$Profile
)

$ErrorActionPreference = "Stop"

$taskRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectName = terraform "-chdir=$taskRoot/extensions/image-build" output -raw project_name
$imageUri = terraform "-chdir=$taskRoot/extensions/image-build" output -raw image_uri
$repositoryName = terraform "-chdir=$taskRoot/extensions/image-build" output -raw repository_name

if ([string]::IsNullOrWhiteSpace($projectName) -or [string]::IsNullOrWhiteSpace($imageUri) -or [string]::IsNullOrWhiteSpace($repositoryName)) {
  throw "image-build extension output을 읽지 못했습니다. 먼저 extension을 apply하십시오."
}

$awsArguments = @("--region", "ap-northeast-2")
if (-not [string]::IsNullOrWhiteSpace($Profile)) {
  $awsArguments += @("--profile", $Profile)
}

function Get-EcrImageScanStatus {
  param(
    [string]$RepositoryName,
    [string]$ImageId
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "SilentlyContinue"
    $scanStatusOutput = & aws @awsArguments ecr describe-image-scan-findings --repository-name $RepositoryName --image-id $ImageId --query "imageScanStatus.status" --output text 2>$null
    $scanStatusExitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($scanStatusExitCode -ne 0) {
    return $null
  }
  return ([string]$scanStatusOutput).Trim()
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

$digest = & aws @awsArguments ecr describe-images --repository-name $repositoryName --image-ids imageTag=stable --query "imageDetails[0].imageDigest" --output text
if ([string]::IsNullOrWhiteSpace($digest) -or $digest -eq "None") {
  throw "ECR에서 stable 이미지 digest를 찾지 못했습니다."
}

$imageId = "imageDigest=$digest"
$scanStatus = Get-EcrImageScanStatus -RepositoryName $repositoryName -ImageId $imageId
if ([string]::IsNullOrWhiteSpace($scanStatus) -or $scanStatus -eq "None") {
  Write-Host "기존 스캔이 없어 ECR 이미지 스캔을 시작합니다."
  & aws @awsArguments ecr start-image-scan --repository-name $repositoryName --image-id $imageId --output json | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "ECR 이미지 스캔을 시작하지 못했습니다: $repositoryName@$digest"
  }
  $scanStatus = "IN_PROGRESS"
}

$scanAttempts = 0
do {
  Start-Sleep -Seconds 5
  $scanAttempts++
  $scanStatus = Get-EcrImageScanStatus -RepositoryName $repositoryName -ImageId $imageId
  if ([string]::IsNullOrWhiteSpace($scanStatus)) {
    $scanStatus = "IN_PROGRESS"
  }
  Write-Host "ECR 이미지 스캔 상태: $scanStatus"
} while ($scanStatus -in @("IN_PROGRESS", "PENDING", "None", "") -and $scanAttempts -lt 120)

if ($scanStatus -notin @("COMPLETE", "ACTIVE")) {
  throw "ECR 이미지 스캔이 정상 완료되지 않았습니다: $scanStatus"
}

$findingCounts = & aws @awsArguments ecr describe-image-scan-findings --repository-name $repositoryName --image-id $imageId --query "imageScanFindings.findingSeverityCounts" --output json
if ($LASTEXITCODE -ne 0) {
  throw "ECR 이미지 스캔 결과를 조회하지 못했습니다: $repositoryName@$digest"
}
Write-Host "ECR 이미지 스캔이 완료됐습니다. 취약점 개수: $findingCounts"
