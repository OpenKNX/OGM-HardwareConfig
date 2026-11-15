#Requires -Version 5.1
<#
Open =
-----+  Manifest
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Manifest.ps1

.SYNOPSIS
    Manifest (HardwareProfile.xml): read, check unknown nodes, <Conflicts> declaration.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: ConvertTo-FlagList, Test-ManifestNodes, Read-Manifest, Get-ConflictInt, ConvertFrom-ConflictCondition, Read-ConflictsNode.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# ------------------------------------------------------------------------------------------------
# Manifest
# ------------------------------------------------------------------------------------------------
# "-DA -D B=1 C" -> "-DA", "-DB=1", "-DC" (platformio.ini writes "-D NAME" with a space)
function ConvertTo-FlagList([string]$Text) {
  $tokens = @($Text -split '\s+' | Where-Object { $_ })
  $list = @()
  for ($i = 0; $i -lt $tokens.Count; $i++) {
    $t = $tokens[$i]
    if ($t -eq "-D") {
      if ($i + 1 -ge $tokens.Count) { Stop-WithError "flags: '-D' without a macro name" }
      $i++
      $t = "-D" + $tokens[$i]
    }
    elseif ($t -notmatch '^-D') { $t = "-D" + $t }
    # only -DNAME or -DNAME=VALUE without spaces or quotes: anything else would be split or misread
    if ($t -notmatch '^-D[A-Za-z_][A-Za-z0-9_]*(=[^\s"'']*)?$') { Stop-WithError "flags: '$t' is not -DNAME or -DNAME=VALUE (no spaces, no quotes, no other options)" }
    $list += $t
  }
  return ,$list
}
# @brief Attributes and child elements the generator reads per manifest element ("*": the element checks its attributes itself
#        and stops: Conflicts, Use, InfoImage, BoardTable). Test-ManifestNodes warns about anything else: a typo would fall back
#        to the default without a word.
$script:ManifestNodes = @{
  HardwareProfile = @("prefix moduleType text unselected order ids portManualValue portNoneValue unselectedValue",
                      "Output Generate IncludePath Import Capability Value ReservedPins Board Boards Ports GpioRole Page Notice InfoImage Conflicts BoardTable Fixes")
  CapabilityPack  = @("name", "Capability Value ReservedPins")
  Output          = @("conf share script header", "")
  Generate        = @("template output finalNewline", "Param")
  "Generate/Param" = @("name value", "")
  "Conflicts/Param" = @("name ref", "")
  Import          = @("href", "")
  IncludePath     = @("", "")
  Capability      = @("name text expr merge switch fixedBy reportedBy runtime feature featureOn featureOff featureInvert featureNote featureNoteWhen", "")
  Value           = @("name text expr ifdef default max unit names query relays", "Set")
  Set             = @("board value", "")
  ReservedPins    = @("macros", "")
  Board           = @("define flags", "")
  Boards          = @("platformio exclude project", "")
  Ports           = @("board use max excludeRelayPins", "")
  GpioRole        = @("name number text count", "Pins")
  Pins            = @("board label scan", "Pin")
  Pin             = @("gpio label", "")
  Page            = @("text icon help features dev title label intro queryTitle query button queryHelp queryImage unselectedTitle infoDefault unselectedInfo unselectedText updateInfo changeInfo firmware more summary portsText portsTextOne", "")
  Notice          = @("when title", "Text")
  Text            = @("", "")
  Conflicts       = @("*", "Param Use ChannelBlock")
  Use             = @("*", "Manual")
  Manual          = @("ref when", "")
  ChannelBlock    = @("name text uses", "")
  InfoImage       = @("*", "Logo")
  Logo            = @("board file", "")
  BoardTable      = @("*", "")
  Fixes           = @("output", "Fix")
  Fix             = @("name capability ref value show indent help", "")
}
function Test-ManifestNodes($Node, [string]$File) {
  $spec = $null
  if ($Node.ParentNode -and $Node.ParentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) { $spec = $script:ManifestNodes[$Node.ParentNode.LocalName + "/" + $Node.LocalName] }
  if ($null -eq $spec) { $spec = $script:ManifestNodes[$Node.LocalName] }
  if ($null -eq $spec) { return }
  $attrs = @($spec[0] -split ' ' | Where-Object { $_ })
  foreach ($at in $Node.Attributes) {
    if ($spec[0] -eq "*") { break }
    if ($at.Name -eq "xmlns" -or $at.Name.Contains(":")) { continue }
    if ($attrs -cnotcontains $at.Name) { Write-Warn ("{0}: <{1}> attribute {2} is unknown and ignored (known: {3})" -f $File, $Node.LocalName, $at.Name, ($attrs -join ", ")) }
  }
  $kids = @($spec[1] -split ' ' | Where-Object { $_ })
  foreach ($c in $Node.ChildNodes) {
    if ($c.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($kids -cnotcontains $c.LocalName) { Write-Warn ("{0}: <{1}> inside <{2}> is unknown and ignored" -f $File, $c.LocalName, $Node.LocalName); continue }
    Test-ManifestNodes $c $File
  }
}
function Read-Manifest([string]$Path) {
  if (-not (Test-Path $Path)) { Stop-WithError "Manifest not found: $Path" }
  $full = (Resolve-Path $Path).Path
  $baseDir = [System.IO.Path]::GetDirectoryName($full)
  [xml]$doc = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
  $root = $doc.HardwareProfile
  if (-not $root) { Stop-WithError "Manifest root element must be <HardwareProfile>" }
  Test-ManifestNodes $root ([System.IO.Path]::GetFileName($full))
  if ("$($root.prefix)" -and "$($root.prefix)" -cnotmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("prefix `"{0}`" must be letters and digits (it is part of ETS, JavaScript and C names)" -f $root.prefix) }

  $m = @{
    ManifestPath = $full
    BaseDir      = $baseDir
    Prefix       = "$($root.prefix)"
    ModuleType   = [int]"$($root.moduleType)"
    Text         = "$($root.text)"
    Outputs      = @{}
    IncludeDirs  = @()
    Boards       = New-Object System.Collections.Generic.List[object]
    Capabilities = New-Object System.Collections.Generic.List[object]
    Values       = New-Object System.Collections.Generic.List[object]
    Roles        = New-Object System.Collections.Generic.List[object]
    Reserved     = @()
  }
  if (-not $m.Prefix) { $m.Prefix = "HWP" }
  if (-not $m.Text) { $m.Text = "Ger$([char]0xE4)t" }
  # unselected = what "not selected" (0) means for the feature flags:
  #   showAll (default) - 0 counts as every capability: an OAM that wraps existing pages in feature flags keeps them
  #                       visible after the app update; ETS writes the default of every INVISIBLE parameter
  #                       on download, so hiding them before the user picks a hardware would reset his values
  #   hide              - 0 shows nothing hardware dependent (new products without existing projects)
  $m.Unselected = "$($root.unselected)"
  if (-not $m.Unselected) { $m.Unselected = "showAll" }
  if ($m.Unselected -ne "showAll" -and $m.Unselected -ne "hide") { Stop-WithError "unselected must be showAll or hide" }
  # value of "not selected" in the hardware selection: always 0 (NOT_SELECTED; no HW-ID is 0)
  $m.UnselectedValue = 0
  if ("$($root.unselectedValue)" -and "$($root.unselectedValue)" -ne "0") { Stop-WithError "unselectedValue was removed: not selected is always 0" }
  # port value encoding of the application's port selections (one declaration for the ETS conflict check and the firmware
  # header): 0..n-1 = port n of the board, portManualValue = manual GPIO, portNoneValue = no port, any other value = no GPIO
  $m.PortManual = $null; $m.PortNone = $null
  foreach ($a in @(@("portManualValue", "PortManual", 254), @("portNoneValue", "PortNone", 255))) {
    if (-not $root.HasAttribute($a[0])) { continue }
    $t = "$($root.GetAttribute($a[0]))".Trim()
    if ($t -notmatch '^\d+$' -or [int64]$t -gt $a[2]) { Stop-WithError ("{0} must be a number 0..{1}" -f $a[0], $a[2]) }
    $m[$a[1]] = [int]$t
  }
  if (($null -eq $m.PortManual) -ne ($null -eq $m.PortNone)) { Stop-WithError "portManualValue and portNoneValue go together" }
  if ($null -ne $m.PortManual -and $m.PortManual -eq $m.PortNone) { Stop-WithError "portManualValue and portNoneValue must differ" }

  # board order: hwid (default, ascending DEVICE_HW_ID) or manifest (order of the entries)
  $m.Order = "$($root.order)"
  if (-not $m.Order) { $m.Order = "hwid" }
  if ($m.Order -ne "manifest" -and $m.Order -ne "hwid") { Stop-WithError "order must be manifest or hwid" }
  # board number ($b.Slot) in IDs: always the slot file (stable over the product life); ids="slot" is still accepted
  if ("$($root.ids)" -and "$($root.ids)" -ne "slot") { Stop-WithError "ids=`"$($root.ids)`" was removed: the board number in IDs always comes from the slot file" }

  # every output is optional; share (the ETS module) needs script and moduleType
  foreach ($o in @("conf", "share", "script", "header")) {
    $p = ""
    if ($root.Output) { $p = "$($root.Output.GetAttribute($o))" }
    if ($p) { $m.Outputs[$o] = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $p)) }
  }
  if ($m.Outputs.ContainsKey("share") -and -not $m.Outputs.ContainsKey("script")) { Stop-WithError "<Output share=...> needs script=..." }
  if ($m.Outputs.ContainsKey("share") -and ($m.ModuleType -lt 1 -or $m.ModuleType -gt 99)) { Stop-WithError "moduleType must be 1..99 (it is the %TT% of the ETS module)" }

  # <Generate template="..." output="..." [finalNewline="false"]><Param name="..." value="..."/></Generate>
  $m.Generates = New-Object System.Collections.Generic.List[object]
  foreach ($g in $root.SelectNodes("Generate")) {
    $tp = "$($g.template)"; $op = "$($g.output)"
    if (-not $tp -or -not $op) { Stop-WithError "<Generate> needs template=... and output=..." }
    if ($tp.StartsWith("@hw/")) { $tFull = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:GeneratorDir, "templates", $tp.Substring(4))) }
    else { $tFull = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $tp)) }
    $params = @{}
    foreach ($pn in $g.SelectNodes("Param")) { $params["$($pn.name)"] = "$($pn.value)" }
    $m.Generates.Add(@{ Template = $tFull; Output = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $op)); Params = $params; FinalNewline = ("$($g.finalNewline)" -ne "false") })
  }
  foreach ($inc in $root.SelectNodes("IncludePath")) {
    $m.IncludeDirs += [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $inc.InnerText.Trim()))
  }

  # capability packs first, then the manifest's own entries (same name = override)
  $sources = @()
  foreach ($imp in $root.SelectNodes("Import")) {
    $ip = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $imp.href))
    if (-not (Test-Path $ip)) { Stop-WithError "Import not found: $ip" }
    [xml]$pack = [System.IO.File]::ReadAllText($ip, [System.Text.Encoding]::UTF8)
    Test-ManifestNodes $pack.DocumentElement ([System.IO.Path]::GetFileName($ip))
    $sources += $pack.DocumentElement
  }
  $sources += $root

  $capIndex = @{}; $valIndex = @{}
  # built in: ThirdParty = the board header defines DEVICE_THIRD_PARTY (board identity, like DEVICE_HW_ID); always bit 0 of
  # the device query; the device card (badge) and <Notice when="ThirdParty"> rely on it
  $m.Capabilities.Add(@{ Name = "ThirdParty"; Text = "Ger$([char]0xE4)t eines Drittanbieters"; Expr = "defined(DEVICE_THIRD_PARTY)"; Merge = "any"; Switch = $false
    FixedBy = ""; ReportedBy = ""; Feature = ""; FeatureOn = ""; FeatureOff = ""; FeatureInvert = $false; FeatureNote = ""; FeatureNoteWhen = "" })
  $capIndex["ThirdParty"] = 0
  foreach ($src in $sources) {
    foreach ($c in $src.SelectNodes("Capability")) {
      if ("$($c.name)" -eq "ThirdParty") { Stop-WithError "Capability ThirdParty is built into the generator (DEVICE_THIRD_PARTY) - remove this <Capability>" }
      # merge = how the envs of one board combine: any (default, union) or all (every env has it)
      $entry = @{ Name = $c.name; Text = $c.text; Expr = $c.expr; Merge = "$($c.merge)"; Switch = $false; FixedBy = "$($c.fixedBy)"; ReportedBy = "$($c.reportedBy)" }
      # <Page features> (developer view): feature = row label (default text), featureOn / featureOff = value when the board
      # has / lacks it (default ja / nein), featureInvert = the board has the feature when the capability is false,
      # featureNote = appended to "has" on boards that also have capability featureNoteWhen
      $entry.Feature = "$($c.feature)"; $entry.FeatureOn = "$($c.featureOn)"; $entry.FeatureOff = "$($c.featureOff)"
      $entry.FeatureInvert = ("$($c.featureInvert)" -eq "true"); $entry.FeatureNote = "$($c.featureNote)"; $entry.FeatureNoteWhen = "$($c.featureNoteWhen)"
      if (($entry.FeatureNote -and -not $entry.FeatureNoteWhen) -or ($entry.FeatureNoteWhen -and -not $entry.FeatureNote)) { Stop-WithError "Capability $($entry.Name): featureNote and featureNoteWhen go together" }
      if (-not $entry.Merge) { $entry.Merge = "any" }
      # switch="true": on/off parameter with device memory (default on); fixedBy: boards that also have that capability
      # show "always on" instead; reportedBy: query bit that says whether the firmware has it (default: own bit)
      $sw = "$($c.switch)"
      if ($sw -and $sw -ne "true" -and $sw -ne "false") { Stop-WithError "Capability $($entry.Name): switch must be true or false" }
      if ($sw -eq "true") { $entry.Switch = $true }
      if (-not $entry.Switch -and ($entry.FixedBy -or $entry.ReportedBy)) { Stop-WithError "Capability $($entry.Name): fixedBy/reportedBy need switch=`"true`"" }
      if ($entry.Merge -ne "any" -and $entry.Merge -ne "all") { Stop-WithError "Capability $($entry.Name): merge must be any or all" }
      # runtime="true": the board has the place for it (expr), the firmware detects the part at run time and reports it
      # through answerQuery(runtimeCaps); its bit is not part of OWN_CAPS
      $rt = "$($c.runtime)"
      if ($rt -and $rt -ne "true" -and $rt -ne "false") { Stop-WithError "Capability $($entry.Name): runtime must be true or false" }
      $entry.Runtime = ($rt -eq "true")
      if ($entry.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "Capability name must be alphanumeric: $($entry.Name)" }
      if ($capIndex.ContainsKey($entry.Name)) { $m.Capabilities[$capIndex[$entry.Name]] = $entry }
      else { $capIndex[$entry.Name] = $m.Capabilities.Count; $m.Capabilities.Add($entry) }
    }
    foreach ($v in $src.SelectNodes("Value")) {
      $entry = @{ Name = $v.name; Text = $v.text; Expr = "$($v.expr)"; IfDef = "$($v.ifdef)"; Default = [int]"$($v.default)"; Max = [int]"$($v.max)"; Unit = "$($v.unit)"; Sets = @(); Query = $true }
      # relays="true": the value counts relays; the first HW_RELAY_COUNT are the board's hard-wired relays, every further one
      # takes a port (developer view row of <Page features>)
      $rl = "$($v.relays)"
      if ($rl -and $rl -ne "true" -and $rl -ne "false") { Stop-WithError "Value $($entry.Name): relays must be true or false" }
      $entry.Relays = ($rl -eq "true")
      # names="a b c": display name of value 0, 1, 2, ... (developer view)
      $entry.Names = @("$($v.names)" -split '\s+' | Where-Object { $_ })
      # query="false": the value exists only in ETS (feature flags, capability page); the device query and the firmware
      # header leave it out, so a <Set> value can coexist with <Output header>
      $q = "$($v.query)"
      if ($q -and $q -ne "true" -and $q -ne "false") { Stop-WithError "Value $($entry.Name): query must be true or false" }
      if ($q -eq "false") { $entry.Query = $false }
      # <Set board="pattern" value="n"/>: value of the matching boards (ETS only); a define without * or ? wins
      # over a pattern, two matching entries of the same kind stop the run
      foreach ($st in $v.SelectNodes("Set")) {
        $sv = ConvertFrom-CInteger "$($st.value)"
        if (-not "$($st.board)" -or $null -eq $sv) { Stop-WithError "Value $($entry.Name): <Set> needs board=... and a number value=..." }
        $entry.Sets += @{ Board = "$($st.board)"; Value = [int]$sv; Pattern = ("$($st.board)" -match '[\*\?]') }
      }
      if ($entry.Expr) {
        if (-not $entry.IfDef -and $entry.Expr -match '^[A-Za-z_][A-Za-z0-9_]*$') { $entry.IfDef = $entry.Expr }
        if (-not $entry.IfDef) { Stop-WithError "Value $($entry.Name): expr is not a macro name - set ifdef=`"<macro that must exist>`"" }
      }
      elseif ($entry.Sets.Count -eq 0) { Stop-WithError "Value $($entry.Name): needs expr=... or <Set> entries" }
      if ($entry.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "Value name must be alphanumeric: $($entry.Name)" }
      if ($entry.Max -lt 1 -or $entry.Max -gt 255) { Stop-WithError "Value $($entry.Name): max must be 1..255" }
      if ($valIndex.ContainsKey($entry.Name)) { $m.Values[$valIndex[$entry.Name]] = $entry }
      else { $valIndex[$entry.Name] = $m.Values.Count; $m.Values.Add($entry) }
    }
    foreach ($rp in $src.SelectNodes("ReservedPins")) {
      foreach ($mac in ("$($rp.macros)" -split '\s+')) { if ($mac -and -not ($m.Reserved -contains $mac)) { $m.Reserved += $mac } }
    }
  }
  # bit order of the device query from the slot file: a recorded name keeps its bit, the rest follows in manifest order,
  # so a pack (Common.caps.xml) or the manifest can grow anywhere without moving a bit of a firmware in the field
  Set-RecordedBitOrder $m
  $capIndex = @{}; for ($i = 0; $i -lt $m.Capabilities.Count; $i++) { $capIndex[$m.Capabilities[$i].Name] = $i }
  $valIndex = @{}; for ($i = 0; $i -lt $m.Values.Count; $i++) { $valIndex[$m.Values[$i].Name] = $i }
  if ($m.Capabilities.Count -gt $MAX_CAPABILITIES) { Stop-WithError "At most $MAX_CAPABILITIES capabilities fit the device query" }
  $switchCount = 0
  foreach ($c in $m.Capabilities) {
    if (-not $c.Switch) { continue }
    $switchCount++
    foreach ($ref in @($c.FixedBy, $c.ReportedBy)) {
      if ($ref -and -not $capIndex.ContainsKey($ref)) { Stop-WithError "Capability $($c.Name): unknown capability $ref" }
    }
    if ($c.FixedBy -eq $c.Name) { Stop-WithError "Capability $($c.Name): fixedBy must name another capability" }
    # a runtime part is detected by the firmware: it cannot fix a switch on, and its own state is its own bit
    if ($c.FixedBy -and $m.Capabilities[$capIndex[$c.FixedBy]].Runtime) { Stop-WithError "Capability $($c.Name): fixedBy=`"$($c.FixedBy)`" is a runtime capability (only a build-time capability can fix a switch on)" }
    if ($c.Runtime -and $c.ReportedBy -and $c.ReportedBy -ne $c.Name) { Stop-WithError "Capability $($c.Name): runtime=`"true`" reports its own bit - remove reportedBy" }
  }
  if ($switchCount -gt $MAX_SWITCHES) { Stop-WithError "At most $MAX_SWITCHES capabilities with switch=`"true`" (one byte)" }
  foreach ($c in $m.Capabilities) {
    if ($c.FeatureNoteWhen -and -not $capIndex.ContainsKey($c.FeatureNoteWhen)) { Stop-WithError "Capability $($c.Name): featureNoteWhen names an unknown capability $($c.FeatureNoteWhen)" }
  }
  if (@($m.Values | Where-Object { $_.Query }).Count -gt $MAX_VALUES) { Stop-WithError "At most $MAX_VALUES values fit the device query (query=`"false`" leaves a value out)" }

  foreach ($b in $root.SelectNodes("Board")) { $m.Boards.Add(@{ Define = $b.define; Flags = (ConvertTo-FlagList "$($b.flags)") }) }
  # <Boards platformio="release_*" [project="."]/>: the envs of the PlatformIO project (default: the manifest's folder)
  $m.EnvPatterns = @($root.SelectNodes("Boards") | Where-Object { "$($_.platformio)" } | ForEach-Object {
      $proj = "$($_.project)"
      if (-not $proj) { $proj = "." }
      # exclude = env name patterns that are not boards (test or tool envs), separated by blanks
      $ex = @("$($_.exclude)" -split '\s+' | Where-Object { $_ })
      @{ Pattern = "$($_.platformio)"; Exclude = $ex; Project = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $proj)) }
    })
  if ($m.Boards.Count -lt 1 -and $m.EnvPatterns.Count -lt 1) { Stop-WithError "No <Board> or <Boards platformio=...> entry" }

  # <Ports board="pattern" use="1 3 5-8"/>: the hardware port numbers offered on the matching boards
  $m.PortSets = New-Object System.Collections.Generic.List[object]
  foreach ($ps in $root.SelectNodes("Ports")) {
    $pat = "$($ps.board)"; $use = "$($ps.use)"
    # excludeRelayPins="true": a port whose GPIO is a relay of the board (HW_RELAY_<n>_GPIO) is not offered
    $xr = "$($ps.excludeRelayPins)"
    if ($xr -and $xr -ne "true" -and $xr -ne "false") { Stop-WithError ("<Ports board=`"{0}`">: excludeRelayPins must be true or false" -f $pat) }
    # max="n": the highest port number the product can store (its value layout); a board with more ports stops the run
    $mx = "$($ps.max)"
    if ($mx -and ($mx -notmatch '^\d+$' -or [int]$mx -lt 1 -or [int]$mx -gt $MAX_PORTS)) { Stop-WithError ("<Ports board=`"{0}`">: max must be 1..{1}" -f $pat, $MAX_PORTS) }
    if (-not $pat -or (-not $use -and $xr -ne "true" -and -not $mx)) { Stop-WithError "<Ports> needs board=... and use=... (or excludeRelayPins=`"true`" or max=...)" }
    $nums = @()
    foreach ($tok in @($use -split '\s+' | Where-Object { $_ })) {
      if ($tok -match '^(\d+)-(\d+)$') { $from = [int]$Matches[1]; $to = [int]$Matches[2] }
      elseif ($tok -match '^\d+$') { $from = [int]$tok; $to = $from }
      else { Stop-WithError ("<Ports board=`"{0}`">: use `"{1}`" - expected port numbers or ranges like 1 3 5-8" -f $pat, $tok) }
      if ($from -lt 1 -or $to -gt $MAX_PORTS -or $to -lt $from) { Stop-WithError ("<Ports board=`"{0}`">: {1} is not within 1..{2}" -f $pat, $tok, $MAX_PORTS) }
      foreach ($n in ($from..$to)) {
        if ($nums -contains $n) { Stop-WithError ("<Ports board=`"{0}`">: port {1} is listed twice" -f $pat, $n) }
        $nums += $n
      }
    }
    if ($mx -and @($nums | Where-Object { $_ -gt [int]$mx }).Count -gt 0) { Stop-WithError ("<Ports board=`"{0}`">: use lists a port above max {1}" -f $pat, $mx) }
    $m.PortSets.Add(@{ Board = $pat; Use = @($nums | Sort-Object); All = (-not $use); ExcludeRelayPins = ($xr -eq "true"); Max = $(if ($mx) { [int]$mx } else { 0 }); Hits = 0 })
  }

  # number = part of the ETS parameter ID: fixed in the manifest, so reordering roles moves nothing
  $usedNumbers = @{}
  foreach ($r in $root.SelectNodes("GpioRole")) {
    $role = @{ Name = $r.name; Text = $r.text; Count = [int]"$($r.count)"; Number = [int]"$($r.number)"; Sources = @() }
    if ($role.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "GpioRole name must be alphanumeric: $($role.Name)" }
    if ($role.Number -lt 1 -or $role.Number -gt 9) { Stop-WithError "GpioRole $($role.Name): number=`"1..9`" is required (part of the parameter ID, never change it)" }
    if ($usedNumbers.ContainsKey($role.Number)) { Stop-WithError "GpioRole $($role.Name): number $($role.Number) is used twice" }
    if (@($m.Roles | Where-Object { $_.Name -eq $role.Name }).Count -gt 0) { Stop-WithError "GpioRole name $($role.Name) is used twice" }
    $usedNumbers[$role.Number] = $true
    if ($role.Count -lt 1 -or $role.Count -gt 9) { Stop-WithError "GpioRole $($role.Name): count must be 1..9" }
    foreach ($p in $r.SelectNodes("Pins")) {
      $label = "$($p.label)"
      if (-not $label) { $label = '$0' }   # default: the macro name
      $src = @{ Board = $p.board; Scan = $p.scan; Label = $label; Pins = @() }
      foreach ($pin in $p.SelectNodes("Pin")) {
        $pl = "$($pin.label)"
        if (-not $pl) { $pl = "$($pin.gpio)" }   # default: the macro name
        $src.Pins += @{ Gpio = $pin.gpio; Label = $pl }
      }
      $role.Sources += $src
    }
    $m.Roles.Add($role)
  }
  if ($m.Roles.Count -gt 9) { Stop-WithError "At most 9 GPIO roles" }

  # <Page text icon help title label intro queryTitle query button queryHelp queryImage unselectedTitle infoDefault unselectedInfo
  # unselectedText updateInfo features dev/>: the hardware page as an OpenKNX page (the OAM includes ParameterBlock Profile into a
  # channel of its choice): page text and icon (assets/icons/<icon>.png is copied next to the share as Baggages/Icons/<icon>.png),
  # the page texts (an attribute that is absent takes the default below, an empty one leaves the text out; &#10; = line break;
  # {page} = page text, {button} = button text): title = headline, label = text of the selection, intro under the headline;
  # queryTitle, query, the query button, queryHelp, queryImage and the unselected* / updateInfo texts only while no board is
  # selected; unselectedTitle = page text in the tree while no board is selected (empty = always the page text); infoDefault =
  # board text of boards without HW_INFO_TEXT. features = capability and value names of the developer view section "Module und
  # Funktionen"; dev = file of the developer view module (own op:define, only in the OAM's development product); help =
  # HelpContext of the page (the OAM ships Help_<lang>/<help>.md)
  $m.Page = $null
  $pg = $root.SelectSingleNode("Page")
  if ($pg) {
    $pageText = {
      param([string]$Attr, [string]$Default)
      # a literal line break in an attribute is a space (XML attribute normalization), &#10; stays a line break
      if ($pg.HasAttribute($Attr)) { return (("$($pg.GetAttribute($Attr))" -replace "`r", '' -replace '[ \t]+', ' ' -replace ' ?\n ?', "`n").Trim()) }
      return [regex]::Unescape($Default)
    }
    foreach ($a in @("more", "summary", "portsText", "portsTextOne")) {
      if ($pg.HasAttribute($a)) { Stop-WithError "<Page>: attribute $a is no longer used (the device card shows name and board text) - remove it" }
    }
    $introDefault = 'Diese Applikation gilt f\u00FCr mehrere Ger\u00E4te. W\u00E4hlen Sie das Ger\u00E4t aus, das verbaut ist. Erst dann sind seine Anschl\u00FCsse und Einstellungen sichtbar.'
    if ($m.Unselected -eq "showAll") { $introDefault = 'Diese Applikation gilt f\u00FCr mehrere Ger\u00E4te. W\u00E4hlen Sie das Ger\u00E4t aus, das verbaut ist. Danach sind nur seine Anschl\u00FCsse und Einstellungen sichtbar.' }
    $m.Page = @{ Text = "$($pg.text)"; Icon = "$($pg.icon)"; Help = "$($pg.help)"; Features = @("$($pg.features)" -split '\s+' | Where-Object { $_ }); Dev = $null; IconFile = $null
      Title           = (& $pageText "title" 'Ger\u00E4t ausw\u00E4hlen')
      Label           = (& $pageText "label" 'Ger\u00E4tetyp')
      Intro           = (& $pageText "intro" $introDefault)
      QueryTitle      = (& $pageText "queryTitle" 'Oder automatisch erkennen')
      Query           = (& $pageText "query" '')
      Button          = (& $pageText "button" 'Vom Ger\u00E4t lesen')
      QueryHelp       = (& $pageText "queryHelp" '\u201E{button}\u201C ist grau/inaktiv?\n1. Physikalische Adresse programmieren (wenn n\u00F6tig: Programmiertaste dr\u00FCcken).\n2. Links eine andere Seite anklicken, dann zur\u00FCck auf diese Seite.\n3. Button klicken: Ger\u00E4tetyp wird ausgelesen und eingestellt.')
      UnselectedTitle = (& $pageText "unselectedTitle" '{page} (nicht gew\u00E4hlt)')
      InfoDefault     = (& $pageText "infoDefault" 'Die Einstellungen dieser Applikation sind auf dieses Ger\u00E4t abgestimmt.')
      UnselectedInfo  = (& $pageText "unselectedInfo" '')
      UnselectedText  = (& $pageText "unselectedText" '')
      UpdateInfo      = (& $pageText "updateInfo" '')
      ChangeInfo      = (& $pageText "changeInfo" '')
      Firmware        = (& $pageText "firmware" '')
      ImageFile       = $null
    }
    if (-not $m.Page.Text) { $m.Page.Text = $m.Text }
    # with unselectedTitle the tree text is "{{0:<text>}}", 6 characters more
    $textMax = 255; if ($m.Page.UnselectedTitle) { $textMax = 249 }
    if ($m.Page.Text.Length -gt $textMax) { Stop-WithError ("<Page>: text has {0} characters, at most {1} (ETS shows 255; unselectedTitle adds {{{{0:...}}}})" -f $m.Page.Text.Length, $textMax) }
    # one-line texts (tree, headlines, selection, button): a line break there is an error, not a layout
    foreach ($k in @("Text", "Title", "Label", "QueryTitle", "Button", "UnselectedTitle")) {
      if ($m.Page[$k] -match "[`r`n]") { Stop-WithError ("<Page>: {0} must be one line (no &#10;)" -f ($k.Substring(0, 1).ToLower() + $k.Substring(1))) }
    }
    if (-not $m.Page.Button) { Stop-WithError "<Page>: button must not be empty (text of the query button)" }
    if (-not $m.Page.Label) { Stop-WithError "<Page>: label must not be empty (text of the selection)" }
    foreach ($k in @("Title", "Label", "Intro", "QueryTitle", "Query", "Button", "QueryHelp", "UnselectedTitle", "InfoDefault", "UnselectedInfo", "UnselectedText", "UpdateInfo", "ChangeInfo")) {
      $m.Page[$k] = $m.Page[$k].Replace("{button}", $m.Page.Button).Replace("{page}", $m.Page.Text)
      if ($k -eq "QueryHelp") { continue }
      if ($m.Page[$k].Length -gt 255) { Stop-WithError ("<Page>: {0} has {1} characters, ETS shows at most 255" -f ($k.Substring(0, 1).ToLower() + $k.Substring(1)), $m.Page[$k].Length) }
    }
    # queryHelp: one information box per part of at most 255 characters, split at line breaks (ETS: 255 characters per text)
    $m.Page.QueryHelpParts = @()
    $cur = ""
    foreach ($line in ($m.Page.QueryHelp -split "`n")) {
      if ($line.Length -gt 255) { Stop-WithError ("<Page>: a line of queryHelp has {0} characters, ETS shows at most 255: {1}" -f $line.Length, $line) }
      if ($cur -and ($cur.Length + 1 + $line.Length) -gt 255) { $m.Page.QueryHelpParts += $cur; $cur = "" }
      if ($cur) { $cur = $cur + "`n" + $line } else { $cur = $line }
    }
    if ($cur) { $m.Page.QueryHelpParts += $cur }
    # queryImage: picture under queryHelp (one-column grid); absent = the generator's steps picture, empty = none
    $imgAttr = [System.IO.Path]::Combine($script:GeneratorDir, "assets", "query-steps.png")
    if ($pg.HasAttribute("queryImage")) { $imgAttr = "$($pg.queryImage)"; if ($imgAttr) { $imgAttr = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $imgAttr)) } }
    if ($imgAttr) {
      if (-not (Test-Path -LiteralPath $imgAttr -PathType Leaf)) { Stop-WithError ("<Page>: queryImage file not found: {0}" -f $imgAttr) }
      $m.Page.ImageFile = $imgAttr
    }
    if (-not $m.Page.Icon) { $m.Page.Icon = "cog-outline" }
    if ($m.Page.Icon -notmatch '^[a-z0-9][a-z0-9-]*$') { Stop-WithError "<Page>: icon must be an icon name (a-z, 0-9, -)" }
    if ($m.Page.Help -and $m.Page.Help -notmatch '^[A-Za-z0-9_-]+$') { Stop-WithError "<Page>: help must be a help context name (A-Z, a-z, 0-9, _, -)" }
    $own = [System.IO.Path]::Combine($script:GeneratorDir, "assets", "icons", $m.Page.Icon + ".png")
    if (Test-Path -LiteralPath $own) { $m.Page.IconFile = $own }
    if ("$($pg.dev)") { $m.Page.Dev = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, "$($pg.dev)")) }
    if (-not $m.Outputs.ContainsKey("share")) { Stop-WithError "<Page> needs <Output share=...>" }
    foreach ($f in $m.Page.Features) {
      if ($f -eq "Ports") { Stop-WithError "<Page features>: Ports has its own section in the developer view - remove it from the list" }
      if (-not $capIndex.ContainsKey($f) -and -not $valIndex.ContainsKey($f)) { Stop-WithError "<Page features>: $f is neither a capability nor a value" }
    }
  }
  # <Notice when="Capability" title="...">text</Notice>: information on the page for boards with that capability; <Text>
  # children are the parts, else the text is split at sentence ends (ETS limits a text to 255 characters)
  $m.Notices = @()
  foreach ($nt in $root.SelectNodes("Notice")) {
    $nn = @{ When = "$($nt.when)"; Title = ("$($nt.title)" -replace '\s+', ' ').Trim(); Parts = @() }
    if (-not $nn.When -or -not $nn.Title) { Stop-WithError "<Notice> needs when=... and title=..." }
    if (-not $capIndex.ContainsKey($nn.When)) { Stop-WithError "<Notice when=`"$($nn.When)`">: unknown capability" }
    if ($nn.Title.Length -gt 255) { Stop-WithError "<Notice when=`"$($nn.When)`">: title is longer than 255 characters (ETS limit)" }
    $tn = @($nt.SelectNodes("Text"))
    if ($tn.Count -gt 0) { $nn.Parts = @($tn | ForEach-Object { ("$($_.InnerText)" -replace '\s+', ' ').Trim() } | Where-Object { $_ }) }
    else {
      # the function returns its array as one object: assign it directly (@() would nest it into one part)
      try { $nn.Parts = [string[]](Split-SentenceText (("$($nt.InnerText)" -replace '\s+', ' ').Trim()) 255) }
      catch { Stop-WithError ("<Notice when=`"{0}`">: {1}" -f $nn.When, $_.Exception.Message) }
    }
    foreach ($part in $nn.Parts) {
      if ($part.Length -gt 255) { Stop-WithError ("<Notice when=`"{0}`">: a <Text> has {1} characters, ETS shows at most 255" -f $nn.When, $part.Length) }
    }
    $m.Notices += $nn
  }

  # <InfoImage define="HW_INFO_URL" default="" module="2" version="3" width="150" urlFont="NotoSans-Regular-44" supersample="4"
  #   urlColor="#0067C0" logo="..." badge="..." thirdPartyWhen="ThirdParty"/>: device card on the <Page> (ETS elements, no text in
  #   pictures except the link): OpenKNX logo, or the third-party badge on boards with capability thirdPartyWhen; DEVICE_NAME as
  #   headline; board text (HW_INFO_TEXT, else <Page infoDefault>); with an info URL (define in the board header, else default;
  #   empty default = no QR code) a grid: board text | picture "QR code + link" (width px, QR v<version> EC M,
  #   <module> px per module, white quiet zone, link without scheme in one line, glyph atlas urlFont = supersample x the size).
  #   logo / badge: PNG paths relative to the manifest (default: generator assets card-badge.png / third-party-badge.png)
  $m.Info = $null
  $ii = $root.SelectSingleNode("InfoImage")
  if ($ii) {
    if (-not $m.Page) { Stop-WithError "<InfoImage> needs <Page> (the device card is part of the hardware page)" }
    if (-not $m.Outputs.ContainsKey("share")) { Stop-WithError "<InfoImage> needs <Output share=...> (the images are baggages of the ETS module)" }
    $allowed = @("define", "default", "style", "module", "version", "width", "urlFont", "supersample", "urlColor", "logo", "badge", "thirdPartyWhen")
    foreach ($at in $ii.Attributes) {
      if ($allowed -cnotcontains $at.Name) { Stop-WithError ("<InfoImage>: attribute {0} is not supported (allowed: {1})" -f $at.Name, ($allowed -join ", ")) }
    }
    if ($ii.HasAttribute("style") -and "$($ii.style)" -ne "card") { Stop-WithError "<InfoImage>: style must be card (or absent)" }
    $assets = [System.IO.Path]::Combine($script:GeneratorDir, "assets")
    $m.Info = @{ Define = "$($ii.define)"; Default = "$($ii.default)"; Module = 2; Version = 3; Width = 150; UrlFont = "NotoSans-Regular-44"; Supersample = 4
      UrlRgb = [byte[]](0x00, 0x67, 0xC0); Logo = [System.IO.Path]::Combine($assets, "card-badge.png"); Badge = [System.IO.Path]::Combine($assets, "third-party-badge.png")
      ThirdWhen = "ThirdParty" }
    if (-not $m.Info.Define) { $m.Info.Define = "HW_INFO_URL" }
    if ($m.Info.Define -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { Stop-WithError "<InfoImage>: define must be a macro name" }
    foreach ($a in @(@("module", "Module", 1, 10), @("version", "Version", 1, 40), @("width", "Width", 40, 400), @("supersample", "Supersample", 1, 8))) {
      if (-not $ii.HasAttribute($a[0])) { continue }
      $v = ConvertFrom-CInteger "$($ii.GetAttribute($a[0]))"
      if ($null -eq $v -or $v -lt $a[2] -or $v -gt $a[3]) { Stop-WithError ("<InfoImage>: {0} must be {1}..{2}" -f $a[0], $a[2], $a[3]) }
      $m.Info[$a[1]] = [int]$v
    }
    if ($ii.HasAttribute("urlFont")) { $m.Info.UrlFont = "$($ii.urlFont)" }
    if ($m.Info.UrlFont -notmatch '^[A-Za-z0-9.-]+$') { Stop-WithError "<InfoImage>: urlFont must be an atlas name of assets/fonts" }
    if ($ii.HasAttribute("urlColor")) {
      $hex = "$($ii.urlColor)"
      if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') { Stop-WithError "<InfoImage>: urlColor must be #RRGGBB" }
      $m.Info.UrlRgb = [byte[]]([Convert]::ToByte($hex.Substring(1, 2), 16), [Convert]::ToByte($hex.Substring(3, 2), 16), [Convert]::ToByte($hex.Substring(5, 2), 16))
    }
    # logo / badge: picture of the OpenKNX / third-party boards; an empty attribute = no picture
    foreach ($a in @(@("logo", "Logo"), @("badge", "Badge"))) {
      if ($ii.HasAttribute($a[0])) {
        $f = "$($ii.GetAttribute($a[0]))"
        if ($f) { $m.Info[$a[1]] = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $f)) } else { $m.Info[$a[1]] = "" }
      }
      if ($m.Info[$a[1]] -and -not (Test-Path -LiteralPath $m.Info[$a[1]] -PathType Leaf)) { Stop-WithError ("<InfoImage>: {0} file not found: {1}" -f $a[0], $m.Info[$a[1]]) }
    }
    # <Logo board="pattern" file="path"/>: picture of the matching boards instead of logo / badge, file="" = none; a define
    # without * or ? wins over a pattern, two matching entries of the same kind stop the run
    $m.Info.Logos = @()
    foreach ($lg in $ii.SelectNodes("Logo")) {
      if (-not "$($lg.board)" -or -not $lg.HasAttribute("file")) { Stop-WithError "<InfoImage><Logo> needs board=... and file=... (empty file = no picture)" }
      $f = "$($lg.file)"
      if ($f) {
        $f = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $f))
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { Stop-WithError ("<InfoImage><Logo board=`"{0}`">: file not found: {1}" -f $lg.board, $f) }
      }
      $m.Info.Logos += @{ Board = "$($lg.board)"; File = $f; Pattern = ("$($lg.board)" -match '[\*\?]') }
    }
    if ($ii.HasAttribute("thirdPartyWhen")) {
      $m.Info.ThirdWhen = "$($ii.thirdPartyWhen)"
      if ($m.Info.ThirdWhen -and -not $capIndex.ContainsKey($m.Info.ThirdWhen)) { Stop-WithError "<InfoImage>: thirdPartyWhen names an unknown capability $($m.Info.ThirdWhen)" }
    }
    elseif (-not $capIndex.ContainsKey($m.Info.ThirdWhen)) { $m.Info.ThirdWhen = "" }
  }
  # <Conflicts>: optional GPIO conflict check (one ParameterCalculation); absent = no output changes
  $m.Conflicts = $null
  $cfNodes = @($root.SelectNodes("Conflicts"))
  if ($cfNodes.Count -gt 1) { Stop-WithError "<Conflicts> may appear only once" }
  if ($cfNodes.Count -eq 1) { $m.Conflicts = Read-ConflictsNode $m $cfNodes[0] $baseDir }
  # <Fixes output><Fix name capability ref value show indent help/></Fixes>: a setting of another module (ParameterRef) set to a
  # value on boards with the capability and shown read-only, hidden or editable there; absent = no output changes
  $m.Fixes = $null
  $fxNodes = @($root.SelectNodes("Fixes"))
  if ($fxNodes.Count -gt 1) { Stop-WithError "<Fixes> may appear only once" }
  if ($fxNodes.Count -eq 1) {
    $fxOut = "$($fxNodes[0].GetAttribute('output'))"
    if (-not $fxOut) { Stop-WithError "<Fixes> needs output=... (the parts file the application includes)" }
    if (-not $m.Outputs.ContainsKey("share")) { Stop-WithError "<Fixes> needs <Output share=...> (the hardware selection)" }
    $m.Fixes = @{ Output = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $fxOut)); Items = @() }
    $fxNames = @{}
    foreach ($f in $fxNodes[0].SelectNodes("Fix")) {
      $fn = "$($f.GetAttribute('name'))"
      if ($fn -cnotmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("<Fix name=`"{0}`">: name must be letters and digits (it names the block Fix_<name>)" -f $fn) }
      if ($fxNames.ContainsKey($fn)) { Stop-WithError "<Fix name=`"$fn`"> is listed twice" }
      $fxNames[$fn] = $true
      $fc = "$($f.GetAttribute('capability'))"
      if (@($m.Capabilities | Where-Object { $_.Name -ceq $fc }).Count -eq 0) { Stop-WithError ("<Fix name=`"{0}`">: capability {1} is not defined (names are case-sensitive)" -f $fn, $fc) }
      $fr = "$($f.GetAttribute('ref'))"
      if ($fr -notmatch '^%AID%_(UP|P)-(\d{2})(\d{5})_R-(\d{2})(\d{5})(\d{2})$' -or $Matches[2] -ne $Matches[4] -or $Matches[3] -ne $Matches[5]) {
        Stop-WithError ("<Fix name=`"{0}`">: ref must be a ParameterRef id like %AID%_P-1401001_R-140100100 (module digits instead of %TT%), got {1}" -f $fn, $fr)
      }
      if ($Matches[6] -eq "99") { Stop-WithError ("<Fix name=`"{0}`">: ref index 99 is used for the read-only row - take the ParameterRef of the setting" -f $fn) }
      if (@($m.Fixes.Items | Where-Object { $_.Ref -ceq $fr }).Count -gt 0) { Stop-WithError ("<Fix name=`"{0}`">: ref {1} is already fixed by another <Fix>" -f $fn, $fr) }
      $fParam = "%AID%_{0}-{1}{2}" -f $Matches[1], $Matches[2], $Matches[3]
      $fRo = "{0}_R-{1}{2}99" -f $fParam, $Matches[2], $Matches[3]
      $fv = "$($f.GetAttribute('value'))"
      if ($fv -eq "") { Stop-WithError ("<Fix name=`"{0}`">: value is missing" -f $fn) }
      $fs = "$($f.GetAttribute('show'))"; if (-not $fs) { $fs = "readonly" }
      if (@("readonly", "hidden", "editable") -cnotcontains $fs) { Stop-WithError ("<Fix name=`"{0}`">: show must be readonly, hidden or editable" -f $fn) }
      $fi = "$($f.GetAttribute('indent'))"
      if ($fi -and ($fi -notmatch '^\d{1,2}$')) { Stop-WithError ("<Fix name=`"{0}`">: indent must be a number" -f $fn) }
      $fh = "$($f.GetAttribute('help'))"
      if ($fh -and $fh -notmatch '^[A-Za-z0-9_-]+$') { Stop-WithError ("<Fix name=`"{0}`">: help must be a help context name" -f $fn) }
      $m.Fixes.Items += @{ Name = $fn; Capability = $fc; Ref = $fr; Param = $fParam; ReadOnlyRef = $fRo; Value = $fv; Show = $fs; Indent = $fi; Help = $fh }
    }
    if ($m.Fixes.Items.Count -eq 0) { Stop-WithError "<Fixes> without <Fix>" }
  }
  # <BoardTable name header scan>: integer macros of an OAM header per board (index = group 1 of scan); absent = no output changes
  $m.BoardTables = @()
  foreach ($bt in $root.SelectNodes("BoardTable")) {
    foreach ($at in $bt.Attributes) {
      if (@("name", "header", "scan") -cnotcontains $at.Name) { Stop-WithError ("<BoardTable>: attribute {0} is not supported (allowed: name, header, scan)" -f $at.Name) }
    }
    $t = @{ Name = "$($bt.name)"; HeaderAttr = "$($bt.header)"; Scan = "$($bt.scan)"; Found = $false }
    if ($t.Name -notmatch '^[A-Za-z0-9]+$') { Stop-WithError ("<BoardTable name=`"{0}`">: name must be letters and digits" -f $t.Name) }
    if (@($m.BoardTables | Where-Object { $_.Name -eq $t.Name }).Count -gt 0) { Stop-WithError ("<BoardTable name=`"{0}`">: name used twice" -f $t.Name) }
    if (-not $t.HeaderAttr) { Stop-WithError ("<BoardTable name=`"{0}`">: header=... is missing" -f $t.Name) }
    $t.Header = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $t.HeaderAttr))
    if (-not (Test-Path -LiteralPath $t.Header -PathType Leaf)) { Stop-WithError ("<BoardTable name=`"{0}`">: header not found: {1}" -f $t.Name, $t.Header) }
    try { $rx = New-Object System.Text.RegularExpressions.Regex($t.Scan) }
    catch { Stop-WithError ("<BoardTable name=`"{0}`">: scan is no regular expression: {1}" -f $t.Name, $t.Scan) }
    # exactly one numbered group: a named group (?<i>...) is not read as group 1
    $named = @($rx.GetGroupNames() | Where-Object { $_ -notmatch '^\d+$' })
    if (-not $t.Scan -or $rx.GetGroupNumbers().Count -ne 2 -or $named.Count -gt 0) { Stop-WithError ("<BoardTable name=`"{0}`">: scan needs exactly one unnamed group (the index), e.g. ^NAME_(\d+)`$: {1}" -f $t.Name, $t.Scan) }
    $m.BoardTables += $t
  }
  if ($m.BoardTables.Count -gt 0 -and -not $m.Outputs.ContainsKey("script")) { Stop-WithError "<BoardTable> needs <Output script=...> (the table is part of the ETS script)" }
  return $m
}
# @brief Integer attribute of a <Conflicts>/<Use> element: $null when absent, stop when not a number in Min..Max
function Get-ConflictInt($Node, [string]$Attr, [int]$Min, [int]$Max, [string]$Where) {
  if (-not $Node.HasAttribute($Attr)) { return $null }
  $t = "$($Node.GetAttribute($Attr))".Trim()
  if ($t -notmatch '^\d+$' -or [int64]$t -lt $Min -or [int64]$t -gt $Max) { Stop-WithError ("{0}: {1} must be a number {2}..{3}" -f $Where, $Attr, $Min, $Max) }
  return [int]$t
}
# @brief Condition text -> list of OR groups, each a list of AND terms @{ Param; Op; Values }
#        Syntax: "<Param> <op> <n>" with op == != < <= > >=, or "<Param> in <n> <n> ..."; terms joined by "and" / "or"
#        ("and" binds tighter, no parentheses); and / or / in are lower case, numbers are 32-bit integers
function ConvertFrom-ConflictCondition([string]$Text, [hashtable]$Params, [string]$Where) {
  $t = ($Text -replace '\s+', ' ').Trim()
  if (-not $t) { Stop-WithError ("{0}: empty condition" -f $Where) }
  $ops = @{ "==" = "eq"; "!=" = "ne"; "<" = "lt"; "<=" = "le"; ">" = "gt"; ">=" = "ge" }
  $groups = @()
  foreach ($g in ($t -csplit ' or ')) {
    $terms = @()
    foreach ($term in ($g -csplit ' and ')) {
      $term = $term.Trim()
      $tm = $null; $nums = @()
      if ($term -cmatch '^([A-Za-z][A-Za-z0-9]*) ?(==|!=|<=|>=|<|>) ?(-?\d+)$') { $tm = @{ Param = $Matches[1]; Op = $ops[$Matches[2]] }; $nums = @($Matches[3]) }
      elseif ($term -cmatch '^([A-Za-z][A-Za-z0-9]*) in ((-?\d+)( -?\d+)*)$') { $tm = @{ Param = $Matches[1]; Op = "in" }; $nums = @($Matches[2].Split(' ')) }
      if ($tm) {
        $vals = @()
        foreach ($nt in $nums) {
          $iv = 0
          if (-not [int]::TryParse($nt, [ref]$iv)) { Stop-WithError ("{0}: condition '{1}' - {2} is not a 32-bit integer" -f $Where, $term, $nt) }
          $vals += $iv
        }
        $tm.Values = $vals
      }
      else { Stop-WithError ("{0}: condition '{1}' - expected '<Param> <op> <number>' (op == != < <= > >=, in XML &lt; for <) or '<Param> in <number> ...', joined by and / or" -f $Where, $term) }
      if (-not $Params.ContainsKey($tm.Param)) { Stop-WithError ("{0}: condition names {1}, which is no <Param name> of <Conflicts>" -f $Where, $tm.Param) }
      $terms += , $tm
    }
    $groups += , $terms
  }
  return , $groups
}
# @brief Reads <Conflicts output number value manual none error><Param name ref/><Use name text when port value manual none
#        wiredRelay error><Manual ref when/></Use></Conflicts>; board-dependent checks follow in Resolve-Conflicts
function Read-ConflictsNode($M, $Node, [string]$BaseDir) {
  $w = "<Conflicts>"
  $allowed = @("output", "number", "value", "error", "reserved", "reservedError", "tpError")
  foreach ($at in $Node.Attributes) { if ($allowed -cnotcontains $at.Name) { Stop-WithError ("{0}: attribute {1} is not supported (allowed: {2})" -f $w, $at.Name, ($allowed -join ", ")) } }
  if (-not $M.Outputs.ContainsKey("share") -or -not $M.Outputs.ContainsKey("script")) { Stop-WithError "<Conflicts> needs <Output share=... script=...> (the check function is part of the generated script)" }
  $out = "$($Node.GetAttribute('output'))"
  if (-not $out) { Stop-WithError "<Conflicts> needs output=... (file with the parts the application includes)" }
  $num = Get-ConflictInt $Node "number" 1 99999 $w
  if ($null -eq $num) { Stop-WithError "<Conflicts> needs number=... (first parameter number of the conflict flags in the including module, also the calculation number)" }
  $cf = @{ Output = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BaseDir, $out)); Number = $num; Params = New-Object System.Collections.Generic.List[object]; Uses = New-Object System.Collections.Generic.List[object] }
  $cf.Value = "$($Node.GetAttribute('value'))"; if (-not $cf.Value) { $cf.Value = "port" }
  if ($cf.Value -ne "port" -and $cf.Value -ne "gpio") { Stop-WithError "<Conflicts>: value must be port or gpio" }
  $cf.Error = "$($Node.GetAttribute('error'))"
  if (-not $cf.Error) { $cf.Error = "GPIO-Konflikt: {text} nutzt denselben GPIO wie ein anderer Anschluss, ein fest verdrahtetes Relais oder ein manueller GPIO." }
  # reserved="true": a use on a GPIO the selected board uses itself gets flag 2 (reservedError); on a KNX UART pin of a board
  # that has TP and IP firmware variants flag 3 (tpError, Information)
  $rv = $Node.GetAttribute("reserved")
  if ($rv -and $rv -ne "true" -and $rv -ne "false") { Stop-WithError "<Conflicts>: reserved must be true or false" }
  $cf.Reserved = ($rv -eq "true")
  $cf.ReservedError = $Node.GetAttribute("reservedError")
  $cf.TpError = $Node.GetAttribute("tpError")
  if (($cf.ReservedError -or $cf.TpError) -and -not $cf.Reserved) { Stop-WithError "<Conflicts>: reservedError / tpError need reserved=`"true`"" }
  if (-not $cf.ReservedError) { $cf.ReservedError = [regex]::Unescape('GPIO-Konflikt: {text} nutzt einen GPIO, den die gew\u00E4hlte Hardware selbst belegt (KNX, Taster, LED, Flash-Speicher oder Ethernet).') }
  if (-not $cf.TpError) { $cf.TpError = [regex]::Unescape('Hinweis: {text} nutzt den GPIO der KNX-TP-Schnittstelle dieser Hardware. Eine TP-Firmware lehnt ihn ab, mit einer IP-Firmware ist er frei.') }
  $params = @{}
  foreach ($pn in $Node.SelectNodes("Param")) {
    $pName = $pn.GetAttribute("name"); $pRef = $pn.GetAttribute("ref")
    $pw = "<Conflicts><Param name=`"$pName`">"
    if ($pName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $pw) }
    # calculation alias P_<name>: ETS allows 50 characters (String50_t)
    if ($pName.Length -gt 48) { Stop-WithError ("{0}: name has {1} characters, at most 48 (alias P_<name>, ETS limit 50)" -f $pw, $pName.Length) }
    if ($params.ContainsKey($pName)) { Stop-WithError ("{0}: name is used twice" -f $pw) }
    if (-not $pRef -or $pRef.Contains("{{")) { Stop-WithError ("{0}: needs ref=... (a ParamRefId, no board expression)" -f $pw) }
    foreach ($q in $cf.Params) { if ($q.Ref -ceq $pRef) { Stop-WithError ("{0}: ref is also <Param name=`"{1}`">" -f $pw, $q.Name) } }
    $params[$pName] = $true
    $cf.Params.Add(@{ Name = $pName; Ref = $pRef })
  }
  $useNames = @{}
  foreach ($un in $Node.SelectNodes("Use")) {
    $uName = $un.GetAttribute("name")
    $uw = "<Conflicts><Use name=`"$uName`">"
    $uAllowed = @("name", "text", "when", "port", "value", "wiredRelay", "error")
    foreach ($at in $un.Attributes) { if ($uAllowed -cnotcontains $at.Name) { Stop-WithError ("{0}: attribute {1} is not supported (allowed: {2})" -f $uw, $at.Name, ($uAllowed -join ", ")) } }
    if ($uName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $uw) }
    # output alias F_<name>: ETS allows 50 characters (String50_t)
    if ($uName.Length -gt 48) { Stop-WithError ("{0}: name has {1} characters, at most 48 (alias F_<name>, ETS limit 50)" -f $uw, $uName.Length) }
    if ($useNames.ContainsKey($uName)) { Stop-WithError ("{0}: name is used twice" -f $uw) }
    $useNames[$uName] = $true
    $u = @{ Name = $uName; Text = ($un.GetAttribute("text") -replace '\s+', ' ').Trim(); Port = $un.GetAttribute("port"); When = $null; Manuals = @(); Index = $cf.Uses.Count }
    if (-not $u.Text) { $u.Text = $uName }
    $u.Value = "$($un.GetAttribute('value'))"; if (-not $u.Value) { $u.Value = $cf.Value }
    if ($u.Value -ne "port" -and $u.Value -ne "gpio") { Stop-WithError ("{0}: value must be port or gpio" -f $uw) }
    # manual / none: the port value encoding of the root (portManualValue / portNoneValue); a GPIO value has none (10 is GPIO 10)
    $u.Manual = $null; $u.None = $null
    if ($u.Value -eq "port") { $u.Manual = $M.PortManual; $u.None = $M.PortNone }
    $u.Wired = Get-ConflictInt $un "wiredRelay" 1 $MAX_RELAYS $uw; if ($null -eq $u.Wired) { $u.Wired = 0 }
    if (-not $u.Port -and $u.Wired -eq 0) { Stop-WithError ("{0}: needs port=... (selection parameter) or wiredRelay=... (hard-wired relay)" -f $uw) }
    if ($un.HasAttribute("when")) {
      if (-not $u.Port) { Stop-WithError ("{0}: when=... needs port=... (a hard-wired relay pin is always occupied)" -f $uw) }
      $u.When = ConvertFrom-ConflictCondition $un.GetAttribute("when") $params $uw
    }
    $u.Error = "$($un.GetAttribute('error'))"; if (-not $u.Error) { $u.Error = $cf.Error }
    $u.ErrorText = $u.Error.Replace("{text}", $u.Text)
    if ($u.ErrorText.Length -gt 255) { Stop-WithError ("{0}: the error text has {1} characters, ETS shows at most 255" -f $uw, $u.ErrorText.Length) }
    $u.ReservedText = $cf.ReservedError.Replace("{text}", $u.Text)
    $u.TpText = $cf.TpError.Replace("{text}", $u.Text)
    if ($cf.Reserved -and $u.ReservedText.Length -gt 255) { Stop-WithError ("{0}: the reservedError text has {1} characters, ETS shows at most 255" -f $uw, $u.ReservedText.Length) }
    if ($cf.Reserved -and $u.TpText.Length -gt 255) { Stop-WithError ("{0}: the tpError text has {1} characters, ETS shows at most 255" -f $uw, $u.TpText.Length) }
    $defaultSeen = $false
    foreach ($mn in $un.SelectNodes("Manual")) {
      $mw = "$uw <Manual>"
      if ($defaultSeen) { Stop-WithError ("{0}: follows a <Manual> without when=... and is never used" -f $mw) }
      $mRef = $mn.GetAttribute("ref")
      if (-not $mRef -or $mRef.Contains("{{")) { Stop-WithError ("{0}: needs ref=... (ParamRefId of the manual GPIO, no board expression)" -f $mw) }
      $mWhen = $null
      if ($mn.HasAttribute("when")) { $mWhen = ConvertFrom-ConflictCondition $mn.GetAttribute("when") $params $mw } else { $defaultSeen = $true }
      $u.Manuals += , @{ Ref = $mRef; When = $mWhen }
    }
    if ($u.Manuals.Count -gt 0 -and $u.Value -ne "port") { Stop-WithError ("{0}: <Manual> needs value=`"port`" (a GPIO value has no manual entry)" -f $uw) }
    if ($u.Manuals.Count -gt 0 -and $null -eq $u.Manual) { Stop-WithError ("{0}: <Manual> needs portManualValue=... on <HardwareProfile> (the port value of the manual GPIO)" -f $uw) }
    if (-not $u.Port -and ($u.Manuals.Count -gt 0)) { Stop-WithError ("{0}: <Manual> needs port=..." -f $uw) }
    $cf.Uses.Add($u)
  }
  if ($cf.Uses.Count -lt 2) { Stop-WithError "<Conflicts> needs at least two <Use> entries" }
  # <ChannelBlock name text uses>: one UI block for a channel template of the OpenKNXproducer (%C% = channel 1..9): the n-th
  # use of "uses" is channel n; its flag number ends in n, so the block names the flag of its channel through %C%
  # (the producer substitutes %C% in the included content, not in an op:include xpath)
  $cf.Channels = New-Object System.Collections.Generic.List[object]
  foreach ($cn in $Node.SelectNodes("ChannelBlock")) {
    $cName = $cn.GetAttribute("name")
    $cw = "<Conflicts><ChannelBlock name=`"$cName`">"
    if ($cName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $cw) }
    if (@($cf.Channels | Where-Object { $_.Name -eq $cName }).Count -gt 0) { Stop-WithError ("{0}: name is used twice" -f $cw) }
    $cText = ($cn.GetAttribute("text") -replace '\s+', ' ').Trim()
    if (-not $cText) { Stop-WithError ("{0}: needs text=... (e.g. with %C%)" -f $cw) }
    $names = @($cn.GetAttribute("uses") -split '\s+' | Where-Object { $_ })
    if ($names.Count -lt 1 -or $names.Count -gt 9) { Stop-WithError ("{0}: uses must name 1..9 <Use> entries (channel 1..9, %C% is one digit)" -f $cw) }
    $ch = @{ Name = $cName; Text = $cText; Index = $cf.Channels.Count + 1; Uses = @() }
    for ($n = 0; $n -lt $names.Count; $n++) {
      $hit = @($cf.Uses | Where-Object { $_.Name -eq $names[$n] })
      if ($hit.Count -eq 0) { Stop-WithError ("{0}: {1} is no <Use name>" -f $cw, $names[$n]) }
      if ($hit[0].ContainsKey("Channel")) { Stop-WithError ("{0}: {1} is already channel {2} of {3}" -f $cw, $names[$n], $hit[0].Channel.N, $hit[0].Channel.Block) }
      $hit[0].Channel = @{ Block = $cName; Group = $ch.Index; N = $n + 1 }
      $ch.Uses += $hit[0]
    }
    # one block, one text: the uses of a block share their error template (error=... of <Use>, else of <Conflicts>)
    $templates = @(Get-OrdinalSorted @($ch.Uses | ForEach-Object { $_.Error }) -Unique)
    if ($templates.Count -gt 1) { Stop-WithError ("{0}: its uses have different error=... texts - give them one text (the block shows one message per channel)" -f $cw) }
    $ch.ErrorText = $templates[0].Replace("{text}", $cText)
    if ($ch.ErrorText.Length -gt 255) { Stop-WithError ("{0}: the error text has {1} characters, ETS shows at most 255" -f $cw, $ch.ErrorText.Length) }
    $ch.ReservedText = $cf.ReservedError.Replace("{text}", $cText)
    $ch.TpText = $cf.TpError.Replace("{text}", $cText)
    if ($cf.Reserved -and $ch.ReservedText.Length -gt 255) { Stop-WithError ("{0}: the reservedError text has {1} characters, ETS shows at most 255" -f $cw, $ch.ReservedText.Length) }
    if ($cf.Reserved -and $ch.TpText.Length -gt 255) { Stop-WithError ("{0}: the tpError text has {1} characters, ETS shows at most 255" -f $cw, $ch.TpText.Length) }
    $cf.Channels.Add($ch)
  }
  if ($cf.Channels.Count -gt 0) {
    # flag numbers: uses outside a channel block number + 0..9, channel block k use n number + 10 k + n
    if ($cf.Number % 10 -ne 0) { Stop-WithError ("<Conflicts>: number must be a multiple of 10 with <ChannelBlock> (flag number of channel n ends in n), not {0}" -f $cf.Number) }
    $free = @($cf.Uses | Where-Object { -not $_.ContainsKey("Channel") }).Count
    if ($free -gt 10) { Stop-WithError ("<Conflicts>: with <ChannelBlock> at most 10 <Use> entries outside a channel block (number + 0..9), not {0}" -f $free) }
    if ($cf.Channels.Count -gt 9 -or $cf.Number + 10 * $cf.Channels.Count + 9 -gt 99999) { Stop-WithError "<Conflicts>: at most 9 <ChannelBlock> entries, and number + 10 x blocks + 9 must stay within 99999" }
  }
  if ($cf.Channels.Count -eq 0 -and $cf.Number + $cf.Uses.Count - 1 -gt 99999) { Stop-WithError ("<Conflicts>: number {0} + {1} flags exceeds 99999" -f $cf.Number, $cf.Uses.Count) }
  return $cf
}
