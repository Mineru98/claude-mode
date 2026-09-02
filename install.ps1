[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$slug = if ($env:CLAUDE_MODE_SLUG) { $env:CLAUDE_MODE_SLUG } else { 'Mineru98/claude-mode' }
$repo = if ($env:CLAUDE_MODE_REPO) { $env:CLAUDE_MODE_REPO } else { "https://github.com/$slug.git" }
$ref = if ($env:CLAUDE_MODE_REF) { $env:CLAUDE_MODE_REF } else { 'main' }
$destination = if ($env:CLAUDE_MODE_HOME) { $env:CLAUDE_MODE_HOME } else { Join-Path $HOME '.claude-mode' }
$pathScope = if ($env:CLAUDE_MODE_PATH_SCOPE) { $env:CLAUDE_MODE_PATH_SCOPE } else { 'User' }

function Say([string]$Message) { Write-Host "==> $Message" -ForegroundColor Green }
function Fail([string]$Message) { throw "claude-mode: $Message" }

function Find-ClaudeCommand {
    $installBin = [IO.Path]::GetFullPath((Join-Path $destination 'bin'))
    foreach ($candidate in & where.exe claude 2>$null) {
        $fullPath = [IO.Path]::GetFullPath($candidate)
        $candidateHome = Split-Path -Parent (Split-Path -Parent $fullPath)
        $isModeWrapper = Test-Path -LiteralPath (Join-Path $candidateHome 'claude-mode.ps1')
        if (-not $isModeWrapper -and -not $fullPath.StartsWith($installBin, [StringComparison]::OrdinalIgnoreCase)) { return $fullPath }
    }
    return $null
}

$realClaude = Find-ClaudeCommand
if (-not $realClaude) { Fail 'Claude Code CLI is not available on PATH. Install Claude Code first.' }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { Fail 'git is not available on PATH.' }

$parent = Split-Path -Parent $destination
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

if (Test-Path -LiteralPath (Join-Path $destination '.git')) {
    Say "Updating: $destination"
    & git.exe -C $destination fetch --depth 1 origin $ref
    if ($LASTEXITCODE -ne 0) { Fail "git fetch failed: $repo ($ref)" }
    & git.exe -C $destination checkout --quiet FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { Fail 'git checkout failed' }
} else {
    if (Test-Path -LiteralPath $destination) {
        $backup = "$destination.backup-$([DateTime]::Now.ToString('yyyyMMddHHmmss'))"
        Say "Backing up existing directory: $backup"
        Move-Item -LiteralPath $destination -Destination $backup
    }
    Say "Downloading: $repo ($ref) -> $destination"
    & git.exe clone --quiet --depth 1 --branch $ref $repo $destination
    if ($LASTEXITCODE -ne 0) { Fail "git clone failed: $repo ($ref)" }
}

foreach ($required in @('claude-mode.ps1', 'bin\claude.cmd', 'settings')) {
    if (-not (Test-Path -LiteralPath (Join-Path $destination $required))) { Fail "required installation file is missing: $required" }
}

Set-Content -LiteralPath (Join-Path $destination '.claude-command') -Value $realClaude -Encoding ASCII
$commit = (& git.exe -C $destination rev-parse --short HEAD 2>$null)
@("ref=$ref", "commit=$commit", "date=$([DateTime]::UtcNow.ToString('yyyy-MM-dd'))", 'method=git', "repo=$repo") |
    Set-Content -LiteralPath (Join-Path $destination '.install-info') -Encoding ASCII

$bin = Join-Path $destination 'bin'
if ($pathScope -notin @('User', 'Process')) { Fail 'CLAUDE_MODE_PATH_SCOPE must be User or Process.' }
$savedPath = [Environment]::GetEnvironmentVariable('Path', $pathScope)
$entries = @($savedPath -split ';' | Where-Object { $_ })
if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $bin.TrimEnd('\') })) {
    $newPath = (@($bin) + $entries) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, $pathScope)
    Say "Added to $pathScope PATH: $bin"
}
if (-not (($env:Path -split ';') | Where-Object { $_.TrimEnd('\') -ieq $bin.TrimEnd('\') })) {
    $env:Path = "$bin;$env:Path"
}

Write-Host ''
Write-Host 'claude-mode installation complete' -ForegroundColor Green
Write-Host "  home     $destination"
Write-Host "  original $realClaude"
Write-Host ''
Write-Host 'Open a new PowerShell or CMD window, then run: claude --mode'
