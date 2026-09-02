$ErrorActionPreference = 'Stop'
$ClaudeArgs = @($args)
$modeHome = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsDir = Join-Path $modeHome 'settings'
$realClaudeFile = Join-Path $modeHome '.claude-command'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("claude-mode: $Message")
    exit 1
}

function Get-Modes {
    Get-ChildItem -LiteralPath $settingsDir -Filter 'settings.*.json' -File |
        ForEach-Object { $_.BaseName.Substring('settings.'.Length) } |
        Sort-Object
}

function Invoke-RealClaude([string[]]$Arguments) {
    if (-not (Test-Path -LiteralPath $realClaudeFile)) {
        Fail 'The original Claude CLI path is missing. Run install.ps1 again.'
    }
    $realClaude = (Get-Content -LiteralPath $realClaudeFile -Raw).Trim()
    if (-not (Test-Path -LiteralPath $realClaude)) {
        Fail "The original Claude CLI cannot be found: $realClaude"
    }
    & $realClaude @Arguments
    exit $LASTEXITCODE
}

function Merge-ModeSettings([string]$ModeFile) {
    $localFile = Join-Path (Join-Path $HOME '.claude') 'settings.local.json'
    if (-not (Test-Path -LiteralPath $localFile)) { return $ModeFile }

    try {
        $mode = Get-Content -LiteralPath $ModeFile -Raw | ConvertFrom-Json
        $local = Get-Content -LiteralPath $localFile -Raw | ConvertFrom-Json
    } catch {
        Fail "Unable to read settings JSON: $($_.Exception.Message)"
    }

    if ($null -eq $local.skillOverrides) { return $ModeFile }
    $merged = [ordered]@{}
    foreach ($property in $mode.PSObject.Properties) { $merged[$property.Name] = $property.Value }
    $overrides = [ordered]@{}
    foreach ($property in $local.skillOverrides.PSObject.Properties) { $overrides[$property.Name] = $property.Value }
    if ($null -ne $mode.skillOverrides) {
        foreach ($property in $mode.skillOverrides.PSObject.Properties) { $overrides[$property.Name] = $property.Value }
    }
    $merged['skillOverrides'] = $overrides

    $tempFile = Join-Path ([IO.Path]::GetTempPath()) ("claude-mode-{0}.json" -f [guid]::NewGuid())
    $json = $merged | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($tempFile, $json, [Text.UTF8Encoding]::new($false))
    return $tempFile
}

if ($ClaudeArgs.Count -gt 0) {
    switch ($ClaudeArgs[0]) {
        '--mode-help' {
            Get-Content -LiteralPath (Join-Path $modeHome 'share\usage.txt')
            exit 0
        }
        '--mode-version' {
            $version = (Get-Content -LiteralPath (Join-Path $modeHome 'VERSION') -Raw).Trim()
            Write-Output "claude-mode $version"
            Write-Output "  home   $modeHome"
            Write-Output '  shell  Windows (PowerShell/CMD)'
            if (Test-Path -LiteralPath (Join-Path $modeHome '.install-info')) {
                Get-Content -LiteralPath (Join-Path $modeHome '.install-info') | ForEach-Object { "  $_" }
            }
            exit 0
        }
    }
}

$mode = $null
$remaining = [Collections.Generic.List[string]]::new()
$sawMode = $false
$afterTerminator = $false
for ($index = 0; $index -lt $ClaudeArgs.Count; $index++) {
    $argument = $ClaudeArgs[$index]
    if ($argument -eq '--') {
        $afterTerminator = $true
        $remaining.Add($argument)
    } elseif (-not $afterTerminator -and $argument -eq '--mode') {
        if ($sawMode) { Fail '--mode may only be specified once.' }
        $sawMode = $true
        if ($index + 1 -ge $ClaudeArgs.Count -or $ClaudeArgs[$index + 1].StartsWith('-')) {
            $mode = '-'
        } else {
            $mode = $ClaudeArgs[++$index]
        }
    } elseif (-not $afterTerminator -and $argument.StartsWith('--mode=')) {
        if ($sawMode) { Fail '--mode may only be specified once.' }
        $sawMode = $true
        $mode = $argument.Substring('--mode='.Length)
        if (-not $mode) { $mode = '-' }
    } else {
        $remaining.Add($argument)
    }
}

if ($null -eq $mode) { Invoke-RealClaude $remaining.ToArray() }
if ($mode -eq '-') {
    if ($remaining.Count -gt 0) { Fail '--mode requires a mode name.' }
    Get-Modes
    exit 0
}
if ($mode -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { Fail "Invalid mode name: $mode" }
$modeFile = Join-Path $settingsDir "settings.$mode.json"
if (-not (Test-Path -LiteralPath $modeFile)) {
    [Console]::Error.WriteLine("claude-mode: mode not found: $mode")
    [Console]::Error.WriteLine("Available modes: $((Get-Modes) -join ', ')")
    exit 1
}

$temporarySettings = Merge-ModeSettings $modeFile
try {
    $beforeTerminator = @()
    foreach ($item in $remaining) {
        if ($item -eq '--') { break }
        $beforeTerminator += $item
    }
    $hasSettings = [bool]($beforeTerminator | Where-Object { $_ -eq '--settings' -or $_.StartsWith('--settings=') })
    $hasMcp = [bool]($beforeTerminator | Where-Object { $_ -eq '--mcp-config' -or $_.StartsWith('--mcp-config=') })
    $extra = [Collections.Generic.List[string]]::new()
    if (-not $hasSettings) {
        $extra.Add('--settings')
        $extra.Add($temporarySettings)
    }
    $mcpFile = Join-Path $settingsDir "mcp.$mode.json"
    if ((Test-Path -LiteralPath $mcpFile) -and -not $hasMcp) {
        $extra.Add('--mcp-config')
        $extra.Add($mcpFile)
    }
    $forward = [Collections.Generic.List[string]]::new()
    $inserted = $false
    foreach ($argument in $remaining) {
        if (-not $inserted -and $argument -eq '--') {
            foreach ($item in $extra) { $forward.Add($item) }
            $inserted = $true
        }
        $forward.Add($argument)
    }
    if (-not $inserted) { foreach ($item in $extra) { $forward.Add($item) } }
    Invoke-RealClaude $forward.ToArray()
} finally {
    if ($temporarySettings -ne $modeFile) { Remove-Item -LiteralPath $temporarySettings -Force -ErrorAction SilentlyContinue }
}
