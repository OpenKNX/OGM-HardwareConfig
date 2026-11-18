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
    Functions: Add-PartRowLabel, Add-PartRowIndent, Find-PartRow, Add-PartRowsXmlIndent, Get-PartRowsHref, Get-PartRowsDefines,
    Get-PartRowsChannelCount, New-PartRowsXml.

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
  # rows only: a ParameterRefRef of a ParameterCalculation / ParameterValidation (LParameters, RParameters) is no row
  $hits = @($Doc.SelectNodes("//*[local-name()='ParameterRefRef']") | Where-Object { $_.GetAttribute("RefId") -ceq $Row.Ref -and $_.ParentNode -and ($_.ParentNode.LocalName -ceq "ParameterBlock" -or $_.ParentNode.LocalName -ceq "when") })
  if ($hits.Count -eq 0) { Stop-WithError (T "{0}: the part has no ParameterRefRef with this RefId - it has changed, check the row selection" $where) }
  if ($hits.Count -gt 1) { Stop-WithError (T "{0}: the part has {1} ParameterRefRef with this RefId - the selection must name exactly one row" $where $hits.Count) }
  $el = $hits[0].ParentNode
  if ($el.LocalName -cne "ParameterBlock" -or $el.GetAttribute("Inline") -cne "true") {
    Stop-WithError (T "{0}: the ParameterRefRef is not a direct child of an inline ParameterBlock (a row of the page)" $where)
  }
  return $el
}

# @brief Indents the element children of Node for a readable copy: a line break plus Indent + Unit before each, Indent before the
#        end tag; recursive (the inserted blocks come without whitespace nodes)
function Add-PartRowsXmlIndent($Doc, $Node, [string]$Indent, [string]$Unit) {
  $kids = @($Node.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -or $_.NodeType -eq [System.Xml.XmlNodeType]::Comment })
  if ($kids.Count -eq 0) { return }
  foreach ($k in $kids) {
    [void]$Node.InsertBefore($Doc.CreateWhitespace("`n" + $Indent + $Unit), $k)
    if ($k.NodeType -eq [System.Xml.XmlNodeType]::Element) { Add-PartRowsXmlIndent $Doc $k ($Indent + $Unit) $Unit }
  }
  [void]$Node.AppendChild($Doc.CreateWhitespace("`n" + $Indent))
}

# @brief href of the copy: a relative href of the source, rewritten to the folder of the output (forward slashes); a file that is
#        the source of another <PartRows> becomes its output (a copied share includes the copied template); hrefs with producer
#        tokens, absolute paths and URLs stay
function Get-PartRowsHref($M, [string]$Href, [string]$SourceDir, [string]$OutputDir) {
  if (-not $Href -or $Href.Contains('%') -or $Href -match '^[A-Za-z][A-Za-z0-9+.-]*://' -or [System.IO.Path]::IsPathRooted($Href)) { return $Href }
  $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($SourceDir, $Href))
  $other = @($M.PartRows | Where-Object { [string]::Equals($_.Source, $target, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
  if ($other) { $target = $other.Output }
  elseif ([string]::Equals($SourceDir, $OutputDir, [StringComparison]::OrdinalIgnoreCase)) { return $Href }
  return ((Get-RelativePath $OutputDir $target) -replace '\\', '/')
}

# @brief The op:define attributes of the product XMLs that name a file (share or template): list of @{ Product; Kind; N }
function Get-PartRowsDefines($M, [string]$File) {
  $hits = @()
  # Get-ProductXmls returns its list as one object (return ,$list): assign it, then enumerate
  $products = Get-ProductXmls $M
  foreach ($p in $products) {
    $dir = [System.IO.Path]::GetDirectoryName($p.Path)
    foreach ($d in [regex]::Matches($p.Text, '<op:define\b' + $script:XmlAttrs + '>')) {
      $n = $null; $files = @()
      foreach ($a in [regex]::Matches($d.Value, '\b(share|template|NumChannels)\s*=\s*"([^"]*)"')) {
        if ($a.Groups[1].Value -ceq "NumChannels") { $n = $a.Groups[2].Value } else { $files += @{ Kind = $a.Groups[1].Value; Path = $a.Groups[2].Value } }
      }
      foreach ($f in $files) {
        if (-not $f.Path -or $f.Path.Contains('%')) { continue }
        if ([string]::Equals([System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dir, $f.Path)), $File, [StringComparison]::OrdinalIgnoreCase)) { $hits += @{ Product = $p.Name; Kind = $f.Kind; N = $n } }
      }
    }
  }
  # plain return: callers wrap it in @() (one hit comes back as a hashtable, none as $null)
  return $hits
}

# @brief NumChannels of the op:define whose share or template is the source of the <PartRows> (product XMLs of the OAM); the
#        producer replaces %N% / %N-1% only in a file it also reads for the Static of a module, a copy that gives only the
#        Dynamic needs the number written in; $null when a define takes the copy itself as share or template (the producer
#        replaces them there). Stops when no define or defines with different numbers name the source.
function Get-PartRowsChannelCount($M, $Pr) {
  # the copy itself is the share or template of a define: the producer replaces %N% there
  if (@(Get-PartRowsDefines $M $Pr.Output).Count -gt 0) { return $null }
  $found = @{}
  foreach ($h in @(Get-PartRowsDefines $M $Pr.Source)) {
    if ($h.N -notmatch '^\d+$') { Stop-WithError (T "<PartRows source=`"{0}`">: the copy uses %N%, the op:define of {1} has no NumChannels number ({2})" $Pr.SourceAttr $h.Product $h.N) }
    $found[$h.N] = $h.Product
  }
  if ($found.Count -eq 0) { Stop-WithError (T "<PartRows source=`"{0}`">: the copy uses %N%, but no op:define of a product XML names this file as share or template (its NumChannels gives %N%)" $Pr.SourceAttr) }
  if ($found.Count -gt 1) { Stop-WithError (T "<PartRows source=`"{0}`">: the copy uses %N%, the product XMLs give different NumChannels ({1})" $Pr.SourceAttr ((Get-OrdinalSorted @($found.Keys)) -join ", ")) }
  return [int]@($found.Keys)[0]
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

  # a <Fix>/<Filter> block replaces every row of its setting: a ParameterRefRef directly in a ParameterBlock or a when (a setting
  # may show in several branches), never one in a ParameterCalculation or ParameterValidation; none = stop
  $isRow = { param($e) $e.ParentNode -and ($e.ParentNode.LocalName -ceq "ParameterBlock" -or $e.ParentNode.LocalName -ceq "when") }
  foreach ($bk in @($Pr.Blocks)) {
    $n = @($doc.SelectNodes("//*[local-name()='ParameterRefRef']") | Where-Object { $_.GetAttribute("RefId") -ceq $bk.Ref -and (& $isRow $_) }).Count
    if ($n -eq 0) { Stop-WithError (T "<PartRows source=`"{0}`"><{1} name=`"{2}`">: the source has no ParameterRefRef with RefId {3}" $Pr.SourceAttr $bk.Kind $bk.Name $bk.Ref) }
  }

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

  # the node that stands for each row after this loop (the choose on the selection, or the row itself): <Row count> wraps it
  $units = @{}
  for ($j = 0; $j -lt $Pr.Rows.Count; $j++) {
    $row = $Pr.Rows[$j]
    $el = $rowEls[$j]
    # count without expr and label: the row is the same on every board, only the channel number decides
    if ($row.Always -and -not $row.Label) { $units[$j] = $el; continue }
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
    $units[$j] = $choose
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

  # <Row count>: the row (or its choose) inside a choose on the count parameter of the hardware module: channel n (%C% of the
  # template) shows while the value of the selected board is at least n; not selected = 255 = every channel. %C% exists only in
  # a channel template: an op:define must take the source or the copy as template=
  $tt = "{0:D2}" -f $M.ModuleType
  if (@($Pr.Rows | Where-Object { $_.Count }).Count -gt 0) {
    $asTemplate = @(@(Get-PartRowsDefines $M $Pr.Source) + @(Get-PartRowsDefines $M $Pr.Output) | Where-Object { $_.Kind -ceq "template" })
    if ($asTemplate.Count -eq 0) { Stop-WithError (T "<PartRows source=`"{0}`">: <Row count> needs a channel template (%C%), but no op:define of a product XML takes the source or the copy as template=" $Pr.SourceAttr) }
  }
  for ($j = 0; $j -lt $Pr.Rows.Count; $j++) {
    $row = $Pr.Rows[$j]
    if (-not $row.Count) { continue }
    $cv = @($M.CountValues | Where-Object { $_.Name -ceq $row.Count })[0]
    $u = $units[$j]
    $parent = $u.ParentNode
    $indent = ""
    $prev = $u.PreviousSibling
    if ($prev -and $prev.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) { $indent = $prev.Value.Substring($prev.Value.LastIndexOf("`n") + 1) }
    $unit = "    "
    $first = $u.FirstChild
    if ($first -and $first.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
      $inner = $first.Value.Substring($first.Value.LastIndexOf("`n") + 1)
      if ($inner.Length -gt $indent.Length -and $inner.StartsWith($indent)) { $unit = $inner.Substring($indent.Length) }
    }
    $ns = $u.NamespaceURI
    [void]$parent.InsertBefore($doc.CreateComment((ConvertTo-XmlComment (" OGM-HardwareConfig <PartRows>: channel %C% only while {0} of the selected board is at least %C% " -f $row.Count))), $u)
    [void]$parent.InsertBefore($doc.CreateWhitespace("`n" + $indent), $u)
    $cc = $doc.CreateElement("choose", $ns)
    $cc.SetAttribute("ParamRefId", ("%AID%_P-{0}{1}_R-{0}{1}01" -f $tt, $cv.Num))
    [void]$parent.InsertBefore($cc, $u)
    [void]$parent.RemoveChild($u)
    $cw = $doc.CreateElement("when", $ns)
    $cw.SetAttribute("test", ">=%C%")
    [void]$cc.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit))
    [void]$cc.AppendChild($cw)
    [void]$cc.AppendChild($doc.CreateWhitespace("`n" + $indent))
    Add-PartRowIndent $u ($unit + $unit)
    [void]$cw.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit + $unit))
    [void]$cw.AppendChild($u)
    [void]$cw.AppendChild($doc.CreateWhitespace("`n" + $indent + $unit))
  }

  # <Fix>/<Filter> blocks in place of the ParameterRefRef of their setting, also inside the copies of a selected row (each copy
  # gets the whole block: its choose on the hardware selection decides); Cell, IndentLevel and HelpContext of the replaced
  # ParameterRefRef (the layout of the source) replace those of every ParameterRefRef of the block; Cell and IndentLevel the
  # replaced one does not have are removed (HelpContext of the manifest stays)
  if (@($Pr.Blocks).Count -gt 0) {
    $blockDocs = @{}
    if (@($Pr.Blocks | Where-Object { $_.Kind -ceq "Fix" }).Count -gt 0) { $x = New-Object System.Xml.XmlDocument; $x.LoadXml((New-FixesXml $M $Boards)); $blockDocs["Fix"] = $x }
    if (@($Pr.Blocks | Where-Object { $_.Kind -ceq "Filter" }).Count -gt 0) { $x = New-Object System.Xml.XmlDocument; $x.LoadXml((New-FiltersXml $M $Boards)); $blockDocs["Filter"] = $x }
    foreach ($bk in @($Pr.Blocks)) {
      $src = @($blockDocs[$bk.Kind].SelectNodes("//*[local-name()='Block']") | Where-Object { $_.GetAttribute("name") -ceq $bk.Block })
      if ($src.Count -ne 1) { Stop-WithError (T "<PartRows source=`"{0}`"><{1} name=`"{2}`">: block {3} not found in the generated parts" $Pr.SourceAttr $bk.Kind $bk.Name $bk.Block) }
      $content = @($src[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -or $_.NodeType -eq [System.Xml.XmlNodeType]::Comment })
      $targets = @($doc.SelectNodes("//*[local-name()='ParameterRefRef']") | Where-Object { $_.GetAttribute("RefId") -ceq $bk.Ref -and (& $isRow $_) })
      foreach ($t in $targets) {
        if ($content.Count -gt 0 -and $content[0].NamespaceURI -and $t.NamespaceURI -cne $src[0].NamespaceURI) { Stop-WithError (T "<PartRows source=`"{0}`">: the source is not in the KNX namespace {1}" $Pr.SourceAttr $src[0].NamespaceURI) }
        $indent = ""
        $prev = $t.PreviousSibling
        if ($prev -and ($prev.NodeType -eq [System.Xml.XmlNodeType]::Whitespace -or $prev.NodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace)) { $indent = $prev.Value.Substring($prev.Value.LastIndexOf("`n") + 1) }
        $parent = $t.ParentNode
        $first = $true
        foreach ($c in $content) {
          $imp = $doc.ImportNode($c, $true)
          if ($imp.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            Add-PartRowsXmlIndent $doc $imp $indent "  "
            $refs = @($imp.SelectNodes("descendant-or-self::*[local-name()='ParameterRefRef']"))
            foreach ($r in $refs) {
              foreach ($an in @("Cell", "IndentLevel", "HelpContext")) {
                if ($t.HasAttribute($an)) { $r.SetAttribute($an, $t.GetAttribute($an)) }
                elseif ($an -cne "HelpContext") { $r.RemoveAttribute($an) }
              }
            }
          }
          if (-not $first) { [void]$parent.InsertBefore($doc.CreateWhitespace("`n" + $indent), $t) }
          [void]$parent.InsertBefore($imp, $t)
          $first = $false
        }
        [void]$parent.RemoveChild($t)
      }
    }
    # parameters and refs of the blocks into the Static of the copy, once (used where the product takes the copy as template=;
    # with the copy as Dynamic include only, a module of the same ModuleType includes the blocks instead); types stay with the product
    $statics = @(@{ Section = "Parameters"; Nodes = @(); Blocks = @() }, @{ Section = "ParameterRefs"; Nodes = @(); Blocks = @() })
    # a block the source already takes by op:include (xpath naming the block) is not inserted a second time
    $included = { param($blockName) @($doc.SelectNodes("//*[local-name()='include']") | Where-Object { $x = $_.GetAttribute("xpath"); $x.Contains("'" + $blockName + "'") -or $x.Contains('"' + $blockName + '"') }).Count -gt 0 }
    foreach ($bk in @($Pr.Blocks)) {
      $bd = $blockDocs[$bk.Kind]
      $pick = {
        param($blockName, $idFilter)
        $b = @($bd.SelectNodes("//*[local-name()='Block']") | Where-Object { $_.GetAttribute("name") -ceq $blockName })
        if ($b.Count -ne 1) { return @() }
        return @($b[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and (-not $idFilter -or $_.GetAttribute("Id") -ceq $idFilter) })
      }
      if ($bk.Kind -ceq "Fix") {
        $fx = @($M.Fixes.Items | Where-Object { $_.Name -ceq $bk.Name })[0]
        # module digits: the read-only ref comes from the shared block ParameterRefs, which the product includes once
        if ($fx.Show -ceq "readonly" -and $fx.Tokens -and -not (& $included ("Fix_" + $bk.Name + "_ParameterRefs"))) { $statics[1].Nodes += (& $pick ("Fix_" + $bk.Name + "_ParameterRefs") $null); $statics[1].Blocks += ("Fix_" + $bk.Name + "_ParameterRefs") }
      }
      elseif (-not $bk.Row) {
        if (-not (& $included ("Filter_" + $bk.Name + "_Parameters"))) { $statics[0].Nodes += (& $pick ("Filter_" + $bk.Name + "_Parameters") $null); $statics[0].Blocks += ("Filter_" + $bk.Name + "_Parameters") }
        if (-not (& $included ("Filter_" + $bk.Name + "_ParameterRefs"))) { $statics[1].Nodes += (& $pick ("Filter_" + $bk.Name + "_ParameterRefs") $null); $statics[1].Blocks += ("Filter_" + $bk.Name + "_ParameterRefs") }
      }
    }
    foreach ($st in $statics) {
      if ($st.Nodes.Count -eq 0) { continue }
      $sec = $doc.SelectSingleNode("//*[local-name()='Static']/*[local-name()='" + $st.Section + "']")
      if (-not $sec) {
        # the source has no such section (e.g. an op:part, whose Static the producer does not read): the product includes the
        # blocks itself (op:include xpath naming the block, e.g. in the share of a second op:define with the same ModuleType);
        # warn for a block no XML of the product src folder names
        $mDir = [System.IO.Path]::GetDirectoryName($M.ManifestPath)
        $srcDir = $mDir; if ([System.IO.Path]::GetFileName($mDir) -cne "src") { $srcDir = [System.IO.Path]::Combine($mDir, "src") }
        $texts = @()
        if (Test-Path -LiteralPath $srcDir -PathType Container) {
          $texts = @(Get-ChildItem -LiteralPath $srcDir -Filter "*.xml" -File -Recurse | Where-Object { $_.Name -notmatch '\.(gen|debug)\.xml$' } | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) })
        }
        foreach ($bn in @($st.Blocks)) {
          $named = @($texts | Where-Object { $_.Contains("'" + $bn + "'") -or $_.Contains('"' + $bn + '"') }).Count -gt 0
          if (-not $named) { Write-Warn (T "<PartRows source=`"{0}`">: no Static/{1} in the source and no product XML includes block {2} - include it in the {1} of the module, else the producer reports its refs as not defined" $Pr.SourceAttr $st.Section $bn) }
        }
        continue
      }
      $last = @($sec.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -or $_.NodeType -eq [System.Xml.XmlNodeType]::Comment }) | Select-Object -Last 1
      $indent = "      "
      if ($last -and $last.PreviousSibling -and $last.PreviousSibling.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) { $indent = $last.PreviousSibling.Value.Substring($last.PreviousSibling.Value.LastIndexOf("`n") + 1) }
      $anchor = $null; if ($last) { $anchor = $last.NextSibling }
      $add = @($doc.CreateComment(" OGM-HardwareConfig <PartRows>: parameters and refs of the blocks (used with this copy as template=) ")) + @($st.Nodes | ForEach-Object { $doc.ImportNode($_, $true) })
      foreach ($n in $add) {
        [void]$sec.InsertBefore($doc.CreateWhitespace("`n" + $indent), $anchor)
        [void]$sec.InsertBefore($n, $anchor)
      }
    }
  }

  # op:part declared in the copy gets its own name (and so does every op:usePart of it here): the producer keeps parts by name
  # for the whole product, a second declaration under the same name would continue the instance numbers and move the ids of
  # the copy away from those of the source; under its own name the part starts at the same values
  $partNames = @{}
  foreach ($e in @($doc.SelectNodes("//*[local-name()='part']"))) { $partNames[$e.GetAttribute("name")] = "{0}-PR{1}" -f $e.GetAttribute("name"), $Pr.Index }
  foreach ($e in @($doc.SelectNodes("//*[local-name()='part' or local-name()='usePart']"))) {
    $n = $e.GetAttribute("name")
    if ($partNames.ContainsKey($n)) { $e.SetAttribute("name", $partNames[$n]) }
  }

  # relative hrefs of the source (op:include, op:part ...) point from the folder of the output to the same files, or to the copy
  # of a file that another <PartRows> copies
  $srcDir = [System.IO.Path]::GetDirectoryName($Pr.Source); $outDir = [System.IO.Path]::GetDirectoryName($Pr.Output)
  foreach ($e in @($doc.SelectNodes("//*[@href]"))) { $e.SetAttribute("href", (Get-PartRowsHref $M $e.GetAttribute("href") $srcDir $outDir)) }

  $head = " Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<PartRows>) from {0} - do not edit " -f ($Pr.SourceAttr -replace '\\', '/')
  # a document takes no whitespace node: the line break after the comment goes into the text
  $headNode = $doc.CreateComment((ConvertTo-XmlComment $head))
  [void]$doc.InsertBefore($headNode, $doc.DocumentElement)
  $text = $doc.OuterXml -replace "`r`n", "`n"
  # %N% / %N-1% (channel count of the module): the producer does not replace them in a copy that gives only the Dynamic
  if ($text.Contains("%N%") -or $text.Contains("%N-1%")) {
    $nc = Get-PartRowsChannelCount $M $Pr
    if ($null -ne $nc) { $text = $text.Replace("%N-1%", [string]($nc - 1)).Replace("%N%", [string]$nc) }
  }
  $at = $text.IndexOf($headNode.OuterXml) + $headNode.OuterXml.Length
  return $text.Substring(0, $at) + "`n" + $text.Substring($at) + "`n"
}
