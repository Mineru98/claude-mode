$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("claude-mode-test-{0}" -f [guid]::NewGuid())
$source = Join-Path $testRoot 'source'
$fakeBin = Join-Path $testRoot 'fake-bin'
$installPowerShell = Join-Path $testRoot 'powershell-home'
$installCmd = Join-Path $testRoot 'cmd-home'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

try {
    New-Item -ItemType Directory -Path $testRoot, $fakeBin | Out-Null
    & git.exe clone --quiet $root $source
    foreach ($relative in @('claude-mode.ps1', 'install.ps1', 'install.cmd', 'README.md', '.gitignore')) {
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination (Join-Path $source $relative) -Force
    }
    New-Item -ItemType Directory -Path (Join-Path $source 'bin') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'bin\claude.cmd') -Destination (Join-Path $source 'bin\claude.cmd') -Force
    & git.exe -C $source add .
    & git.exe -C $source -c user.name=claude-mode-test -c user.email=test@example.invalid commit --quiet -m test
    $sourceBranch = (& git.exe -C $source branch --show-current).Trim()

    $fakeClaude = Join-Path $fakeBin 'claude.cmd'
    Set-Content -LiteralPath $fakeClaude -Encoding ASCII -Value '@echo off', 'if "%~1"=="--fail" exit /b 23', 'echo REAL_CLAUDE %*'
    $originalPath = $env:Path
    $env:Path = "$fakeBin;$originalPath"
    $env:CLAUDE_MODE_REPO = $source
    $env:CLAUDE_MODE_REF = $sourceBranch
    $env:CLAUDE_MODE_PATH_SCOPE = 'Process'

    $env:CLAUDE_MODE_HOME = $installPowerShell
    & (Join-Path $root 'install.ps1') | Out-Host
    Assert-True (Test-Path -LiteralPath (Join-Path $installPowerShell 'bin\claude.cmd')) 'PowerShell installer did not install the CMD shim'
    $modes = & (Join-Path $installPowerShell 'bin\claude.cmd') --mode
    Assert-True ($modes -contains 'default') 'PowerShell-installed wrapper did not list modes'
    $forwarded = & (Join-Path $installPowerShell 'bin\claude.cmd') --mode default --version
    Assert-True (($forwarded -join ' ') -match 'REAL_CLAUDE.*--version.*--settings') 'mode arguments were not forwarded to the real Claude CLI'
    $terminated = & (Join-Path $installPowerShell 'bin\claude.cmd') --mode default -- prompt
    Assert-True (($terminated -join ' ') -match '--settings .+ -- prompt$') 'injected settings were not placed before --'
    $explicit = & (Join-Path $installPowerShell 'bin\claude.cmd') --mode default --settings=custom.json
    Assert-True ((($explicit -join ' ') -split '--settings').Count -eq 2) 'an explicit --settings value was duplicated'
    & (Join-Path $installPowerShell 'bin\claude.cmd') --fail
    Assert-True ($LASTEXITCODE -eq 23) 'the real Claude CLI exit code was not preserved'
    $ErrorActionPreference = 'Continue'
    & (Join-Path $installPowerShell 'bin\claude.cmd') --mode missing 2>$null
    $unknownModeExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Assert-True ($unknownModeExitCode -ne 0) 'an unknown mode unexpectedly succeeded'
    & (Join-Path $root 'install.ps1') | Out-Host

    $env:CLAUDE_MODE_HOME = $installCmd
    $env:CLAUDE_MODE_INSTALL_URL = ([uri](Join-Path $root 'install.ps1')).AbsoluteUri
    & cmd.exe /d /c (Join-Path $root 'install.cmd')
    Assert-True ($LASTEXITCODE -eq 0) 'CMD installer returned a non-zero exit code'
    Assert-True (Test-Path -LiteralPath (Join-Path $installCmd 'claude-mode.ps1')) 'CMD installer did not install the PowerShell wrapper'
    $cmdModes = & cmd.exe /d /c "`"$(Join-Path $installCmd 'bin\claude.cmd')`" --mode"
    Assert-True (($cmdModes -split "`r?`n") -contains 'default') 'CMD-installed wrapper did not list modes'

    Write-Host 'Windows installer tests passed.' -ForegroundColor Green
} finally {
    $env:Path = $originalPath
    Remove-Item Env:CLAUDE_MODE_REPO, Env:CLAUDE_MODE_REF, Env:CLAUDE_MODE_HOME, Env:CLAUDE_MODE_PATH_SCOPE, Env:CLAUDE_MODE_INSTALL_URL -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
