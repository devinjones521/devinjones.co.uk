# Builds index.html from template.html by inlining images/*.jpg as base64 data URIs.
# The published page must be self-contained: GitHub Pages serves it fine either way,
# but inlining keeps it to a single file with no request waterfall.
#
#   powershell -ExecutionPolicy Bypass -File ./build.ps1
#
# Edit template.html. Never edit index.html by hand - this overwrites it.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$map = @{
  '{{IMG_LASTSTAND}}'  = 'laststand.jpg'
  '{{IMG_ROBOROI}}'    = 'roboroi.jpg'
  '{{IMG_TOGETHER}}'   = 'together.jpg'
  '{{IMG_HOMEREFORM}}' = 'homereform.jpg'
  '{{IMG_FINES}}'      = 'fines.jpg'
}

$html = Get-Content (Join-Path $root 'template.html') -Raw -Encoding UTF8

foreach ($token in $map.Keys) {
  $path = Join-Path $root "images\$($map[$token])"
  if (-not (Test-Path $path)) { throw "Missing image: $path" }
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
  $html = $html.Replace($token, "data:image/jpeg;base64,$b64")
}

if ($html -match '\{\{') { throw 'An image token was left unreplaced - check the map above.' }

$out = Join-Path $root 'index.html'
Set-Content $out $html -Encoding UTF8 -NoNewline
Write-Host ("Built index.html - {0} KB" -f [int]((Get-Item $out).Length / 1KB))
