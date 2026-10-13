$ErrorActionPreference='Stop'
$webRoot=Join-Path $PSScriptRoot 'build/web'
$pythonExe='E:/Conda/python.exe'
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
  throw '找不到演示构建文件，请重新构建或使用完整Demo包。'
}
if (-not (Test-Path -LiteralPath $pythonExe)) {
  $pythonExe=(Get-Command python -ErrorAction Stop).Source
}
$chosenPort=$null
foreach ($candidatePort in 8787..8797) {
  $url="http://127.0.0.1:$candidatePort/"
  try {
    $response=Invoke-WebRequest -Uri ($url+'focusnest-demo.json') -TimeoutSec 1
    if (($response.Content | ConvertFrom-Json).id -eq 'focusnest-demo-v01') {
      $chosenPort=$candidatePort
      break
    }
  } catch {}
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$candidatePort)
  try {
    $listener.Start()
    $listener.Stop()
    $quotedRoot='"'+$webRoot+'"'
    $arguments=@('-m','http.server',"$candidatePort",'--bind','127.0.0.1','--directory',$quotedRoot)
    Start-Process -FilePath $pythonExe -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
    $ready=$false
    for ($attempt=0;$attempt -lt 30;$attempt++) {
      Start-Sleep -Milliseconds 200
      try {
        $response=Invoke-WebRequest -Uri ($url+'focusnest-demo.json') -TimeoutSec 1
        if (($response.Content | ConvertFrom-Json).id -eq 'focusnest-demo-v01') { $ready=$true; break }
      } catch {}
    }
    if ($ready) { $chosenPort=$candidatePort; break }
  } catch { $listener.Stop() }
}
if ($null -eq $chosenPort) { throw '未能启动演示服务，请检查本机端口。' }
Start-Process "http://127.0.0.1:$chosenPort/#/home"

