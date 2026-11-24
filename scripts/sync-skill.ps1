param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir = Split-Path -Parent $scriptDir

$gitRoot = git -C $skillDir rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitRoot) {
    Write-Output "STATUS=NOT_A_GIT_REPO"
    exit 0
}

$version = "unknown"
$pkgPath = Join-Path $gitRoot "package.json"
if (Test-Path $pkgPath) {
    try {
        $version = (Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json).version
    } catch {}
}

$localSha = (git -C $gitRoot rev-parse --short HEAD 2>$null)
$branch = (git -C $gitRoot rev-parse --abbrev-ref HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $branch) {
    Write-Output "STATUS=NO_HEAD"
    exit 0
}

$upstream = (git -C $gitRoot rev-parse --abbrev-ref "@{u}" 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $upstream) {
    $upstream = "origin/$branch"
}

$prevPrompt = $env:GIT_TERMINAL_PROMPT
$prevGcm = $env:GCM_INTERACTIVE
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE = "never"
try {
    git -C $gitRoot fetch origin --tags --quiet 2>$null
    $fetchExit = $LASTEXITCODE
} finally {
    $env:GIT_TERMINAL_PROMPT = $prevPrompt
    $env:GCM_INTERACTIVE = $prevGcm
}

if ($fetchExit -ne 0) {
    Write-Output "STATUS=OFFLINE_OR_AUTH_FAILED"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    exit 0
}

git -C $gitRoot rev-parse --verify $upstream 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output "STATUS=NO_UPSTREAM_REF"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    exit 0
}

$behindOut = git -C $gitRoot rev-list --count "HEAD..$upstream" 2>$null
$aheadOut = git -C $gitRoot rev-list --count "$upstream..HEAD" 2>$null
$behind = if ($behindOut -match '^\d+$') { [int]$behindOut } else { 0 }
$ahead = if ($aheadOut -match '^\d+$') { [int]$aheadOut } else { 0 }
$dirty = git -C $gitRoot status --porcelain 2>$null

if ($behind -eq 0 -and $ahead -eq 0) {
    Write-Output "STATUS=UP_TO_DATE"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    exit 0
}

if ($behind -eq 0 -and $ahead -gt 0) {
    Write-Output "STATUS=AHEAD"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    Write-Output "AHEAD_COUNT=$ahead"
    exit 0
}

if ($ahead -gt 0 -and $behind -gt 0) {
    Write-Output "STATUS=DIVERGED"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    exit 0
}

if ($dirty) {
    Write-Output "STATUS=DIRTY_BEHIND"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    Write-Output "BEHIND_COUNT=$behind"
    exit 0
}

if ($CheckOnly) {
    Write-Output "STATUS=UPDATE_AVAILABLE"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    Write-Output "BEHIND_COUNT=$behind"
    exit 0
}

$prevPrompt = $env:GIT_TERMINAL_PROMPT
$prevGcm = $env:GCM_INTERACTIVE
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE = "never"
try {
    git -C $gitRoot pull --ff-only origin $branch --quiet 2>$null
    $pullExit = $LASTEXITCODE
} finally {
    $env:GIT_TERMINAL_PROMPT = $prevPrompt
    $env:GCM_INTERACTIVE = $prevGcm
}

if ($pullExit -ne 0) {
    Write-Output "STATUS=PULL_FAILED"
    Write-Output "VERSION=$version"
    Write-Output "COMMIT=$localSha"
    exit 0
}

$newSha = (git -C $gitRoot rev-parse --short HEAD 2>$null)
$newVersion = $version
if (Test-Path $pkgPath) {
    try {
        $newVersion = (Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json).version
    } catch {}
}

Write-Output "STATUS=UPDATED"
Write-Output "OLD_VERSION=$version"
Write-Output "NEW_VERSION=$newVersion"
Write-Output "OLD_COMMIT=$localSha"
Write-Output "NEW_COMMIT=$newSha"
