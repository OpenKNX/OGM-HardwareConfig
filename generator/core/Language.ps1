#Requires -Version 5.1
<#
Open =
-----+  Language
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Language.ps1

.SYNOPSIS
    Language of the console output: German (default) or English.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope; also dot-sourced by tests/Test-HardwareProfile.ps1.
    The code holds the English text; core/Messages.de.psd1 maps it to German (UTF-8 with BOM, so the .ps1 files stay ASCII).
    A text missing in the table is printed in English. The self-test checks that every text of the code is in the table.
    Functions: Set-OutputLanguage, Read-MessageTable, T.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

$script:Messages = $null

# @brief Selects the output language: "de" loads the German table, "en" prints the texts of the code
function Set-OutputLanguage([string]$Language) {
  $script:Messages = $null
  if ($Language -ne "de") { return }
  # a broken table must not stop a build: warn and print the texts of the code (the self-test fails on it)
  try { $script:Messages = Read-MessageTable ([System.IO.Path]::Combine($PSScriptRoot, "Messages.de.psd1")) }
  catch {
    $text = "German texts not available, output in English: {0}" -f $_.Exception.Message
    # counted like every warning where the generator console is loaded, plain yellow line otherwise (Test-DemoUpdate)
    if (Get-Command Write-Warn -ErrorAction SilentlyContinue) { Write-Warn $text } else { Write-Host ("  ! " + $text) -ForegroundColor Yellow }
  }
}

# @brief Reads a message table (one hashtable of string constants) with the PowerShell parser: nothing in the file is run;
#        the lookup is case-sensitive (the English text as written in the code); the parser already rejects a key listed
#        twice (also when only the case differs), a non-constant entry stops
function Read-MessageTable([string]$Path) {
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ("{0}: {1}" -f $Path, $errors[0].Message) }
  $table = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $false)
  if ($null -eq $table) { throw ("{0}: no @{{ ... }} table" -f $Path) }
  $map = New-Object "System.Collections.Generic.Dictionary[string,string]" ([System.StringComparer]::Ordinal)
  foreach ($kv in $table.KeyValuePairs) {
    $value = $null
    $st = $kv.Item2
    if ($st -is [System.Management.Automation.Language.PipelineAst] -and $st.PipelineElements.Count -eq 1 -and
        $st.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) { $value = $st.PipelineElements[0].Expression }
    if ($kv.Item1 -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or
        $value -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
      throw ("{0}, line {1}: only 'text' = 'text' entries" -f $Path, $kv.Item1.Extent.StartLineNumber)
    }
    # a text over several lines matches the `n of the code also when the file has CRLF line ends (Windows checkout)
    $key = $kv.Item1.Value -replace "`r`n", "`n"
    if ($map.ContainsKey($key)) { throw ("{0}, line {1}: text twice in the table" -f $Path, $kv.Item1.Extent.StartLineNumber) }
    $map[$key] = $value.Value -replace "`r`n", "`n"
  }
  return ,$map
}

# @brief Text in the output language; further arguments fill {0}, {1}, ... like -f (current culture, as the format calls before)
function T([string]$Text) {
  $f = $Text
  if ($null -ne $script:Messages -and $script:Messages.ContainsKey($Text)) { $f = $script:Messages[$Text] }
  if ($args.Count -eq 0) { return $f }
  # one argument goes to -f as it is (an array fills the placeholders with its items, as with "..." -f $array)
  if ($args.Count -eq 1) { return ($f -f $args[0]) }
  return ($f -f $args)
}
