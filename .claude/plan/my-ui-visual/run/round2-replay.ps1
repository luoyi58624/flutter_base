# round 2：只读真源、私有 SDK/PUB_CACHE；仅运行 my_ui 子集，无前台窗口、无 Git。
$ErrorActionPreference = 'Stop'
$runPath = $PSScriptRoot
$repoPath = (Resolve-Path (Join-Path $runPath '../../../..')).Path
$outPath = Join-Path $runPath '../round2'
& node (Join-Path $runPath 'setup-runtime.mjs')
if ($LASTEXITCODE -ne 0) { throw '隔离缓存初始化失败' }
$env:PUB_CACHE = 'D:/data/pub-cache'
$env:FLUTTER_ROOT = Join-Path $runPath 'sdk'
$env:LOCALAPPDATA = Join-Path $runPath 'runtime/local'
$env:APPDATA = Join-Path $runPath 'runtime/roaming'
$env:MY_UI_VISUAL_OUT = $outPath
$env:MY_UI_SDK = 'D:/app/fvm/versions/stable'
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
if (-not [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) { [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', [Environment]::GetFolderPath('ProgramFilesX86'), 'Process') }
if (-not $env:ProgramFiles) { $env:ProgramFiles = [Environment]::GetFolderPath('ProgramFiles') }
$dartPath = 'D:/app/fvm/versions/stable/bin/cache/dart-sdk/bin/dart.exe'
$snapshotPath = Join-Path $runPath 'sdk/bin/cache/flutter_tools.snapshot'
$serverJob = Start-Process -FilePath 'node' -ArgumentList @((Join-Path $runPath 'web-server.mjs')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runPath 'round2-vite-replay.log') -RedirectStandardError (Join-Path $runPath 'round2-vite-replay-error.log')
try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($serverJob.HasExited) { throw '专用 Vite 服务退出；检查端口5189是否已占用' }
        try { $response = Invoke-WebRequest 'http://127.0.0.1:5189/' -UseBasicParsing; if ($response.StatusCode -eq 200) { $ready = $true; break } } catch {}
        Start-Sleep -Milliseconds 250
    }
    if (-not $ready) { throw 'Vite 未在10秒内启动' }
    foreach ($file in @('round2-font-probe.mjs','round2-web-capture.mjs','round2-web-states.mjs','round2-font-baseline.mjs')) {
        & node (Join-Path $runPath $file)
        if ($LASTEXITCODE -ne 0) { throw "Web采集失败：$file" }
    }
    Push-Location (Join-Path $runPath 'project')
    try {
        & $dartPath $snapshotPath --no-version-check analyze --no-pub (Join-Path $repoPath 'lib/src/my_ui') (Join-Path $repoPath 'test/my_ui')
        if ($LASTEXITCODE -ne 0) { throw '定向分析失败' }
        & $dartPath $snapshotPath --no-version-check test --no-pub --concurrency=1 --reporter=expanded (Join-Path $repoPath 'test/my_ui')
        if ($LASTEXITCODE -ne 0) { throw 'my_ui子集测试失败' }
    } finally { Pop-Location }
    foreach ($file in @('round2-compare.py','round2-state-review.py','round2-measure.py')) {
        & python (Join-Path $runPath $file)
        if ($LASTEXITCODE -ne 0) { throw "对照生成失败：$file" }
    }
} finally {
    if (-not $serverJob.HasExited) { Stop-Process -Id $serverJob.Id }
}
