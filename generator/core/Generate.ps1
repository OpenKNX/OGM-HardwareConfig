#Requires -Version 5.1
<#
Open =
-----+  Generate
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Generate.ps1

.SYNOPSIS
    The steps of a generator run after the manifest: boards, slots, pictures, outputs, version guard, writing, summary.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-ProductBoards, Update-SlotsAndPorts, New-CardImages, New-ProductOutputs, Test-ProductAndGuard,
    Write-ProductOutputs, Write-RunSummary.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Boards of the product: <Board> lines, PlatformIO envs and patterns, resolved per board, envs of one HW-ID merged, sorted; returns Boards and EnvCount
function Get-ProductBoards($m) {
  # <Board define="OKNXHW_OPENKNXIAO_*"/>: every board of OGM-HardwareConfig with a DEVICE_HW_ID whose
  # define matches - a board added to the headers joins the product without touching the manifest
  # explicit entries first and they win; a pattern only adds boards nobody named; the same board with
  # two different flag sets is ambiguous and stops the run
  $expanded = New-Object System.Collections.Generic.List[object]
  $allBoards = $null
  foreach ($pass in @("explicit", "pattern")) {
    foreach ($be in $m.Boards) {
      $isPattern = ($be.Define -match '[\*\?]')
      if (($pass -eq "explicit") -eq $isPattern) { continue }
      $names = @($be.Define)
      if ($isPattern) {
        if ($null -eq $allBoards) { $allBoards = @(Get-AllHardwareIdBoards) }
        $names = @(Get-OrdinalSorted @($allBoards | Where-Object { $_ -like $be.Define }))
        if ($names.Count -eq 0) { Stop-OnSkip (T "No board with DEVICE_HW_ID matches {0}" $be.Define) }
      }
      foreach ($n in $names) {
        $prev = @($expanded | Where-Object { $_.Define -eq $n })
        if ($prev.Count -eq 0) { $expanded.Add(@{ Define = $n; Flags = $be.Flags; Explicit = (-not $isPattern) }); continue }
        $norm = { param($f) (Get-OrdinalSorted @($f | ForEach-Object { $_ -replace '^-D', '' })) -join " " }
        $same = ((& $norm $prev[0].Flags) -eq (& $norm $be.Flags))
        if (-not $same -and (-not $isPattern -or -not $prev[0].Explicit)) {
          Stop-WithError (T "Board {0} is listed twice with different flags ('{1}' / '{2}')" $n ($prev[0].Flags -join " ") ($be.Flags -join " "))
        }
      }
    }
  }
  foreach ($pat in $m.EnvPatterns) {
    foreach ($eb in (Get-PlatformIOBoards $m $pat.Pattern $pat.Project $pat.Exclude)) {
      $expanded.Add(@{ Define = $eb.Define; Flags = $eb.Flags; Explicit = $false; Env = $eb.Env; Mcu = $eb.Mcu; Memory = $eb.Memory; Psram = $eb.Psram; Variant = $eb.Variant })
    }
  }
  Write-Step (T "Boards: {0}" $expanded.Count)

  $boards = @()
  $boardIndex = 0
  foreach ($be in $expanded) {
    $boardIndex++
    $boardLabel = $be.Define
    if ($be.Env) { $boardLabel = $be.Env }
    Write-Activity (T "Board {0}/{1}  {2}" $boardIndex $expanded.Count $boardLabel)
    $b = Resolve-Board $m $be
    $script:CompilerPath = $script:DefaultCompiler
    $b.Explicit = $be.Explicit
    $b.Env = $be.Env
    $b.Mcu = "$($be.Mcu)"
    $b.Envs = @()
    if ($be.Env) { $b.Envs = @($be.Env) }
    $capText = @()
    for ($i = 0; $i -lt $m.Capabilities.Count; $i++) { if ($b.Caps[$i]) { $capText += $m.Capabilities[$i].Name } }
    $valText = @()
    for ($i = 0; $i -lt $m.Values.Count; $i++) { $valText += ("{0}={1}" -f $m.Values[$i].Name, $b.Values[$i]) }
    $pinText = @()
    foreach ($role in $m.Roles) { $pinText += ("{0}:{1}" -f $role.Name, @($b.Pins[$role.Name]).Count) }
    if ($b.ReservedSkipped -gt 0) { $pinText += ("({0} reserved pin(s) left out)" -f $b.ReservedSkipped) }
    $envText = ""
    if ($be.Env) { $envText = "  [env:" + $be.Env + "]" }
    Write-Ok ("0x{0:X4} {1}{2}" -f $b.HwId, $b.Name, $envText)
    Write-Detail (T "           caps: {0}" ($capText -join ", "))
    Write-Detail ("           {0}  {1}" -f ($valText -join " "), ($pinText -join " "))
    $boards += $b
  }

  foreach ($ps in $m.PortSets) { if ($ps.Hits -eq 0) { Write-Warn (T "<Ports board=`"{0}`"> matches no board" $ps.Board) } }
  foreach ($t in $m.BoardTables) { if (-not $t.Found) { Write-Warn (T "<BoardTable name=`"{0}`">: no macro matches {1} on any board" $t.Name $t.Scan) } }

  # several envs build the same board with different flags (e.g. TP and TP+WiFi): one ETS entry with the
  # union of what the builds can do; the device query reports what one device was built with
  foreach ($g in ($boards | Where-Object { $_.Env } | Group-Object { $_.HwId } | Where-Object { $_.Count -gt 1 })) {
    $first = $g.Group[0]
    foreach ($o in @($g.Group | Select-Object -Skip 1)) {
      # one HW-ID, two different devices: a duplicate DEVICE_HW_ID, not two builds of one board
      if ($o.Name -ne $first.Name) { Stop-WithError (T "Duplicate DEVICE_HW_ID 0x{0:X4}: {1} ({2}) and {3} ({4})" ([int]$first.HwId) $first.Name $first.Env $o.Name $o.Env) }
      $portsA = (@($first.Ports) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $portsB = (@($o.Ports) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $relA = (@($first.Relays) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $relB = (@($o.Relays) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      if ($relA -cne $relB) { Stop-WithError (T "0x{0:X4}: env {1} has other relays than env {2}" ([int]$first.HwId) $o.Env $first.Env) }
      if ($o.InfoUrl -ne $first.InfoUrl) { Stop-WithError (T "0x{0:X4}: env {1} has another info URL than env {2}" ([int]$first.HwId) $o.Env $first.Env) }
      if ($o.InfoText -cne $first.InfoText) { Stop-WithError (T "0x{0:X4}: env {1} has another HW_INFO_TEXT than env {2}" ([int]$first.HwId) $o.Env $first.Env) }
      if ($o.InfoText2 -cne $first.InfoText2) { Stop-WithError (T "0x{0:X4}: env {1} has another HW_INFO_TEXT2 than env {2}" ([int]$first.HwId) $o.Env $first.Env) }
      if ($o.LogoFile -cne $first.LogoFile) { Stop-WithError (T "0x{0:X4}: env {1} has another HW_INFO_LOGO than env {2}" ([int]$first.HwId) $o.Env $first.Env) }
      # <PartRows> and <Fix valueMacro>: one row state and one value per HW-ID (ETS shows one page for every firmware of the board)
      foreach ($rk in @($first.PartRows.Keys)) {
        $sa = $first.PartRows[$rk]; $sb2 = $o.PartRows[$rk]
        if ($sa.On -ne $sb2.On -or $sa.Label -cne $sb2.Label) { Stop-WithError (T "0x{0:X4}: env {1} gives another <PartRows> row state or label than env {2} - the rows of a board must not depend on the env" ([int]$first.HwId) $o.Env $first.Env) }
      }
      foreach ($fk in @(@($first.FixValues.Keys) + @($o.FixValues.Keys) | Sort-Object -Unique)) {
        if ("$($first.FixValues[$fk])" -cne "$($o.FixValues[$fk])") { Stop-WithError (T "0x{0:X4}: env {1} gives <Fix name=`"{2}`"> another value macro than env {3}" ([int]$first.HwId) $o.Env $fk $first.Env) }
      }
      if ($o.Mcu -cne $first.Mcu) { Stop-WithError (T "0x{0:X4}: env {1} builds for MCU '{2}', env {3} for '{4}'" ([int]$first.HwId) $o.Env $o.Mcu $first.Env $first.Mcu) }
      # one port list per HW-ID: ETS offers one list for every firmware of the board
      if ($portsA -cne $portsB -or $first.PortCount -ne $o.PortCount) { Stop-WithError (T "0x{0:X4}: env {1} has other ports than env {2} (HW_PORT_*) - the ports of a board must not depend on the env" ([int]$first.HwId) $o.Env $first.Env) }
      for ($i = 0; $i -lt $first.Caps.Count; $i++) {
        # the firmware variants of the board differ in this capability (developer view: "je nach Firmware-Variante")
        if ([bool]$first.Caps[$i] -ne [bool]$o.Caps[$i]) { $first.CapMixed[$i] = $true }
        if ($m.Capabilities[$i].Merge -eq "all") { $first.Caps[$i] = ($first.Caps[$i] -and $o.Caps[$i]) }
        elseif ($o.Caps[$i]) { $first.Caps[$i] = $true }
      }
      $first.CapMask = [uint32]0
      for ($i = 0; $i -lt $first.Caps.Count; $i++) { if ($first.Caps[$i]) { $first.CapMask = $first.CapMask -bor ([uint32]1 -shl $i) } }
      $first.Envs += $o.Env
      # GPIOs the board uses: union over its envs; the TP state per env decides about the KNX UART pins
      $first.ReservedGpios = @(@($first.ReservedGpios) + @($o.ReservedGpios) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
      $first.TpGpios = @(@($first.TpGpios) + @($o.TpGpios) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
      $first.TpStates = @($first.TpStates) + @($o.TpStates)
      for ($i = 0; $i -lt $first.Values.Count; $i++) { if ($o.Values[$i] -gt $first.Values[$i]) { $first.Values[$i] = $o.Values[$i] } }
      # <BoardTable>: any = bitwise OR, all = bitwise AND per index over the envs (a missing index counts 0)
      foreach ($tn in @($m.BoardTables | ForEach-Object { $_.Name })) {
        $ta = $first.Tables[$tn]; $tb = $o.Tables[$tn]
        foreach ($ix in @(@($ta.Any.Keys) + @($tb.Any.Keys) | Sort-Object -Unique)) {
          $va = 0; if ($ta.Any.ContainsKey($ix)) { $va = $ta.Any[$ix] }
          $vb = 0; if ($tb.Any.ContainsKey($ix)) { $vb = $tb.Any[$ix] }
          $ta.Any[$ix] = [long]($va -bor $vb)
          $va = 0; if ($ta.All.ContainsKey($ix)) { $va = $ta.All[$ix] }
          $vb = 0; if ($tb.All.ContainsKey($ix)) { $vb = $tb.All[$ix] }
          $ta.All[$ix] = [long]($va -band $vb)
        }
      }
      foreach ($rn in @($o.Pins.Keys)) {
        $merged = @($first.Pins[$rn])
        foreach ($pin in $o.Pins[$rn]) { if (@($merged | Where-Object { $_.Gpio -eq $pin.Gpio }).Count -eq 0) { $merged += $pin } }
        $first.Pins[$rn] = @(Get-OrdinalSorted $merged { [regex]::Replace($_.Label, '\d+', { param($mt) $mt.Value.PadLeft(5, '0') }) })
      }
    }
    Write-Step (T "0x{0:X4} built by {1} envs ({2}) - one entry (capabilities: merge any/all, values: largest)" ([int]$g.Name) $g.Count (($g.Group | ForEach-Object { $_.Env }) -join ", "))
    Set-BoardMaps $m $first
    $keep = $first
    # drop only the other env members; a <Board> line or pattern board of this HW-ID goes on to the priority dedup
    $boards = @($boards | Where-Object { $_.HwId -ne [int]$g.Name -or -not $_.Env -or [object]::ReferenceEquals($_, $keep) })
  }
  # the "not selected" value is one more entry of the selection: it must not be a board's HW-ID
  $clash = @($boards | Where-Object { [int]$_.HwId -eq $m.UnselectedValue }) | Select-Object -First 1
  if ($clash) { Stop-WithError (T "{0} has DEVICE_HW_ID {1}, the value of not selected" $clash.Define $m.UnselectedValue) }
  # an explicit entry can resolve to the same HW-ID as a pattern board (alias define + flags):
  # the explicit one wins, two explicit ones stop
  $dups = $boards | Group-Object { $_.HwId } | Where-Object { $_.Count -gt 1 }
  foreach ($d in $dups) {
    # priority: a <Board> line of the manifest > a PlatformIO env (already merged per HW-ID) > a pattern
    $rank = { param($b) if ($b.Explicit) { 3 } elseif ($b.Env) { 2 } else { 1 } }
    $top = ($d.Group | ForEach-Object { & $rank $_ } | Measure-Object -Maximum).Maximum
    $winners = @($d.Group | Where-Object { (& $rank $_) -eq $top })
    $list = ($d.Group | ForEach-Object { $_.Define }) -join ", "
    if ($winners.Count -ne 1) { Stop-WithError (T "Duplicate DEVICE_HW_ID 0x{0:X4}: {1}" ([int]$d.Name) $list) }
    $keepDup = $winners[0]
    Write-Warn (T "0x{0:X4} reached twice ({1}) - {2} wins" ([int]$d.Name) $list $keepDup.Define)
    $boards = @($boards | Where-Object { $_.HwId -ne [int]$d.Name -or [object]::ReferenceEquals($_, $keepDup) })
  }
  # two boards with the same DEVICE_NAME would show two identical ETS entries
  foreach ($g in ($boards | Group-Object { $_.Name } | Where-Object { $_.Count -gt 1 })) {
    foreach ($b in $g.Group) { $b.Name = "{0} (0x{1:X4})" -f $b.Name, $b.HwId }
    Write-Warn (T "Same DEVICE_NAME for {0} boards - the ETS list adds the HW-ID: {1}" $g.Count $g.Name)
  }
  if ($boards.Count -lt 2) { Stop-WithError (T "A hardware selection needs at least two boards") }
  # order="hwid": ascending DEVICE_HW_ID; $b.Index = position in the final list
  if ($m.Order -eq "hwid") { $boards = @($boards | Sort-Object { [int]$_.HwId }) }
  for ($i = 0; $i -lt $boards.Count; $i++) { $boards[$i].Index = $i }
  $envCount = @($expanded | Where-Object { $_.Env }).Count
  return @{ Boards = $boards; EnvCount = $envCount }
}

# @brief Slot file (board numbers, bit order), port value check, GPIO conflict check; returns the slot file text
function Update-SlotsAndPorts($m, $boards) {
  # board number in IDs: the slot file
  $slotFile = Update-BoardSlots $m $boards
  # port value encoding: no offered port may sit on the manual or none value (it could never be selected)
  if ($null -ne $m.PortManual) {
    foreach ($b in $boards) {
      foreach ($pt in @($b.Ports)) {
        foreach ($kv in @(@("portManualValue", $m.PortManual), @("portNoneValue", $m.PortNone))) {
          if (($pt.N - 1) -eq $kv[1]) { Stop-WithError (T "{0}: ETS offers port {1}, its port value {3} (port number - 1) is {2} - leave the port out with <Ports use=...> or choose other values (e.g. 254 / 255)" $b.Define $pt.N $kv[0] $kv[1]) }
        }
      }
    }
  }
  if ($m.Conflicts) { Resolve-Conflicts $m $boards }
  if ($m.Conflicts -and $m.Filters) { Test-FilterConflictIds $m }
  return $slotFile
}

# @brief Pictures of the device card and the query steps; returns Images (rendered, written later)
function New-CardImages($m, $boards) {
  # device card pictures (logo, badge, QR code + caption): rendered with the text outputs, written after them
  $m.InfoGroups = Get-InfoGroups $m $boards
  $m.Marks = Get-CardMarks $m $boards
  $images = @()
  if ($m.Info) {
    $infoDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info"))
    try { $urlFont = Read-GlyphFont ([System.IO.Path]::Combine($script:GeneratorDir, "assets", "fonts")) $m.Info.UrlFont }
    catch { Stop-WithError (T "<InfoImage>: {0}" $_.Exception.Message) }
    # QR pictures first: a logo next to a QR code takes the height of that picture (a long URL raises the QR version)
    $imageIndex = 0
    foreach ($g in $m.InfoGroups) {
      # the caption under the QR code (<InfoImage caption>); the QR code holds the URL
      $imageIndex++
      Write-Activity (T "QR picture {0}/{1}  {2}" $imageIndex (@($m.InfoGroups).Count) $g.Url)
      try { $img = New-QrLinkImage $g.Url $m.Info.Caption $m.Info.Width $m.Info.Module $m.Info.Version $urlFont $m.Info.Supersample $m.Info.UrlRgb }
      catch { Stop-WithError (T "device card {0} ({1}): {2}" $g.File $g.Url $_.Exception.Message) }
      $g.QrPx = $img.QrPx; $g.ImgHeight = $img.Height
      $images += @{ Output = [System.IO.Path]::Combine($infoDir, $g.File); Image = $img }
      if ($img.Qr.Version -gt $m.Info.Version) { Write-Warn (T "device card {0}: the URL needs QR version {1} (manifest version {2}): {3}" $g.File $img.Qr.Version $m.Info.Version $g.Url) }
      Write-Step (T "device card {0}: {1}x{2} px, QR version {3}-{4} {5} px, caption {6:N1} px: {7}, {8} board(s)" $g.File $img.Width $img.Height $img.Qr.Version $img.Qr.Ec $img.QrPx $img.TextW $g.Url $g.Boards.Count)
    }
    try {
      $geo = Get-CardQrGeometry $m $urlFont
      $logoMaxW = $script:CardLogoColumnPx - 4
      foreach ($k in $m.Marks) {
        $img = Read-PngRgba $k.File
        # padded logo: height of the QR picture of its boards, the largest one (all of one size in the usual case); a board
        # without QR code takes the QR picture of the manifest version, so its logo stands on the same line
        $kGeo = $geo
        if ($k.Padded) {
          $urls = @($k.Boards | ForEach-Object { $_.InfoUrl })
          $gs = @($m.InfoGroups | Where-Object { $urls -ccontains $_.Url } | ForEach-Object { @{ QrPx = $_.QrPx; Height = $_.ImgHeight } })
          if (@($k.Boards | Where-Object { -not $_.InfoUrl }).Count -gt 0) { $gs += @{ QrPx = $geo.QrPx; Height = $geo.Height } }
          $sizes = @($gs | ForEach-Object { "{0}/{1}" -f $_.QrPx, $_.Height } | Sort-Object -Unique)
          $kGeo = @($gs | Sort-Object { $_.Height } -Descending)[0]
          if ($sizes.Count -gt 1) { Write-Warn (T "device card {0}.png stands next to QR codes of different size ({1}): padded for the largest" $k.Name ($sizes -join ", ")) }
        }
        # a logo fits the left card column and the height of the QR code
        if ($k.Padded -and ($img.Width -gt $logoMaxW -or $img.Height -gt $kGeo.QrPx)) {
          throw (T "logo {0} is {1}x{2} px, at most {3}x{4} px (left card column, QR code height)" $k.File $img.Width $img.Height $logoMaxW $kGeo.QrPx)
        }
        if (-not $k.Padded -and $img.Width -gt $logoMaxW) {
          throw (T "badge {0} is {1} px wide, at most {2} px (left card column)" $k.File $img.Width $logoMaxW)
        }
        if ($k.Padded) {
          # height of the QR picture, the logo centered on the QR code (the caption below it stays free)
          $h = $kGeo.Height; $top = [int][Math]::Floor(($kGeo.QrPx - $img.Height) / 2)
          $px = New-Object byte[] ($img.Width * $h * 4)
          [Array]::Copy($img.Pixels, 0, $px, $top * $img.Width * 4, $img.Width * $img.Height * 4)
          $img = @{ Width = $img.Width; Height = $h; Pixels = $px }
        }
        $images += @{ Output = [System.IO.Path]::Combine($infoDir, $k.Name + ".png"); Image = $img }
        Write-Step (T "device card {0}.png: {1}x{2} px from {3}, {4} board(s)" $k.Name $img.Width $img.Height $k.File (@($k.Boards).Count))
      }
    }
    catch { Stop-WithError (T "<InfoImage>: {0}" $_.Exception.Message) }
  }

  # <Page queryImage>: steps picture of the device query, copied as Baggages/<prefix>Info/Steps.png (at most the page width)
  if ($m.Page -and $m.Page.ImageFile) {
    try { $img = Read-PngRgba $m.Page.ImageFile }
    catch { Stop-WithError (T "<Page> queryImage: {0}" $_.Exception.Message) }
    if ($img.Width -gt $script:EtsPictureMaxWidth) { Stop-WithError (T "<Page> queryImage: {0} is {1} px wide, the page is {2} px wide" $m.Page.ImageFile $img.Width $script:EtsPictureMaxWidth) }
    $stepsDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info"))
    $images += @{ Output = [System.IO.Path]::Combine($stepsDir, "Steps.png"); Image = $img }
    Write-Step (T "query steps Steps.png: {0}x{1} px from {2}" $img.Width $img.Height $m.Page.ImageFile)
  }
  return @{ Images = $images }
}

# @brief Every output in memory (conf, share, developer view, script, header, conflicts, fixes, part rows, templates); returns Rendered and OwnOutputs
function New-ProductOutputs($m, $boards) {
  # every output is rendered before the first one is written: an error leaves no half-updated set
  $rendered = @()
  if ($m.Outputs.ContainsKey("conf")) { Write-OutputActivity (T "build") $m.Outputs["conf"]; $rendered += @{ Output = $m.Outputs["conf"]; Text = (New-ConfXml $m $boards) } }
  if ($m.Outputs.ContainsKey("share")) { Write-OutputActivity (T "build") $m.Outputs["share"]; $rendered += @{ Output = $m.Outputs["share"]; Text = (New-ShareXml $m $boards) } }
  if ($m.Page -and $m.Page.Dev) { Write-OutputActivity (T "build") $m.Page.Dev; $rendered += @{ Output = $m.Page.Dev; Text = (New-DevShareXml $m $boards) } }
  if ($m.Outputs.ContainsKey("script")) { Write-OutputActivity (T "build") $m.Outputs["script"]; $rendered += @{ Output = $m.Outputs["script"]; Text = (New-ScriptJs $m $boards) } }
  if ($m.Outputs.ContainsKey("header")) { Write-OutputActivity (T "build") $m.Outputs["header"]; $rendered += @{ Output = $m.Outputs["header"]; Text = (New-Header $m $boards) } }
  if ($m.Conflicts) { Write-OutputActivity (T "build") $m.Conflicts.Output; $rendered += @{ Output = $m.Conflicts.Output; Text = (New-ConflictsXml $m $boards) } }
  if ($m.Fixes) { Write-OutputActivity (T "build") $m.Fixes.Output; $rendered += @{ Output = $m.Fixes.Output; Text = (New-FixesXml $m $boards) } }
  foreach ($pr in @($m.PartRows)) { Write-OutputActivity (T "build") $pr.Output; $rendered += @{ Output = $pr.Output; Text = (New-PartRowsXml $m $boards $pr) } }
  if ($m.Filters) { Write-OutputActivity (T "build") $m.Filters.Output; $rendered += @{ Output = $m.Filters.Output; Text = (New-FiltersXml $m $boards) } }
  if ($m.ValueNotices) { Write-OutputActivity (T "build") $m.ValueNotices.Output; $rendered += @{ Output = $m.ValueNotices.Output; Text = (New-ValueNoticesXml $m $boards) } }

  # templates ("Bausteine"): whole generated files, never a splice into a hand-written file
  $vars = @{ Boards = $boards; M = $m }
  foreach ($g in $m.Generates) {
    Write-OutputActivity (T "build") $g.Output
    $vars["P"] = $g.Params
    try { $text = Invoke-TemplateFile -FullPath $g.Template -Vars $vars -FinalNewline $g.FinalNewline }
    catch { Stop-WithError (T "Template {0}: {1}" $g.Template $_.Exception.Message) }
    $rendered += @{ Output = $g.Output; Text = $text }
  }
  # <Conflicts>: numbers against the module files next to the parts file (hint); a parts file of an earlier run is reported
  $ownOutputs = @($rendered | ForEach-Object { [System.IO.Path]::GetFullPath($_.Output) })
  if ($m.Conflicts) { Test-ConflictNumbers $m $ownOutputs }
  return @{ Rendered = $rendered; OwnOutputs = $ownOutputs }
}

# @brief Product XML check and ETS fingerprint (version guard); returns Rendered (with the slot file) and Products
function Test-ProductAndGuard($m, $slotFile, $rendered, $images) {
  # product XMLs of the OAM: inclusion of the hardware module, ApplicationVersion for the ETS fingerprint
  $products = Get-ProductXmls $m
  Test-ProductXmls $m $products
  if ($null -ne $slotFile) {
    Add-EtsFingerprint $m $slotFile $rendered $images $products
    $rendered += @{ Output = $slotFile.Output; Text = $slotFile.Text }
  }
  return @{ Rendered = $rendered; Products = $products }
}

# @brief Writes (or with -Check compares, with -DryRun lists) every output, the pictures and the page icon; returns the state text of the step
function Write-ProductOutputs($m, $rendered, $images, $ownOutputs) {
  foreach ($f in (Get-StaleConflictFiles $m $ownOutputs)) {
    Write-Warn (T "{0} is a <Conflicts> parts file of an earlier run (no <Conflicts output> names it any more) - delete it and its op:include lines" $f)
    if ($script:CheckMode) { Add-Written $f }
  }
  foreach ($r in $rendered) {
    Write-OutputActivity (T "compare") $r.Output
    if ($DryRun) { Write-Step (T "would write {0}" $r.Output) }
    elseif (Update-Utf8File $r.Output $r.Text) { Add-Written $r.Output; Write-Ok (T "wrote {0}" $r.Output) }
    else { Write-Detail (T "  = unchanged {0}" $r.Output) }
  }
  foreach ($r in $images) {
    if ($DryRun) { Write-Step (T "would write {0}" $r.Output) }
    elseif (Update-PngRgba $r.Output $r.Image.Width $r.Image.Height $r.Image.Pixels) { Add-Written $r.Output; Write-Ok (T "wrote {0}" $r.Output) }
    else { Write-Detail (T "  = unchanged {0}" $r.Output) }
  }
  # page icon of the generator (assets/icons/<icon>.png) next to the share: Baggages/Icons/<icon>.png (producer: Icons.zip)
  if ($m.Page -and $m.Page.IconFile) {
    $iconOut = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", "Icons", $m.Page.Icon + ".png")
    $iconBytes = [System.IO.File]::ReadAllBytes($m.Page.IconFile)
    $same = $false
    if (Test-Path -LiteralPath $iconOut -PathType Leaf) {
      $old = [System.IO.File]::ReadAllBytes($iconOut)
      $same = ($old.Length -eq $iconBytes.Length) -and ([System.Convert]::ToBase64String($old) -ceq [System.Convert]::ToBase64String($iconBytes))
    }
    if ($DryRun) { Write-Step (T "would write {0}" $iconOut) }
    elseif ($same) { Write-Detail (T "  = unchanged {0}" $iconOut) }
    elseif ($script:CheckMode) { Add-Written $iconOut }
    else {
      [void](New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($iconOut)))
      [System.IO.File]::WriteAllBytes($iconOut, $iconBytes)
      Add-Written $iconOut
      Write-Ok (T "wrote {0}" $iconOut)
    }
  }
  # the generator owns the info folder: pictures it no longer writes go
  # <InfoImage> and <Page> both need <Output share>; without either the folder is not the generator's
  if ($m.Info -or $m.Page) { $infoDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info")) }
  if (($m.Info -or $m.Page) -and -not $DryRun -and (Test-Path -LiteralPath $infoDir)) {
    $keep = @($images | ForEach-Object { [System.IO.Path]::GetFileName($_.Output) })
    foreach ($f in (Get-ChildItem -LiteralPath $infoDir -Filter "*.png")) {
      if ($keep -notcontains $f.Name) {
        if (-not $script:CheckMode) { Remove-Item -LiteralPath $f.FullName; Write-Ok (T "removed {0}" $f.FullName) }
        Add-Written $f.FullName
      }
    }
  }
  if ($script:CheckMode) { $phaseState = $(if ($script:WrittenCount -eq 0) { T "up to date" } else { T "{0} out of date" $script:WrittenCount }) }
  elseif ($DryRun) { $phaseState = T "{0} file(s), nothing written" $rendered.Count }
  else { $phaseState = $(if ($script:WrittenCount -eq 0) { T "unchanged" } else { T "{0} written" $script:WrittenCount }) }
  return $phaseState
}

# @brief Board list and summary line (compact), or the end of the full log; exit 1 when -Check finds an output out of date
function Write-RunSummary($m, $boards, $envCount) {
  if ($script:Compact) {
    Clear-Activity
    Write-Host ""
    # one line per board (by HW-ID), then the summary
    foreach ($b in @($boards | Sort-Object { [int]$_.HwId })) { Write-Host ("  OK 0x{0:X4}  {1}" -f [int]$b.HwId, $b.Name) -ForegroundColor Green }
    $parts = @()
    if ($envCount -gt 0) { $parts += (T "{0} Envs" $envCount) }
    $parts += (T "{0} Boards" $boards.Count)
    if ($script:CheckMode) {
      if ($script:WrittenCount -eq 0) { Write-Host (T "Hardware: {0}, Check: up to date" ($parts -join ", ")) -ForegroundColor Green; exit 0 }
      Write-Host (T "Hardware: {0}, Check: {1} file(s) out of date: {2} - run the generator (delete stale <Conflicts> files by hand)" ($parts -join ", ") $script:WrittenCount ($script:WrittenFiles -join ", ")) -ForegroundColor Red
      exit 1
    }
    if ($script:WrittenCount -eq 0) { $state = T "unchanged" }
    elseif ($script:WrittenCount -eq 1) { $state = T "1 file written" }
    else { $state = T "{0} files written" $script:WrittenCount }
    if ($script:WrittenCount -gt 0 -and $script:WrittenCount -le 3) { $state += " (" + ($script:WrittenFiles -join ", ") + ")" }
    Write-Host ("Hardware: {0}, {1}" -f ($parts -join ", "), $state) -ForegroundColor Green
    if ($script:WarningCount -gt 0) { Write-Host (T "  {0} warning(s)" $script:WarningCount) -ForegroundColor Yellow }
  }
  else {
    Write-Host ""
    if ($script:CheckMode -and $script:WrittenCount -gt 0) {
      Write-Host (T "  Check: {0} file(s) not current: {1}" $script:WrittenCount ($script:WrittenFiles -join ", ")) -ForegroundColor Red
      exit 1
    }
    if ($script:CheckMode) { Write-Host (T "  Check: current") -ForegroundColor Green }
    elseif ($script:WarningCount -gt 0) { Write-Host (T "  done with {0} warning(s)" $script:WarningCount) -ForegroundColor Yellow }
    else { Write-Host (T "  done") -ForegroundColor Green }
  }
}
