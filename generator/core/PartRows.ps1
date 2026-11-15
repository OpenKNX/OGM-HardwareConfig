#Requires -Version 5.1
<#
Open =
-----+  PartRows
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/PartRows.ps1

.SYNOPSIS
    Rows of a part of another module shown per board (<PartRows>): copy of the part file with the selected rows per board.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Add-PartRowLabel, Add-PartRowIndent, Find-PartRow, New-PartRowsXml.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Row text with the board label: " (<label>)" in front of the first %TOKEN% of the text, else at its end
function Add-PartRowLabel([string]$Text, [string]$Label) {
  $mt = [regex]::Match($Text, '%[A-Za-z0-9_]+%')
  $ins = " (" + $Label + ")"
  if ($mt.Success) { return $Text.Substring(0, $mt.Index) + $ins + $Text.Substring($mt.Index) }
  return $Text + $ins
}

# @brief Moves every line inside a node two levels deeper: each whitespace node of its subtree gets Extra after its line breaks
function Add-PartRowIndent($Node, [string]$Extra) {
  foreach ($c in @($Node.ChildNodes)) {
    if ($c.NodeType -eq [System.Xml.XmlNodeType]::Whitespace -or $c.NodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
      $c.Value = $c.Value.Replace("`n", "`n" + $Extra)
    }
    elseif ($c.HasChildNodes) { Add-PartRowIndent $c $Extra }
  }
}

# @brief The row of one <Row>: the inline ParameterBlock whose direct child is the ParameterRefRef ref; stops when the part has
#        no such ParameterRefRef, more than one, or when it does not sit directly in an inline ParameterBlock
function Find-PartRow($Doc, $Pr, $Row) {
  $where = "<PartRows source=`"{0}`"><Row ref=`"{1}`">" -f $Pr.SourceAttr, $Row.Ref
  $hits = @($Doc.SelectNodes("//*[local-name()='ParameterRefRef']") | Where-Object { $_.GetAttribute("RefId") -ceq $Row.Ref })
  if ($hits.Count -eq 0) { Stop-WithError (T "{0}: the part has no ParameterRefRef with this RefId - it has changed, check the row selection" $where) }
  if ($hits.Count -gt 1) { Stop-WithError (T "{0}: the part has {1} ParameterRefRef with this RefId - the selection must name exactly one row" $where $hits.Count) }
  $el = $hits[0].ParentNode
  if ($el.LocalName -cne "ParameterBlock" -or $el.GetAttribute("Inline") -cne "true") {
    Stop-WithError (T "{0}: the ParameterRefRef is not a direct child of an inline ParameterBlock (a row of the page)" $where)
  }
  return $el
}

# @brief Parts file of one <PartRows>: the source part, each selected row replaced by a choose on the hardware selection:
#        not selected = the original row, one when per group of boards with the same label (row text with the label),
#        boards whose header does not meet expr = no when, so no row
function New-PartRowsXml($M, $Boards, $Pr) {
  $refs = Get-ParamRefIds $M
  $doc = New-Object System.Xml.XmlDocument
  $doc.PreserveWhitespace = $true
  try { $doc.LoadXml([System.IO.File]::ReadAllText($Pr.Source, [System.Text.Encoding]::UTF8)) }
  catch { Stop-WithError (T "<PartRows source=`"{0}`">: not readable as XML: {1}" $Pr.SourceAttr $_.Exception.Message) }

  # every row is located before the first change: an error leaves nothing half done
  $rowEls = @()
  for ($j = 0; $j -lt $Pr.Rows.Count; $j++) {
    $row = $Pr.Rows[$j]
    $el = Find-PartRow $doc $Pr $row
    foreach ($o in $rowEls) {
      if ([object]::ReferenceEquals($o, $el)) { Stop-WithError (T "<PartRows source=`"{0}`"><Row ref=`"{1}`">: this row is already selected by another <Row>" $Pr.SourceAttr $row.Ref) }
    }
    if ($row.Label) {
      $seps = @($el.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -ceq "ParameterSeparator" -and $_.HasAttribute("Text") })
      if ($seps.Count -ne 1) { Stop-WithError (T "<PartRows source=`"{0}`"><Row ref=`"{1}`">: label needs exactly one ParameterSeparator with Text in the row, found {2}" $Pr.SourceAttr $row.Ref $seps.Count) }
    }
    $rowEls += $el
  }

  for ($j = 0; $j -lt $Pr.Rows.Count; $j++) {
    $row = $Pr.Rows[$j]
    $el = $rowEls[$j]
    $key = "{0}/{1}" -f $Pr.Index, $j
    # boards with the row, grouped by label in board order
    $groups = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Boards) {
      $st = $b.PartRows[$key]
      if (-not $st.On) { continue }
      $g = @($groups | Where-Object { $_.Label -ceq $st.Label }) | Select-Object -First 1
      if (-not $g) { $g = @{ Label = $st.Label; Boards = @() }; $groups.Add($g) }
      $g.Boards += $b
    }
    # indentation of the row and one level of the source
    $indent = ""
    $prev = $el.PreviousSibling
    if ($prev -and $prev.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) { $indent = $prev.Value.Substring($prev.Value.LastIndexOf("`n") + 1) }
    $unit = "    "
    $first = $el.FirstChild
    if ($first -and $first.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
      $inner = $first.Value.Substring($first.Value.LastIndexOf("`n") + 1)
      if ($inner.Length -gt $indent.Length -and $inner.StartsWith($indent)) { $unit = $inner.Substring($indent.Length) }
    }
    $ns = $el.NamespaceURI
    $parent = $el.ParentNode
    $note = " OGM-HardwareConfig <PartRows>: row per selected board, {0} board(s) in {1} group(s) (label {2}); not selected: the original row " -f
      [int](@($groups | ForEach-Object { $_.Boards.Count }) | Measure-Object -Sum).Sum, $groups.Count, $(if ($row.Label) { $row.Label } else { "-" })
    [void]$parent.InsertBefore($doc.CreateComment((ConvertTo-XmlComment $note)), $el)
    [void]$parent.InsertBefore($doc.CreateWhitespace("`n" + $indent), $el)
    $choose = $doc.CreateElement("choose", $ns)
    $choose.SetAttribute("ParamRefId", $refs.Select)
    [void]$parent.InsertBefore($choose, $el)
    [void]$parent.RemoveChild($el)
    $whens = @(@{ Test = [string]$M.UnselectedValue; Row = $el })
    foreach ($g in $groups) {
      $copy = $el.CloneNode($true)
      if ($g.Label) {
        $sep = @($copy.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -ceq "ParameterSeparator" -and $_.HasAttribute("Text") })[0]
        $sep.SetAttribute("Text", (Add-PartRowLabel $sep.GetAttribute("Text") $g.Label))
      }
      $whens += @{ Test = (Get-IdList $g.Boards); Row = $copy }
    }
    foreach ($w in $whens) {
      [void]$choose.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit))
      $when = $doc.CreateElement("when", $ns)
      $when.SetAttribute("test", $w.Test)
      [void]$choose.AppendChild($when)
      [void]$when.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit + $unit))
      Add-PartRowIndent $w.Row ($unit + $unit)
      [void]$when.AppendChild($w.Row)
      [void]$when.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit))
    }
    [void]$choose.AppendChild($doc.CreateWhitespace("`n" + $indent))
  }

  $head = " Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<PartRows>) from {0} - do not edit " -f ($Pr.SourceAttr -replace '\\', '/')
  # a document takes no whitespace node: the line break after the comment goes into the text
  $headNode = $doc.CreateComment((ConvertTo-XmlComment $head))
  [void]$doc.InsertBefore($headNode, $doc.DocumentElement)
  $text = $doc.OuterXml -replace "`r`n", "`n"
  $at = $text.IndexOf($headNode.OuterXml) + $headNode.OuterXml.Length
  return $text.Substring(0, $at) + "`n" + $text.Substring($at) + "`n"
}
