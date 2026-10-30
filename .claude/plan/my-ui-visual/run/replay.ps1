# 只读真源与SDK；不安装依赖、不执行Git；浏览器使用现有Chrome无头模式。
$ErrorActionPreference = 'Stop'
$runPath = $PSScriptRoot
$repoPath = (Resolve-Path (Join-Path $runPath '../../../..')).Path
$outPath = (Resolve-Path (Join-Path $runPath '..')).Path
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
$sdkDartPath = 'D:/app/fvm/versions/stable/bin/cache/dart-sdk/bin/dart.exe'
$toolSnapshotPath = Join-Path $runPath 'sdk/bin/cache/flutter_tools.snapshot'
$serverJob = Start-Process -FilePath 'node' -ArgumentList @((Join-Path $runPath 'web-server.mjs')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runPath 'vite-replay.log') -RedirectStandardError (Join-Path $runPath 'vite-replay-error.log')
try {
    # readiness有上限，且只探测本任务专用5189端口。
    $serverReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try { $response = Invoke-WebRequest 'http://127.0.0.1:5189/' -UseBasicParsing; if ($response.StatusCode -eq 200) { $serverReady = $true; break } } catch {}
        Start-Sleep -Milliseconds 250
    }
    if (-not $serverReady) { throw 'Vite未在10秒内启动' }
    & node (Join-Path $runPath 'web-capture.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Web基础截图失败' }
    # 加载态由真实点击采集，补齐Loading与Skeleton实体页面。
    & node (Join-Path $runPath 'web-loading-capture.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Web加载态截图失败' }
    & node (Join-Path $runPath 'web-states.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Web状态截图失败' }
    Push-Location (Join-Path $runPath 'project')
    try {
        & $sdkDartPath $toolSnapshotPath --no-version-check test --no-pub --concurrency=1 --reporter=expanded (Join-Path $repoPath 'test/my_ui/visual_render_test.dart')
        if ($LASTEXITCODE -ne 0) { throw 'Flutter真实渲染失败' }
    } finally { Pop-Location }
    & python (Join-Path $runPath 'compare.py')
    & python (Join-Path $runPath 'state-review.py')
    & python (Join-Path $runPath 'glyph-coverage.py')
} finally {
    # 只结束本脚本启动的专用服务。
    if (-not $serverJob.HasExited) { Stop-Process -Id $serverJob.Id }
}
