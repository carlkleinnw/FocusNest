param([switch]$NoOpen)
$ErrorActionPreference='Stop'
$webRoot=Join-Path $PSScriptRoot 'build/web'
$serverScript=Join-Path $PSScriptRoot 'scripts/serve_demo.py'
$pythonExe='E:/Conda/python.exe'
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
  throw '找不到演示构建文件，请重新构建或使用完整Demo包。'
}
if (-not (Test-Path -LiteralPath $serverScript)) { throw '缺少本地AI服务，请使用完整新版网页包。' }
if (-not (Test-Path -LiteralPath $pythonExe)) {
  $pythonExe=(Get-Command python -ErrorAction Stop).Source
}
$chosenPort=$null
# Prefer a compatible running service even when an earlier port is now free;
# otherwise a second launch would open a fresh process with no saved key.
foreach ($candidatePort in 8787..8797) {
  $url="http://127.0.0.1:$candidatePort/"
  try {
    $response=Invoke-WebRequest -UseBasicParsing -Uri ($url+'focusnest-demo.json') -TimeoutSec 1
    $bridge=Invoke-RestMethod -Uri ($url+'api/agent/settings') -TimeoutSec 1
    if (($response.Content | ConvertFrom-Json).id -eq 'focusnest-demo-v01' -and $bridge.bridgeVersion -ge 2) {
      $chosenPort=$candidatePort
      break
    }
  } catch {}
}
if ($null -eq $chosenPort) {
foreach ($candidatePort in 8787..8797) {
  $url="http://127.0.0.1:$candidatePort/"
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$candidatePort)
  try {
    $listener.Start()
    $listener.Stop()
    $quotedRoot='"'+$webRoot+'"'
    $arguments=@(('"'+$serverScript+'"'),'--port',"$candidatePort",'--directory',$quotedRoot)
    Start-Process -FilePath $pythonExe -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
    $ready=$false
    for ($attempt=0;$attempt -lt 30;$attempt++) {
      Start-Sleep -Milliseconds 200
      try {
        $response=Invoke-WebRequest -UseBasicParsing -Uri ($url+'focusnest-demo.json') -TimeoutSec 1
        $bridge=Invoke-RestMethod -Uri ($url+'api/agent/settings') -TimeoutSec 1
        if (($response.Content | ConvertFrom-Json).id -eq 'focusnest-demo-v01' -and $bridge.bridgeVersion -ge 2) { $ready=$true; break }
      } catch {}
    }
    if ($ready) { $chosenPort=$candidatePort; break }
  } catch { $listener.Stop() }
}
}
if ($null -eq $chosenPort) { throw '未能启动演示服务，请检查本机端口。' }
$demoUrl="http://127.0.0.1:$chosenPort/#/plans"
if ($NoOpen) { Write-Output $demoUrl } else { Start-Process $demoUrl }
