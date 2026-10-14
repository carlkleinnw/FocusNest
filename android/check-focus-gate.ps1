param([Parameter(Mandatory=$true)][string]$JavaHome)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath = Join-Path $ProjectRoot 'build/guard-checks'
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$GatePath = Join-Path $PSScriptRoot 'app/src/main/java/cn/focusnest/focus_pet_demo/FocusGate.java'
$CheckPath = Join-Path $PSScriptRoot 'app/src/test/java/cn/focusnest/focus_pet_demo/FocusGateCheck.java'
$WindowPath = Join-Path $PSScriptRoot 'app/src/main/java/cn/focusnest/focus_pet_demo/ForegroundWindow.java'
& (Join-Path $JavaHome 'bin/javac.exe') -d $OutputPath $GatePath $WindowPath $CheckPath
if ($LASTEXITCODE -ne 0) { throw 'Native guard regression checks did not compile' }
& (Join-Path $JavaHome 'bin/java.exe') -cp $OutputPath cn.focusnest.focus_pet_demo.FocusGateCheck
if ($LASTEXITCODE -ne 0) { throw 'Native guard regression checks failed' }
