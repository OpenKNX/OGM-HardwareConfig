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
    Functions: Show-OpenKNXLogo, Add-Written, Write-Activity, Write-OutputActivity, Clear-Activity, Write-Step, Write-Ok, Write-Detail, Write-Warn, Stop-WithError, Stop-OnSkip.

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
# @brief Compact mode on a console: one self-overwriting progress line; nothing when the output is redirected
function Write-Activity([string]$Text) {
  if (-not $script:Compact -or [Console]::IsOutputRedirected) { return }
  $max = 79
  try { $max = [Math]::Min(79, [Console]::WindowWidth - 1) } catch { }
  if ($max -lt 20) { return }
  $line = "Hardware: " + $Text
  if ($line.Length -gt $max) { $line = $line.Substring(0, $max) }
  [Console]::Write("`r" + $line.PadRight($max))
  $script:ActivityWidth = $max
  $script:ActivityShown = $true
}
# @brief Progress line for one output file: action and file name
function Write-OutputActivity([string]$Action, [string]$Path) { Write-Activity ("{0}  {1}" -f $Action, [System.IO.Path]::GetFileName($Path)) }
# @brief Removes the progress line before regular output
function Clear-Activity {
  if (-not $script:ActivityShown) { return }
  [Console]::Write("`r" + (" " * $script:ActivityWidth) + "`r")
  $script:ActivityShown = $false
}
function Write-Step([string]$Text) {
  $script:LastStep = $Text
  if (-not $script:Compact) { Write-Host ("  > " + $Text) -ForegroundColor Cyan }
  else { Write-Activity $Text }
}
function Write-Ok([string]$Text) { if (-not $script:Compact) { Write-Host ("  + " + $Text) -ForegroundColor Green } }
# @brief Plain log line, only with -Detailed (or -ListIds / -Init / -DryRun)
function Write-Detail([string]$Text) { if (-not $script:Compact) { Write-Host $Text } }
function Write-Warn([string]$Text) { Clear-Activity; Write-Host ("  ! " + $Text) -ForegroundColor Yellow; $script:WarningCount++ }
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
  if ($script:Compact) { Write-Activity ("{0}/{1}  {2} ..." -f $script:PhaseNo, $script:PhaseCount, $Text) }
  else { Write-Host ("  [{0}/{1}] {2} ..." -f $script:PhaseNo, $script:PhaseCount, $Text) -ForegroundColor White }
}
function Write-PhaseLine([string]$Mark, [string]$Color, [string]$Detail) {
  Clear-Activity
  Write-Host ("  [{0}/{1}] " -f $script:PhaseNo, $script:PhaseCount) -NoNewline -ForegroundColor DarkGray
  Write-Host $script:PhaseText.PadRight(46) -NoNewline
  Write-Host (" " + $Mark) -NoNewline -ForegroundColor $Color
  Write-Host ("{0,6:N1} s" -f $script:PhaseWatch.Elapsed.TotalSeconds) -NoNewline -ForegroundColor DarkGray
  if ($Detail) { Write-Host ("  " + $Detail) -ForegroundColor Gray } else { Write-Host "" }
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
  Write-PhaseLine (Get-PhaseMark "ok") "Green" $Detail
  $script:PhaseWatch = $null
}

function Stop-WithError([string]$Text) {
  Clear-Activity
  # the step that stopped gets its line with a cross before the reason
  if ($script:PhaseWatch) { Write-PhaseLine (Get-PhaseMark "fail") "Red" ""; $script:PhaseWatch = $null }
  if ($script:Compact -and $script:LastStep) { Write-Host ("  > " + $script:LastStep) -ForegroundColor Cyan }
  Write-Host ("  x " + $Text) -ForegroundColor Red
  exit 1
}
# @brief A board or a define of a board would be left out: stops the run (both ids modes). A skipped board
# drops its HW-ID from ETS and the firmware table and is marked "removed" in the slot file; a board is dropped
# on purpose by deleting its env. -Init only lists the problem (it writes no ETS or firmware output).
function Stop-OnSkip([string]$Text) {
  if ($script:InitMode) { Write-Warn $Text; return }
  Stop-WithError ($Text + " - a left-out board drops its HW-ID from ETS and the firmware table; to drop a board on purpose, delete its env")
}
