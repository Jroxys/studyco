<#
.SYNOPSIS
    AI Agent Orchestrator - reusable template

.DESCRIPTION
    Reads the task queue from .orchestra/state.json, dispatches tasks to
    claude / codex / agy (Gemini/Antigravity), verifies tests, and saves
    results under .orchestra/.

    Default: DRY-RUN (prerequisite check + queue display only).
    Pass -Execute to actually run a task.

    Before use: fill in the CONFIG section below for your project.

.PARAMETER Execute
    Run the first queued task for real.

.PARAMETER TaskId
    Run a specific task by ID (use with -Execute).

.PARAMETER SkipTests
    Skip the test step after a codex task.

.PARAMETER RunAll
    With -Execute: keep running queued tasks one after another (never in
    parallel), in queue order, always picking the first task whose
    dependencies are done. Stops at the first failed task, when nothing is
    runnable, or after -MaxTasks tasks. Exit code 0 only if everything it ran
    succeeded.

.PARAMETER MaxTasks
    Upper bound for -RunAll (1-50, default 10).

.EXAMPLE
    # Dry-run - checks tools and queue, runs nothing
    .\scripts\orchestrator.ps1

    # Run first queued task
    .\scripts\orchestrator.ps1 -Execute

    # Run specific task
    .\scripts\orchestrator.ps1 -Execute -TaskId "add-login-tests"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Execute,
    [string]$TaskId   = "",
    [switch]$SkipTests,
    [switch]$RunAll,
    [ValidateRange(1, 50)][int]$MaxTasks = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# CONFIG - edit for your project
# =============================================================================
$PROJECT_NAME  = "studyco-backend"
$TEST_COMMAND  = "npm test"   # e.g. "npm test" or "python -m pytest"
$TEST_ARGS     = @()                  # extra args, e.g. @("--", "--reporter=tap")

# Strings that must never appear in an agent prompt (safety filter)
$FORBIDDEN_PATTERNS = @(
    'git push', 'git commit', 'git reset --hard',
    'DROP TABLE', 'TRUNCATE TABLE',
    'rm -rf', 'Remove-Item -Recurse -Force'
)
# Project-specific additions, e.g. @('migrate.js', 'pm2 deploy'). init.ps1 fills this line.
$EXTRA_FORBIDDEN = @('migrate.sh down', 'DROP DATABASE', 'pm2 deploy')  # INIT:EXTRA_FORBIDDEN
$FORBIDDEN_PATTERNS = @($FORBIDDEN_PATTERNS) + @($EXTRA_FORBIDDEN)

# agy (Antigravity / Gemini) is usually NOT in PATH; set the full path here.
# Windows default after running "agy install":
$AGY_EXE = "$env:LOCALAPPDATA\agy\bin\agy.exe"
# macOS/Linux alternative: $AGY_EXE = "$env:HOME/.local/bin/agy"
# =============================================================================

$ROOT        = Split-Path $PSScriptRoot -Parent
$STATE_FILE  = Join-Path $ROOT ".orchestra\state.json"
$REPORTS_DIR = Join-Path $ROOT ".orchestra\reports"
$LOGS_DIR    = Join-Path $ROOT ".orchestra\logs"

# --- Output helpers ----------------------------------------------------------
function Write-Header([string]$msg) {
    Write-Host "`n$('-' * 60)" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "$('-' * 60)" -ForegroundColor Cyan
}
function Write-Ok([string]$msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green  }
function Write-Warn([string]$msg) { Write-Host "  [!!]  $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)  { Write-Host "  [XX]  $msg" -ForegroundColor Red    }
function Write-Info([string]$msg) { Write-Host "  [--]  $msg" -ForegroundColor Gray   }

function Get-Timestamp { (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ") }
function Get-LogSlug   { (Get-Date -Format "yyyyMMdd-HHmmss") }
function Safe-Path([string]$p) {
    try { return (Resolve-Path -Path $p -Relative -ErrorAction Stop) } catch { return $p }
}

# Start-Process cannot launch extensionless shims (e.g. bare "npm" fails with
# "%1 is not a valid Win32 application"), so resolve to a real .exe/.cmd/.bat.
function Resolve-Exe([string]$name) {
    if (Test-Path -LiteralPath $name -PathType Leaf) { return (Resolve-Path -LiteralPath $name).Path }
    $c = @(Get-Command $name -CommandType Application -All -ErrorAction SilentlyContinue |
           Where-Object { $_.Source -match '\.(exe|cmd|bat)$' })
    $e = $c | Where-Object { $_.Source -match '\.exe$' } | Select-Object -First 1
    if ($e) { return $e.Source }
    $o = $c | Select-Object -First 1
    if ($o) { return $o.Source }
    throw "Executable not found: $name"
}

# Start-Process -ArgumentList does NOT quote array elements, so an argument
# containing spaces would be split into several. Build one safely quoted string.
function Join-Args([string[]]$list) {
    $parts = foreach ($a in $list) {
        if ($a -eq '') { '""' }
        elseif ($a -notmatch '[\s"]') { $a }
        else {
            $s = $a -replace '(\\*)"', '$1$1\"'
            $s = $s -replace '(\\+)$', '$1$1'
            '"' + $s + '"'
        }
    }
    return ($parts -join ' ')
}

# Task IDs become file names; keep them to a safe charset.
function Assert-TaskId([string]$id) {
    if ($id -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') {
        throw "Invalid task id '$id' (use lowercase letters, digits and hyphens only)"
    }
}

# --- 1. Prerequisites --------------------------------------------------------
function Test-Prerequisites {
    Write-Header "Prerequisite Check  ($PROJECT_NAME)"
    $ok = $true

    foreach ($tool in @("node", "npm")) {
        try {
            $v = (& $tool --version 2>&1) -join ""
            Write-Ok "$tool $v"
        } catch { Write-Warn "$tool not found (may not be needed for this project)" }
    }

    # claude
    try {
        $v = (claude --version 2>&1) -join ""
        Write-Ok "claude $v"
        $script:CLAUDE_OK = $true
    } catch { Write-Warn "claude CLI not found - claude tasks skipped"; $script:CLAUDE_OK = $false }

    # codex (use exec --help because --version exits non-zero)
    $script:CODEX_OK = $false
    try {
        $raw = (codex exec --help 2>&1) -join ""
        if ($raw -match "non-interactively") {
            Write-Ok "codex exec available"
            $script:CODEX_OK = $true
        } else { Write-Warn "codex found but exec subcommand not recognised" }
    } catch { Write-Warn "codex CLI not found - codex tasks skipped" }

    # agy (Antigravity / Gemini)
    $script:AGY_OK = $false
    if (Test-Path $AGY_EXE) {
        try {
            $job  = Start-Job { & $using:AGY_EXE --version 2>&1 }
            $done = Wait-Job $job -Timeout 6
            if ($done) {
                $v = (Receive-Job $job) -join ""
                Write-Ok "agy (Antigravity) $v  [$AGY_EXE]"
                $script:AGY_OK = $true
            } else {
                Stop-Job $job
                Write-Warn "agy found but --version timed out (interactive binary?)"
            }
            Remove-Job $job -Force 2>$null
        } catch { Write-Warn "agy found but failed to query version" }
    } else {
        Write-Warn "agy not found at $AGY_EXE - gemini/antigravity tasks skipped"
        Write-Info "  Install: https://antigravity.ai  then set AGY_EXE in this script"
    }

    # state.json
    if (-not (Test-Path $STATE_FILE)) {
        Write-Err ".orchestra/state.json missing - run setup first"
        $ok = $false
    } else {
        try {
            $null = Get-Content $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Ok "state.json is valid JSON"
        } catch { Write-Err "state.json is malformed: $_"; $ok = $false }
    }

    return $ok
}

# --- 2. State helpers --------------------------------------------------------
function Read-State {
    return (Get-Content $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-State([pscustomobject]$state) {
    $state.updated_at = Get-Timestamp
    Set-Content -Path $STATE_FILE -Value ($state | ConvertTo-Json -Depth 10) -Encoding UTF8
}

function Get-FirstQueuedTask([string]$filterId = "") {
    $s = Read-State
    if ($filterId) {
        $t = $s.queued  | Where-Object { $_.id -eq $filterId } | Select-Object -First 1
        if (-not $t) { $t = $s.running | Where-Object { $_.id -eq $filterId } | Select-Object -First 1 }
        return $t
    }
    return ($s.queued | Select-Object -First 1)
}

function Move-TaskToRunning([string]$id) {
    $s = Read-State
    $t = $s.queued | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $t) { throw "Task not in queue: $id" }
    $t.status = "running"; $t.started_at = Get-Timestamp
    $s.queued  = @($s.queued  | Where-Object { $_.id -ne $id })
    $s.running = @($s.running) + @($t)
    Write-State $s; return $t
}

function Move-TaskToDone([string]$id, [string]$report = "") {
    $s = Read-State
    $t = $s.running | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $t) { throw "Task not in running: $id" }
    $t.status = "done"; $t.finished_at = Get-Timestamp
    if ($report) { $t.report = $report }
    $s.running = @($s.running | Where-Object { $_.id -ne $id })
    $s.done    = @($s.done) + @($t)
    Write-State $s
}

function Move-TaskToFailed([string]$id, [string]$reason = "", [string]$log = "") {
    $s = Read-State
    $t = $s.running | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $t) { $t = $s.queued | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
    if (-not $t) { Write-Warn "Task not found (may be cleaned up): $id"; return }
    $t.status = "failed"; $t.finished_at = Get-Timestamp
    $t | Add-Member -NotePropertyName "failure_reason" -NotePropertyValue $reason -Force
    $t | Add-Member -NotePropertyName "log"            -NotePropertyValue $log    -Force
    $s.running = @($s.running | Where-Object { $_.id -ne $id })
    $s.queued  = @($s.queued  | Where-Object { $_.id -ne $id })
    $s.failed  = @($s.failed) + @($t)
    Write-State $s
}

# --- 3. Safety filter --------------------------------------------------------
function Test-PromptSafety([string]$prompt) {
    foreach ($pat in $FORBIDDEN_PATTERNS) {
        if ($prompt -match [regex]::Escape($pat)) {
            throw "SAFETY: Prompt contains forbidden pattern: '$pat'"
        }
    }
}

# --- 4. Log / report writers -------------------------------------------------
function Write-Log([string]$slug, [string]$content) {
    $path = Join-Path $LOGS_DIR "$slug.log"
    Set-Content -Path $path -Value $content -Encoding UTF8
    return (Safe-Path $path)
}

function Write-Report([string]$id, [string]$agent, [string]$content) {
    $path = Join-Path $REPORTS_DIR "$id-$agent.md"
    Set-Content -Path $path -Value $content -Encoding UTF8
    return (Safe-Path $path)
}

# --- 5. Test runner ----------------------------------------------------------
function Invoke-Tests([string]$taskId) {
    Write-Header "Running tests: $TEST_COMMAND"
    $outFile = Join-Path $LOGS_DIR "test-stdout-tmp.txt"
    $errFile = Join-Path $LOGS_DIR "test-stderr-tmp.txt"

    $parts   = $TEST_COMMAND -split " ", 2
    $exe     = Resolve-Exe $parts[0]
    $baseArgs = if ($parts.Count -gt 1) { $parts[1] -split " " } else { @() }
    $allArgs  = @($baseArgs) + @($TEST_ARGS)

    $spArgs = @{
        FilePath = $exe
        ArgumentList = (Join-Args $allArgs)
        WorkingDirectory = $ROOT
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
        RedirectStandardOutput = $outFile
        RedirectStandardError = $errFile
    }
    # Splatting, not backtick continuation: Windows PowerShell 5.1 misparses a backtick before a bare LF.
    $proc = Start-Process @spArgs

    $out = if (Test-Path $outFile) { Get-Content $outFile -Raw -Encoding UTF8 } else { "" }
    $err = if (Test-Path $errFile) { Get-Content $errFile -Raw -Encoding UTF8 } else { "" }
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue

    $logPath = Write-Log "$taskId-tests-$(Get-LogSlug)" "STDOUT:`n$out`nSTDERR:`n$err"

    if ($proc.ExitCode -ne 0) {
        Write-Err "Tests FAILED (exit $($proc.ExitCode)). Log: $logPath"
        return @{ Success = $false; LogPath = $logPath }
    }
    Write-Ok "All tests passed. Log: $logPath"
    return @{ Success = $true; LogPath = $logPath }
}

# --- 6. Agent runners --------------------------------------------------------
# The task prompt is written to a file and the agent gets a short, fixed
# instruction pointing at it. This avoids every shell/quoting problem with
# free-form prompt text (spaces, quotes, & | < > ^ % and newlines).
function New-PromptFile([pscustomobject]$task) {
    Assert-TaskId $task.id
    $rel  = ".orchestra/logs/$($task.id)-prompt.md"
    $path = Join-Path $LOGS_DIR "$($task.id)-prompt.md"
    Set-Content -Path $path -Value $task.prompt -Encoding UTF8
    return "Read $rel and carry out the task it describes. Follow the rules in CLAUDE.md, AGENTS.md and GEMINI.md."
}

function Invoke-AgentProcess([string]$exeName, [string[]]$agentArgs, [string]$taskId, [string]$label) {
    $exe     = Resolve-Exe $exeName
    $outFile = Join-Path $LOGS_DIR "$label-out-tmp.txt"
    $errFile = Join-Path $LOGS_DIR "$label-err-tmp.txt"

    $spArgs = @{
        FilePath = $exe
        ArgumentList = (Join-Args $agentArgs)
        WorkingDirectory = $ROOT
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
        RedirectStandardOutput = $outFile
        RedirectStandardError = $errFile
    }
    $proc = Start-Process @spArgs

    $out = if (Test-Path $outFile) { Get-Content $outFile -Raw -Encoding UTF8 } else { "" }
    $err = if (Test-Path $errFile) { Get-Content $errFile -Raw -Encoding UTF8 } else { "" }
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue

    $logPath    = Write-Log "$taskId-$label-$(Get-LogSlug)" "${label} OUTPUT:`nSTDOUT:`n$out`nSTDERR:`n$err"
    $reportPath = Write-Report $taskId $label "# $label Report: $taskId`nDate: $(Get-Timestamp)`nExit: $($proc.ExitCode)`n`n## Output`n$out`n`n## Stderr`n$err"

    if ($proc.ExitCode -ne 0) { throw "$label exited $($proc.ExitCode). Log: $logPath" }
    return $reportPath
}

# Flags below were checked against each CLI's --help output:
#   claude : -p/--print, --allowedTools (comma or space separated)
#   codex  : exec, --sandbox {read-only|workspace-write|danger-full-access}, --cd  (--sandbox and --approve-for-me are mutually exclusive)
#   agy    : -p/--print, --mode {accept-edits|auto|plan}
function Invoke-ClaudeTask([pscustomobject]$task) {
    if (-not $script:CLAUDE_OK) { throw "claude CLI not available" }
    Write-Header "Claude task: $($task.id)"
    Test-PromptSafety $task.prompt
    $instr = New-PromptFile $task
    # Read-only toolset: the orchestrator plans and verifies, it does not edit or run shell commands.
    return Invoke-AgentProcess "claude" @("-p", $instr, "--allowedTools", "Read,Glob,Grep") $task.id "claude"
}

function Invoke-CodexTask([pscustomobject]$task) {
    if (-not $script:CODEX_OK) { throw "codex CLI not available" }
    Write-Header "Codex task: $($task.id)"
    Test-PromptSafety $task.prompt
    $instr = New-PromptFile $task
    return Invoke-AgentProcess "codex" @("exec", "--sandbox", "workspace-write", "-c", "sandbox_workspace_write.network_access=true", "--cd", $ROOT, $instr) $task.id "codex"
}

function Invoke-AgyTask([pscustomobject]$task) {
    if (-not $script:AGY_OK) { throw "agy not available at $AGY_EXE" }
    Write-Header "agy (Antigravity) task: $($task.id)"
    Test-PromptSafety $task.prompt
    $instr = New-PromptFile $task
    # --mode plan = analysis only. The orchestrator itself saves the report from stdout.
    return Invoke-AgentProcess $AGY_EXE @("-p", $instr, "--mode", "plan") $task.id "agy"
}

function Invoke-AgentTask([pscustomobject]$task) {
    switch ($task.agent) {
        "claude"      { return Invoke-ClaudeTask $task }
        "codex"       { return Invoke-CodexTask  $task }
        "gemini"      { return Invoke-AgyTask    $task }
        "antigravity" { return Invoke-AgyTask    $task }
        default       { throw "Unknown agent: $($task.agent)" }
    }
}

# --- 7. Queue display --------------------------------------------------------
function Show-QueueStatus {
    Write-Header "Task Queue"
    $s = Read-State
    $q = @($s.queued); $r = @($s.running); $d = @($s.done); $f = @($s.failed)
    Write-Info "Queued:  $($q.Count)  |  Running: $($r.Count)  |  Done: $($d.Count)  |  Failed: $($f.Count)"

    if ($q.Count -gt 0) {
        $next = $q[0]
        Write-Host "`n  Next task:" -ForegroundColor White
        Write-Host "    id       : $($next.id)"       -ForegroundColor White
        Write-Host "    title    : $($next.title)"    -ForegroundColor White
        Write-Host "    agent    : $($next.agent)"    -ForegroundColor White
        Write-Host "    priority : $($next.priority)" -ForegroundColor White
        $deps = @(); if ($next.PSObject.Properties['depends_on']) { $deps = @($next.depends_on) }
        if ($deps.Count -gt 0) { Write-Host "    depends  : $($deps -join ', ')" -ForegroundColor Yellow }
    } else {
        Write-Ok "Queue is empty."
    }
}

# --- 8. Main -----------------------------------------------------------------
# First queued task whose dependencies are all done (queue order is kept).
function Get-NextRunnableTask {
    $s = Read-State
    $doneIds = @($s.done | ForEach-Object { $_.id })
    foreach ($t in @($s.queued)) {
        $deps = @(); if ($t.PSObject.Properties['depends_on']) { $deps = @($t.depends_on) }
        $missing = @($deps | Where-Object { $doneIds -notcontains $_ })
        if ($missing.Count -eq 0) { return $t }
    }
    return $null
}

# Runs exactly one task and returns 'done', 'failed', 'blocked' or 'empty'.
function Invoke-NextTask([string]$filterId) {
    if ($filterId) {
        $task = Get-FirstQueuedTask $filterId
        if (-not $task) { Write-Err "Task not found: $filterId"; return 'failed' }
        $deps = @(); if ($task.PSObject.Properties['depends_on']) { $deps = @($task.depends_on) }
        $doneIds = @((Read-State).done | ForEach-Object { $_.id })
        foreach ($dep in $deps) {
            if ($doneIds -notcontains $dep) { Write-Err "Dependency not done: $dep"; return 'blocked' }
        }
    } else {
        $task = Get-NextRunnableTask
        if (-not $task) {
            if (@((Read-State).queued).Count -gt 0) {
                Write-Err "Queued tasks remain but none is runnable (a dependency failed or is missing)."
                return 'blocked'
            }
            return 'empty'
        }
    }

    Write-Header "Starting: $($task.id) [$($task.agent)]"
    $task = Move-TaskToRunning $task.id

    try {
        $reportPath = Invoke-AgentTask $task

        if ($task.agent -eq "codex" -and -not $SkipTests) {
            $result = Invoke-Tests $task.id
            if (-not $result.Success) {
                Move-TaskToFailed $task.id "Tests failed" $result.LogPath
                Write-Err "Task failed (tests): $($task.id)"
                return 'failed'
            }
        }

        Move-TaskToDone $task.id $reportPath
        Write-Ok "Task completed: $($task.id)"
        if ($reportPath) { Write-Info "Report: $reportPath" }
        return 'done'
    } catch {
        $msg     = $_.Exception.Message
        $logPath = Write-Log "$($task.id)-error-$(Get-LogSlug)" $msg
        Move-TaskToFailed $task.id $msg $logPath
        Write-Err "Task failed: $msg"
        return 'failed'
    }
}

function Main {
    Write-Host "`nAI Agent Orchestrator - $PROJECT_NAME" -ForegroundColor Magenta
    Write-Host "Root: $ROOT" -ForegroundColor Gray

    if ($RunAll -and $TaskId) { Write-Err "-RunAll cannot be combined with -TaskId."; exit 1 }
    if (-not (Test-Prerequisites)) { Write-Err "Prerequisites not met."; exit 1 }
    Show-QueueStatus

    if (-not $Execute) {
        Write-Host ""
        Write-Warn "DRY-RUN - no tasks executed."
        Write-Info "Run next task  : .\scripts\orchestrator.ps1 -Execute"
        Write-Info "Run the queue  : .\scripts\orchestrator.ps1 -Execute -RunAll   (stops at the first failure)"
        Write-Info "Run by ID      : .\scripts\orchestrator.ps1 -Execute -TaskId {id}"
        Write-Info "Skip tests     : .\scripts\orchestrator.ps1 -Execute -SkipTests"
        return
    }

    $limit = if ($RunAll) { $MaxTasks } else { 1 }
    $ran = 0
    $last = 'empty'
    while ($ran -lt $limit) {
        $filter = ''
        if ($ran -eq 0) { $filter = $TaskId }
        $last = Invoke-NextTask $filter
        if ($last -eq 'empty') { if ($ran -eq 0) { Write-Ok "Queue is empty." }; break }
        $ran++
        if ($last -ne 'done') { break }
    }

    if ($RunAll) {
        Write-Header "Run summary"
        $s = Read-State
        Write-Info "Ran $ran task(s); last result: $last"
        Write-Info "Queued: $(@($s.queued).Count)  |  Done: $(@($s.done).Count)  |  Failed: $(@($s.failed).Count)"
        if ($last -eq 'done' -and $ran -ge $limit -and @($s.queued).Count -gt 0) {
            Write-Warn "Stopped at -MaxTasks ($MaxTasks); $(@($s.queued).Count) task(s) still queued."
        }
    }
    if ($last -eq 'failed' -or $last -eq 'blocked') { exit 1 }
}

Main
