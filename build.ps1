# Builds the site from template.html.
#
#   powershell -ExecutionPolicy Bypass -File ./build.ps1
#
# Two outputs, because they are consumed differently:
#
#   index.html     a complete standalone document - doctype, charset, VIEWPORT.
#                  This is what nginx serves. Without the viewport tag a phone
#                  lays the page out at ~980px and scales it down, so none of
#                  the media queries fire and the mobile CSS never runs.
#
#   fragment.html  the same page without the skeleton, for previewing as a
#                  Claude artifact (that publisher adds its own head/body).
#
# Edit template.html. Never edit either output by hand - this overwrites them.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$map = @{
  '{{IMG_LASTSTAND}}'  = 'laststand.jpg'
  '{{IMG_ROBOROI}}'    = 'roboroi.jpg'
  '{{IMG_TOGETHER}}'   = 'together.jpg'
  '{{IMG_HOMEREFORM}}' = 'homereform.jpg'
  '{{IMG_FINES}}'      = 'fines.jpg'
}

$fragment = Get-Content (Join-Path $root 'template.html') -Raw -Encoding UTF8

foreach ($token in $map.Keys) {
  $path = Join-Path $root "images\$($map[$token])"
  if (-not (Test-Path $path)) { throw "Missing image: $path" }
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
  $fragment = $fragment.Replace($token, "data:image/jpeg;base64,$b64")
}

if ($fragment -match '\{\{') { throw 'An image token was left unreplaced - check the map above.' }

Set-Content (Join-Path $root 'fragment.html') $fragment -Encoding UTF8 -NoNewline

# Split at the stylesheet so <title> and <style> land in <head>, not <body>.
$marker = '</style>'
$cut = $fragment.IndexOf($marker)
if ($cut -lt 0) { throw 'No </style> found in template.html - cannot split head from body.' }
$head = $fragment.Substring(0, $cut + $marker.Length)
$body = $fragment.Substring($cut + $marker.Length)

$description = 'Devin Jones - controls governance in London during the week, and the things I build at weekends.'

$doc = @"
<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="$description">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 16 16%22><text y=%2214%22 font-size=%2214%22>&#128197;</text></svg>">
$head
</head>
<body>
$body
</body>
</html>
"@

$out = Join-Path $root 'index.html'
Set-Content $out $doc -Encoding UTF8 -NoNewline

if ((Get-Content $out -Raw) -notmatch 'name="viewport"') { throw 'Viewport tag missing from index.html.' }

Write-Host ("Built index.html   - {0} KB (standalone, has viewport)" -f [int]((Get-Item $out).Length / 1KB))
Write-Host ("Built fragment.html - {0} KB (for artifact preview)" -f [int]((Get-Item (Join-Path $root 'fragment.html')).Length / 1KB))
