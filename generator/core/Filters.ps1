#Requires -Version 5.1
<#
Open =
-----+  Filters
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Filters.ps1

.SYNOPSIS
    Selection lists filtered per board (<Filters>): an existing dropdown offers only the values the selected board allows.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    ETS cannot hide single items of a list, so every value set gets its own ParameterType and a parameter without memory
    that copies the chosen value into the existing parameter (the carrier, <Assign> source): only the carrier holds memory,
    a choose on it, the conflict check and the firmware keep reading it. Boards that allow every value show the carrier.
    Functions: Read-FilterSource, Get-FilterValues, Get-FilterKey, Get-FilterBoardSet, New-FiltersXml.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Carrier of one <Filter> from its source file: the Parameter and its ParameterType (enumeration); stops when the
#        parameter or its type is not in the source or the type is no enumeration
function Read-FilterSource($Item) {
  $where = "<Filter name=`"{0}`">" -f $Item.Name
  $doc = New-Object System.Xml.XmlDocument
  try { $doc.LoadXml([System.IO.File]::ReadAllText($Item.Source, [System.Text.Encoding]::UTF8)) }
  catch { Stop-WithError (T "{0}: source {1} is not readable as XML: {2}" $where $Item.SourceAttr $_.Exception.Message) }
  $pars = @($doc.SelectNodes("//*[local-name()='Parameter']") | Where-Object { $_.GetAttribute("Id") -ceq $Item.Param })
  if ($pars.Count -ne 1) { Stop-WithError (T "{0}: source {1} has {2} Parameter with Id {3} (needs exactly one)" $where $Item.SourceAttr $pars.Count $Item.Param) }
  $p = $pars[0]
  $typeId = $p.GetAttribute("ParameterType")
  $types = @($doc.SelectNodes("//*[local-name()='ParameterType']") | Where-Object { $_.GetAttribute("Id") -ceq $typeId })
  if ($types.Count -ne 1) { Stop-WithError (T "{0}: the type {1} of the parameter is not defined in {2} (the filter copies its items from there)" $where $typeId $Item.SourceAttr) }
  $tr = @($types[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
  if ($tr.Count -ne 1 -or $tr[0].LocalName -cne "TypeRestriction" -or $tr[0].GetAttribute("Base") -cne "Value") {
    Stop-WithError (T "{0}: the type {1} is no enumeration (TypeRestriction Base=`"Value`")" $where $typeId)
  }
  $enums = @()
  foreach ($e in $tr[0].ChildNodes) {
    if ($e.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($e.LocalName -cne "Enumeration") { Stop-WithError (T "{0}: the type {1} holds <{2}>, only <Enumeration> can be filtered" $where $typeId $e.LocalName) }
    $iv = 0
    if (-not [int]::TryParse($e.GetAttribute("Value"), [ref]$iv)) { Stop-WithError (T "{0}: the type {1} has an item with Value `"{2}`" (needs an integer)" $where $typeId $e.GetAttribute("Value")) }
    $c = $e.CloneNode($true)
    $c.SetAttribute("Id", "%ENID%")
    $enums += @{ Value = $iv; Xml = ($c.OuterXml -replace ' xmlns="[^"]*"', '') }
  }
  if ($enums.Count -lt 2) { Stop-WithError (T "{0}: the type {1} has fewer than two items - nothing to filter" $where $typeId) }
  $trAttrs = ""
  foreach ($at in $tr[0].Attributes) { if ($at.Name -ne "xmlns") { $trAttrs += (" {0}=`"{1}`"" -f $at.Name, (ConvertTo-XmlText $at.Value)) } }
  $def = 0
  [void][int]::TryParse($p.GetAttribute("Value"), [ref]$def)
  $Item.Carrier = @{
    Name = $p.GetAttribute("Name"); Text = $p.GetAttribute("Text"); Default = $def
    TypeName = $types[0].GetAttribute("Name"); TrAttrs = $trAttrs; Enums = $enums
  }
  # parameter ids the source already uses (a generated list must not take one)
  $Item.SourceIds = @{}
  foreach ($q in $doc.SelectNodes("//*[local-name()='Parameter']")) { $Item.SourceIds[$q.GetAttribute("Id")] = $true }
  $all = @($enums | ForEach-Object { $_.Value })
  foreach ($a in $Item.Allows) {
    foreach ($v in $a.Values) { if ($all -notcontains $v) { Stop-WithError (T "{0}: <Allow board=`"{1}`"> names value {2}, the list has {3}" $where $a.Board $v ($all -join " ")) } }
  }
}

# @brief Every item value of the carrier list, in list order
function Get-FilterValues($Item) { return , @($Item.Carrier.Enums | ForEach-Object { $_.Value }) }

# @brief Key of a value set (sorted, comma separated) as written in the slot file
function Get-FilterKey($Values) { return (@($Values | Sort-Object -Unique) -join ",") }

# @brief Values one board may select: the first <Allow> in manifest order that matches the board (board define or pattern,
#        or capability), else the items up to the manifest value, else every item; stops when the set is empty
function Get-FilterBoardSet($Item, $Board) {
  $where = "<Filter name=`"{0}`">" -f $Item.Name
  $all = Get-FilterValues $Item
  $hit = $null
  foreach ($a in $Item.Allows) {
    if ($a.Capability) { if ($Board.Caps[$a.CapIndex]) { $hit = $a; break } }
    elseif (Test-Wildcard $a.Board $Board.Define) { $hit = $a; break }
  }
  if ($hit) { $set = @($hit.Values) }
  elseif ($Item.Value) {
    $n = [int]$Board.Val[$Item.Value]
    $set = @($all | Where-Object { $_ -le $n })
  }
  else { $set = $all }
  if ($set.Count -eq 0) { Stop-WithError (T "{0}: {1} allows no item of the list" $where $Board.Define) }
  return , @($set | Sort-Object -Unique)
}

# @brief Parts file of <Filters>: the ParameterTypes of every filter (path //ApplicationProgram/Static/ParameterTypes, the producer
#        takes types only from there) and per <Filter> the blocks _Parameters (memoryless, into the Parameters of the module),
#        the carrier), _ParameterRefs and Filter_<name> (in place of the row of the carrier): not selected and boards with every
#        value = the carrier, every other value set = its own parameter that copies its value into the carrier; a set with one
#        value is read-only
function New-FiltersXml($M, $Boards) {
  $refs = Get-ParamRefIds $M
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<KNX xmlns="http://knx.org/xml/project/20" xmlns:op="http://github.com/OpenKNX/OpenKNXproducer">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<Filters>) - do not edit -->")
  [void]$sb.AppendLine("  <!-- include: //ApplicationProgram/Static/ParameterTypes/ParameterType into the ParameterTypes; per filter _Parameters (no memory) into the Parameters, _ParameterRefs into the ParameterRefs, Filter_<name> in place of the row of the carrier -->")
  $types = New-Object System.Text.StringBuilder
  $blocks = New-Object System.Text.StringBuilder
  foreach ($f in $M.Filters.Items) {
    $all = Get-FilterKey (Get-FilterValues $f)
    $c = $f.Carrier
    # value sets in slot order; the full set is the carrier itself
    $sets = @($f.SetSlots.Keys | Where-Object { $_ -cne $all } | Sort-Object { $f.SetSlots[$_] })
    $used = @{}
    foreach ($b in $Boards) { $used[$b.FilterKeys[$f.Name]] = $true }
    $sets = @($sets | Where-Object { $used.ContainsKey($_) })
    $info = @{}
    foreach ($k in $sets) {
      $slot = $f.SetSlots[$k]
      $num = "{0:D5}" -f ($f.Number + $slot)
      $vals = @($k.Split(",") | ForEach-Object { [int]$_ })
      $def = $c.Default; if ($vals -notcontains $def) { $def = $vals[0] }
      $info[$k] = @{ Slot = $slot; Vals = $vals; Default = $def
                     Type = "%AID%_PT-{0}F{1}" -f $c.TypeName, $slot; TypeName = "{0}F{1}" -f $c.TypeName, $slot
                     Param = "%AID%_P-{0}{1}" -f $f.TT, $num; Ref = "%AID%_P-{0}{1}_R-{0}{1}01" -f $f.TT, $num
                     Name = "{0}F{1}" -f $c.Name, $slot; Fixed = ($vals.Count -eq 1) }
    }
    [void]$types.AppendLine(("<!-- <Filter name=`"{0}`"> -->" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      [void]$types.AppendLine(("<ParameterType Id=`"{0}`" Name=`"{1}`">" -f $s.Type, $s.TypeName))
      [void]$types.AppendLine(("  <TypeRestriction{0}>" -f $c.TrAttrs))
      foreach ($e in $c.Enums) { if ($s.Vals -contains $e.Value) { [void]$types.AppendLine("    " + $e.Xml) } }
      [void]$types.AppendLine("  </TypeRestriction>")
      [void]$types.AppendLine("</ParameterType>")
    }
    $sb0 = $sb; $sb = $blocks
    [void]$sb.AppendLine(("  <Block name=`"Filter_{0}_Parameters`">" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      [void]$sb.AppendLine(("    <Parameter Id=`"{0}`" Name=`"{1}`" ParameterType=`"{2}`" Text=`"{3}`" Value=`"{4}`" />" -f $s.Param, $s.Name, $s.Type, (ConvertTo-XmlText $c.Text), $s.Default))
    }
    [void]$sb.AppendLine("  </Block>")
    [void]$sb.AppendLine(("  <Block name=`"Filter_{0}_ParameterRefs`">" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      [void]$sb.AppendLine(("    <ParameterRef Id=`"{0}`" RefId=`"{1}`"{2} />" -f $s.Ref, $s.Param, $(if ($s.Fixed) { ' Access="Read"' } else { "" })))
    }
    [void]$sb.AppendLine("  </Block>")
    [void]$sb.AppendLine(("  <Block name=`"Filter_{0}`">" -f $f.Name))
    [void]$sb.AppendLine(("    <choose ParamRefId=`"{0}`">" -f $refs.Select))
    $full = @($Boards | Where-Object { $_.FilterKeys[$f.Name] -ceq $all })
    $ids = @([string]$M.UnselectedValue); if ($full.Count -gt 0) { $ids += (Get-IdList $full) }
    [void]$sb.AppendLine(("      <when test=`"{0}`">" -f ($ids -join " ")))
    [void]$sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`" IndentLevel=`"{1}`" />" -f $f.Ref, $f.Indent))
    [void]$sb.AppendLine("      </when>")
    foreach ($k in $sets) {
      $s = $info[$k]
      $grp = @($Boards | Where-Object { $_.FilterKeys[$f.Name] -ceq $k })
      [void]$sb.AppendLine(("      <!-- values {0} -->" -f ($s.Vals -join " ")))
      [void]$sb.AppendLine(("      <when test=`"{0}`">" -f (Get-IdList $grp)))
      [void]$sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`" IndentLevel=`"{1}`" />" -f $s.Ref, $f.Indent))
      if ($s.Fixed) { [void]$sb.AppendLine(("        <Assign TargetParamRefRef=`"{0}`" Value=`"{1}`" />" -f $s.Ref, $s.Vals[0])) }
      [void]$sb.AppendLine(("        <Assign TargetParamRefRef=`"{0}`" SourceParamRefRef=`"{1}`" />" -f $f.Ref, $s.Ref))
      [void]$sb.AppendLine("      </when>")
    }
    [void]$sb.AppendLine("    </choose>")
    [void]$sb.AppendLine("  </Block>")
    $sb = $sb0
  }
  [void]$sb.AppendLine("  <ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static><ParameterTypes>")
  [void]$sb.Append($types.ToString())
  [void]$sb.AppendLine("  </ParameterTypes></Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>")
  [void]$sb.Append($blocks.ToString())
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}
