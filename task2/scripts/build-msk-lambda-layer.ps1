param(
    [string]$PythonCommand = "py",
    [string[]]$PythonArguments = @("-3.14")
)

$ErrorActionPreference = "Stop"
$taskRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $taskRoot "msk/.build"
$pythonRoot = Join-Path $buildRoot "python"
$requirements = Join-Path $taskRoot "assets/msk/lambda/requirements.txt"
$layerZip = Join-Path $buildRoot "kafka-python-layer.zip"

if (Test-Path -LiteralPath $pythonRoot) {
    Remove-Item -LiteralPath $pythonRoot -Recurse -Force
}
if (Test-Path -LiteralPath $layerZip) {
    Remove-Item -LiteralPath $layerZip -Force
}

New-Item -ItemType Directory -Path $pythonRoot -Force | Out-Null
& $PythonCommand @PythonArguments -m pip install --requirement $requirements --target $pythonRoot
if ($LASTEXITCODE -ne 0) {
    throw "Lambda layer dependency installation failed with exit code $LASTEXITCODE."
}

$binRoot = Join-Path $pythonRoot "bin"
if (Test-Path -LiteralPath $binRoot) {
    Remove-Item -LiteralPath $binRoot -Recurse -Force
}
Get-ChildItem -LiteralPath $pythonRoot -Directory -Filter "__pycache__" -Recurse |
    Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath $pythonRoot -File -Filter "*.pyc" -Recurse |
    Remove-Item -Force

Compress-Archive -Path $pythonRoot -DestinationPath $layerZip -CompressionLevel Optimal
Write-Output $layerZip
