Param(
  [Parameter(Mandatory)]
  [String]$ZoneFile,

  [Parameter(Mandatory)]
  [String]$ZoneName,

  [Parameter(Mandatory)]
  [String]$TerraformOutputFile
)

$nsRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "NS"
  ttl     = {3}
  name    = "{1}"
  value   = "{4}"
}}


"@

$mxRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "MX"
  ttl     = {3}
  name    = "{1}"
  value = "{5}"
  priority = {4}
}}


"@

$txtRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "TXT"
  ttl     = {3}
  name    = "{1}"
  value   = "{4}"
}}


"@

$aRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "A"
  ttl     = {3}
  name    = "{1}"
  value   = "{4}"
  proxied = false
}}


"@

$aaaaRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "AAAA"
  ttl     = {3}
  name    = "{1}"
  value   = "{4}"
  proxied = false
}}


"@

$srvRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "SRV"
  ttl     = {3}
  name    = "{1}"
  data {{
    priority = {4}
    weight   = {5}
    port     = {6}
    target   = "{7}"
    service  = "{8}"
    proto    = "{9}"
    name     = "{10}"
  }}
}}


"@

$cnameRecordFormat = @"
resource "cloudflare_record" "{0}" {{
  zone_id = {2}
  type    = "CNAME"
  ttl     = {3}
  name    = "{1}"
  value   = "{4}"
  proxied = false
}}


"@

$zoneResourceName = $ZoneName -replace '[^\w]', '_'
$zoneResourceReference = "cloudflare_zone.$($zoneResourceName).id"

$zoneOutputFile = $ZoneFile + "-output.json"
& 'python' "$PSScriptroot/parse_zone_file.py" $ZoneFile $zoneOutputFile $ZoneName

$content = Get-Content $zoneOutputFile -Raw
$groupedRecords = $content | ConvertFrom-Json
$result = @{}

$groupedRecords.PSObject.Properties | ForEach-Object {
  $groupedRecordName = ($_.Name -replace '\.$', '').ToLower()
  $sanitizedName = $groupedRecordName -replace '[^\w]', '_' -replace '^(?<num>\d)', '_$1'
  $groupedRecordNameWithoutZone = $groupedRecordName -replace "$($ZoneName.ToLower())$", ''
  If ($groupedRecordNameWithoutZone -eq '') { $recordSetName = '@' }
  Else { $recordSetName = $groupedRecordNameWithoutZone -replace '\.$', '' }
  $recordSetTypes = $_.Value

  $i = 1
  $result['a'] = ($result['a'], @{})[-not $result['a']]
  $recordSetTypes.a | Where-Object { $_ } | ForEach-Object {
    $resourceName = "a_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $aRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, $_.ip
    $result['a'].Add($resourceName, $resource)
    $i += 1
  }

  $i = 1
  $result['aaaa'] = ($result['aaaa'], @{})[-not $result['aaaa']]
  $recordSetTypes.aaaa | Where-Object { $_ } | ForEach-Object {
    $resourceName = "aaaa_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $aaaaRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, $_.ip
    $result['aaaa'].Add($resourceName, $resource)
    $i += 1
  }

  $i = 1
  $result['cname'] = ($result['cname'], @{})[-not $result['cname']]
  $recordSetTypes.cname | Where-Object { $_ } | ForEach-Object {
    $resourceName = "cname_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $cnameRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, ($_.alias -replace '\.$','')
    $result['cname'].Add($resourceName, $resource)
    $i += 1
  }

  $i = 1
  $result['ns'] = ($result['ns'], @{})[-not $result['ns']]
  $recordSetTypes.ns | Where-Object { $_ } | ForEach-Object {
    If($recordSetName -eq '@') { Return }
    Else { Write-Warning "Zone has non-root NS record types: $recordSetName" }

    $resourceName = "ns_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $nsRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, ($_.host -replace '\.$','')
    $result['ns'].Add($resourceName, $resource)
    $i += 1
  }

  $i = 1
  $result['txt'] = ($result['txt'], @{})[-not $result['txt']]
  $recordSetTypes.txt | Where-Object { $_ } | ForEach-Object {
    $resourceName = "txt_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $txtRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, ($_.txt[0] -replace '\\','\\')
    $result['txt'].Add($resourceName, $resource)
    $i += 1
  }
  
  $i = 1
  $result['mx'] = ($result['mx'], @{})[-not $result['mx']]
  $recordSetTypes.mx | Where-Object { $_ } | ForEach-Object {
    $resourceName = "mx_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $mxRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, $_.preference, ($_.host -replace '\.$','')
    $result['mx'].Add($resourceName, $resource)
    $i += 1
  }
  
  $i = 1
  $result['srv'] = ($result['srv'], @{})[-not $result['srv']]
  $recordSetTypes.srv | Where-Object { $_ } | ForEach-Object {
    $resourceName = "srv_" + $sanitizedName + @("", "_$i")[$i -ne 1]
    $resource = $srvRecordFormat -f $resourceName, $recordSetName, $zoneResourceReference, $_.ttl, $_.priority, $_.weight, $_.port, ($_.target -replace '\.$',''), $_.name, ($recordSetName.Split('.')[1]), $zoneName
    $result['srv'].Add($resourceName, $resource)
    $i += 1
  }
}

$textResult = @"
resource "cloudflare_zone" "$zoneResourceName" {
  zone       = "$zoneName"
  jump_start = false
  plan       = "free"
  type       = "full"
}

###
### A Records ###
###
$($result['a'].Keys | Sort-Object | % { $result['a'][$_] })
###
### AAAA Records ###
###
$($result['aaaa'].Keys | Sort-Object | % { $result['aaaa'][$_] })
###
### CNAME Records ###
###
$($result['cname'].Keys | Sort-Object | % { $result['cname'][$_] })
###
### TXT Records ###
###
$($result['txt'].Keys | Sort-Object | % { $result['txt'][$_] })
###
### NS Records ###
###
$($result['ns'].Keys | Sort-Object | % { $result['ns'][$_] })
###
### MX Records ###
###
$($result['mx'].Keys | Sort-Object | % { $result['mx'][$_] })
###
### SRV Records ###
###
$($result['srv'].Keys | Sort-Object | % { $result['srv'][$_] })
"@

Set-Content -Path $TerraformOutputFile -Value $textResult -NoNewline
Remove-Item -Path $zoneOutputFile