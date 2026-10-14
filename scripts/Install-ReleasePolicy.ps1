param([string]$ProjectPath = '')
$ErrorActionPreference = 'Stop'
if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
& git -C $ProjectPath rev-parse --show-toplevel | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'ProjectPath must be an existing Git repository.' }
& git -C $ProjectPath config --local core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { throw 'Could not install the repository hook path.' }
& git -C $ProjectPath config --local push.followTags true
if ($LASTEXITCODE -ne 0) { throw 'Could not enable annotated tag publishing.' }
Write-Host 'FocusNest release policy installed: branch updates need annotated version tags.'
