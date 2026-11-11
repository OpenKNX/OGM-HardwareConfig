@@# JavaScript object entries: the GPIO of every port of every board with ports, indexed by the port value
@@# (hardware port number - 1); a port that <Ports use> leaves out is null
@@#   <Indent><Key>: [  // <name>
@@#   <Indent>  <gpio>,
@@#   <Indent>][,]
@@# Params: Indent, Key (template with $b)
@@params
@@default Indent = "  "
@@default Key = '0x{{X4 $b.HwId}}'
@@set $list = Select-TBoards $Boards { $_.Ports.Count -gt 0 }
@@for $b in $list
{{$P.Indent}}{{Expand $P.Key}}: [  // {{$b.Name}}
@@for $n in (Range 1 (MaxOf $b.Ports { $_.N } 0))
@@set $port = @($b.Ports | Where-Object { $_.N -eq $n })
{{$P.Indent}}  {{ if ($port.Count -gt 0) { [string]$port[0].Gpio } else { 'null' } }}{{ if (-not $last) { ',' } }}
@@end
{{$P.Indent}}]{{ if (-not $last) { ',' } }}
@@end
