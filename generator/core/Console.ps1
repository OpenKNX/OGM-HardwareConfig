#Requires -Version 5.1
<#
Open =
-----+  Console
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Console.ps1

.SYNOPSIS
    Console output, progress line, warnings and stops.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Show-OpenKNXLogo, Add-Written, Get-ConsoleWidth, Set-ProgressSpin, Start-ProgressLine, Suspend-ProgressLine,
    Resume-ProgressLine, Complete-ProgressLine, Stop-ProgressSpinner, Write-Activity, Write-OutputActivity, Clear-Activity,
    Write-Step, Write-Ok, Write-Detail, Write-Warn, Start-Phase, Write-PhaseLine, Get-PhaseMark, Complete-Phase, Stop-WithError,
    Stop-OnSkip.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# ------------------------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------------------------
# compact output (default of a generation run): steps and per-output lines only with -Detailed; warnings and errors
# always; an error also shows the last step as context
# @brief OpenKNX logo with a title (same look as the OpenKNX build scripts); the glyphs are built at run time, the file stays ASCII
function Show-OpenKNXLogo([string]$Text) {
  $box = [char]::ConvertFromUtf32(0x25A0)
  $line = [char]::ConvertFromUtf32(0x252C) + ([string][char]::ConvertFromUtf32(0x2500) * 4) + [char]::ConvertFromUtf32(0x2534)
  Write-Host ""
  Write-Host "Open " -NoNewline
  Write-Host $box -ForegroundColor Green
  Write-Host ("{0}  {1}" -f $line, $Text) -ForegroundColor Green
  Write-Host $box -NoNewline -ForegroundColor Green
  Write-Host " KNX"
  Write-Host ""
}
# @brief Counts a written or removed output (the compact summary names up to three)
function Add-Written([string]$Path) { $script:WrittenCount++; $script:WrittenFiles.Add([System.IO.Path]::GetFileName($Path)) }
# @brief Progress line of a running step (also used by tests/Test-HardwareProfile.ps1): "<prefix><spinner> <text>", redrawn by
#        a runspace every 120 ms while the step runs; Complete-ProgressLine replaces it with "<prefix><mark> <text>  <time>".
#        Redirected output (CI, log file) or a too narrow console: no spinner, only the final line.
$script:Spin = $null
$script:ProgPrefix = ""
$script:ProgText = ""
$script:ProgWatch = $null
function Get-ConsoleWidth {
  if ([Console]::IsOutputRedirected) { return 0 }
  try { return [Console]::WindowWidth - 1 } catch { return 0 }
}
# @brief Sets the spinner text (Prefix + frame + Tail, cut to the console width) and shows it
function Set-ProgressSpin([string]$Tail) {
  if (-not $script:Spin) { return }
  $st = $script:Spin.State
  $room = $st.Width - $script:ProgPrefix.Length - 2
  if ($Tail.Length -gt $room) { $Tail = $Tail.Substring(0, [Math]::Max(0, $room)) }
  [System.Threading.Monitor]::Enter($st.Lock)
  try { $st.Head = $script:ProgPrefix; $st.Tail = $Tail.PadRight([Math]::Max(0, $room)); $st.Active = $true }
  finally { [System.Threading.Monitor]::Exit($st.Lock) }
}
function Start-ProgressLine([string]$Prefix, [string]$Text) {
  $script:ProgPrefix = $Prefix; $script:ProgText = $Text
  $script:ProgWatch = [System.Diagnostics.Stopwatch]::StartNew()
  $width = Get-ConsoleWidth
  if ($width -lt 30) { return }
  if (-not $script:Spin) {
    $state = [hashtable]::Synchronized(@{ Run = $true; Active = $false; Head = ""; Tail = ""; Width = $width; Lock = (New-Object Object) })
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("state", $state)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
      $frames = @('|', '/', '-', '\')
      $i = 0
      while ($state.Run) {
        [System.Threading.Monitor]::Enter($state.Lock)
        try { if ($state.Active) { [Console]::Write("`r" + $state.Head + $frames[$i % 4] + " " + $state.Tail) } }
        finally { [System.Threading.Monitor]::Exit($state.Lock) }
        $i++
        Start-Sleep -Milliseconds 120
      }
    })
    $script:Spin = @{ State = $state; Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke() }
  }
  $script:Spin.State.Width = $width
  Set-ProgressSpin $Text
}
# @brief Hides the spinner line (before other output); Resume-ProgressLine shows it again
function Suspend-ProgressLine {
  if (-not $script:Spin) { return }
  $st = $script:Spin.State
  [System.Threading.Monitor]::Enter($st.Lock)
  try { if ($st.Active) { [Console]::Write("`r" + (" " * $st.Width) + "`r"); $st.Active = $false } }
  finally { [System.Threading.Monitor]::Exit($st.Lock) }
}
function Resume-ProgressLine { if ($script:Spin -and $script:ProgWatch) { Set-ProgressSpin $script:ProgText } }
# @brief Final line of the step: mark (ok / fail / skip) in front of the text, time behind it, optional detail
function Complete-ProgressLine([string]$Kind, [string]$Detail = "", [switch]$NoTime) {
  Suspend-ProgressLine
  $color = @{ ok = "Green"; fail = "Red"; skip = "Yellow" }[$Kind]
  Write-Host $script:ProgPrefix -NoNewline -ForegroundColor DarkGray
  Write-Host ((Get-PhaseMark $Kind) + " ") -NoNewline -ForegroundColor $color
  Write-Host $script:ProgText -NoNewline
  if (-not $NoTime -and $script:ProgWatch) { Write-Host ("  {0:N1} s" -f $script:ProgWatch.Elapsed.TotalSeconds) -NoNewline -ForegroundColor DarkGray }
  if ($Detail) { Write-Host ("  " + $Detail) -ForegroundColor Gray } else { Write-Host "" }
  $script:ProgWatch = $null
}
# @brief Ends the spinner runspace (end of the run)
function Stop-ProgressSpinner {
  if (-not $script:Spin) { return }
  Suspend-ProgressLine
  $script:Spin.State.Run = $false
  try { [void]$script:Spin.Ps.EndInvoke($script:Spin.Handle) } catch { }
  $script:Spin.Ps.Dispose(); $script:Spin.Rs.Dispose()
  $script:Spin = $null
}
# @brief Compact mode: what the running step does right now, behind its text on the spinner line
function Write-Activity([string]$Text) {
  if (-not $script:Compact -or -not $script:ProgWatch) { return }
  Set-ProgressSpin ("{0}: {1}" -f $script:ProgText, $Text)
}
# @brief Progress line for one output file: action and file name
function Write-OutputActivity([string]$Action, [string]$Path) { Write-Activity ("{0}  {1}" -f $Action, [System.IO.Path]::GetFileName($Path)) }
# @brief Removes the progress line before regular output (it comes back with the next activity or Resume-ProgressLine)
function Clear-Activity { Suspend-ProgressLine }
function Write-Step([string]$Text) {
  $script:LastStep = $Text
  if (-not $script:Compact) { Write-Host ("  > " + $Text) -ForegroundColor Cyan }
  else { Write-Activity $Text }
}
function Write-Ok([string]$Text) { if (-not $script:Compact) { Write-Host ("  + " + $Text) -ForegroundColor Green } }
# @brief Plain log line, only with -Detailed (or -ListIds / -Init / -DryRun)
function Write-Detail([string]$Text) { if (-not $script:Compact) { Write-Host $Text } }
function Write-Warn([string]$Text) { Clear-Activity; Write-Host ("  ! " + $Text) -ForegroundColor Yellow; $script:WarningCount++; Resume-ProgressLine }
# @brief Core steps of a run: one numbered line per step with a mark and the time, in every mode; the progress line shows the
#        running step (compact mode). Marks: Get-PhaseMark
$script:PhaseCount = 7
$script:PhaseNo = 0
$script:PhaseText = ""
$script:PhaseWatch = $null
$script:RunWatch = [System.Diagnostics.Stopwatch]::StartNew()
function Start-Phase([string]$Text) {
  $script:PhaseNo++
  $script:PhaseText = $Text
  $script:PhaseWatch = [System.Diagnostics.Stopwatch]::StartNew()
  $prefix = "  [{0}/{1}] " -f $script:PhaseNo, $script:PhaseCount
  # compact: spinner line until the step ends; detailed: a start line, then the log lines of the step, then the result line
  if ($script:Compact) { Start-ProgressLine $prefix $Text }
  else { $script:ProgPrefix = $prefix; $script:ProgText = $Text; $script:ProgWatch = $script:PhaseWatch; Write-Host ("{0}{1} ..." -f $prefix, $Text) -ForegroundColor White }
}
function Write-PhaseLine([string]$Kind, [string]$Detail) {
  $script:ProgPrefix = "  [{0}/{1}] " -f $script:PhaseNo, $script:PhaseCount
  $script:ProgText = $script:PhaseText
  $script:ProgWatch = $script:PhaseWatch
  Complete-ProgressLine $Kind $Detail
}
# @brief Marks of the step lines (also used by tests/Test-HardwareProfile.ps1); Windows PowerShell 5.1 gets marks its console
#        font (e.g. Consolas) has: U+221A, x, -
function Get-PhaseMark([string]$Kind) {
  $old = ($PSVersionTable.PSVersion.Major -lt 6)
  switch ($Kind) {
    "ok" { if ($old) { return [string][char]0x221A } return [string][char]0x2713 }
    "fail" { if ($old) { return "x" } return [string][char]0x2717 }
    default { if ($old) { return "-" } return [string][char]0x2013 }
  }
}
function Complete-Phase([string]$Detail = "") {
  if (-not $script:PhaseWatch) { return }
  Write-PhaseLine "ok" $Detail
  $script:PhaseWatch = $null
}

function Stop-WithError([string]$Text) {
  Clear-Activity
  # the step that stopped gets its line with a cross before the reason
  if ($script:PhaseWatch) { Write-PhaseLine "fail" ""; $script:PhaseWatch = $null }
  if ($script:Compact -and $script:LastStep) { Write-Host ("  > " + $script:LastStep) -ForegroundColor Cyan }
  Write-Host ("  x " + $Text) -ForegroundColor Red
  Stop-ProgressSpinner
  exit 1
}
# @brief A board or a define of a board would be left out: stops the run (both ids modes). A skipped board
# drops its HW-ID from ETS and the firmware table and is marked "removed" in the slot file; a board is dropped
# on purpose by deleting its env. -Init only lists the problem (it writes no ETS or firmware output).
function Stop-OnSkip([string]$Text) {
  if ($script:InitMode) { Write-Warn $Text; return }
  Stop-WithError (T "{0} - a left-out board drops its HW-ID from ETS and the firmware table; to drop a board on purpose, delete its env" $Text)
}
