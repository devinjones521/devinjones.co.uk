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
  '{{IMG_WORKOUT}}'    = 'workout.jpg'
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
$origin = 'https://devinjones.co.uk'
$cardAlt = 'devin jones, london - the two crontab lines the site is built around'

# The icons and the share card are the one part of this page that CANNOT be inlined.
# Everything else is base64 in the HTML, but favicons at fixed sizes, Android home
# screen icons and og:image all have to be real files at real URLs - no crawler will
# follow a data: URI. They live in static/ and deploy.sh uploads them alongside.
#
# The manifest is .json, not the conventional .webmanifest, on purpose: nginx 1.24
# on that box has no mime.types entry for .webmanifest, so it would go out as
# application/octet-stream and Chrome would refuse to parse it. .json maps to
# application/json, which Chrome accepts. Fixing it in nginx would mean editing a
# config that also fronts a client's live site, which is not worth it for this.
$assets = @(
  'icon.svg', 'icon-32.png', 'icon-192.png', 'icon-512.png',
  'icon-maskable-512.png', 'apple-touch-icon.png', 'og.png', 'manifest.json'
)
foreach ($a in $assets) {
  $p = Join-Path $root "static\$a"
  if (-not (Test-Path $p)) { throw "Missing static asset: $p (run build-assets.js to regenerate)" }
}

$doc = @"
<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="$description">
<meta name="color-scheme" content="light dark">

<link rel="canonical" href="$origin/">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/icon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/manifest.json">

<!-- Matched to the page background rather than to the mark, so the Android
     browser chrome sits flush with the page instead of banding across the top. -->
<meta name="theme-color" media="(prefers-color-scheme: light)" content="#EDF0F4">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#11151B">

<meta property="og:type" content="website">
<meta property="og:site_name" content="devin jones">
<meta property="og:url" content="$origin/">
<meta property="og:title" content="devin jones">
<meta property="og:description" content="$description">
<meta property="og:image" content="$origin/og.png">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="$cardAlt">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="devin jones">
<meta name="twitter:description" content="$description">
<meta name="twitter:image" content="$origin/og.png">
<meta name="twitter:image:alt" content="$cardAlt">
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
