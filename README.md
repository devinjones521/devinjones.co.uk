# devinjones.co.uk

My personal site. One page, no framework, no build step beyond inlining the images.

## Layout

```
template.html   the source - edit this
images/         project screenshots, inlined at build time
build.ps1       template.html + images -> index.html
index.html      generated, served by GitHub Pages - do not edit by hand
CNAME           custom domain
```

## Changing it

```powershell
powershell -ExecutionPolicy Bypass -File ./build.ps1
```

Then commit both `template.html` and `index.html`. Pages redeploys on push to `main`.

`build.ps1` fails loudly if an image is missing or a `{{IMG_*}}` token is left
unreplaced, so a half-built page cannot reach the site.

## Notes

The page is a single self-contained file: all CSS and JS are inline and every
image is a base64 data URI. It works offline, and there is no request waterfall.

It reads the visitor's clock to mark which of the two cron schedules is running
when they arrive. That is the only JavaScript that matters; everything else
degrades to a plain scrolling document.

Light and dark are both handled through CSS custom properties, keyed off
`prefers-color-scheme` and an explicit `data-theme` override.
