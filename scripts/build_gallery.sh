#!/usr/bin/env bash
# Renders the OPOSSUM QA gallery and assembles a single self-contained
# gallery.html (SVGs inlined — just open it in a browser).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p gallery
rm -f gallery/*.svg
forge script script/RenderGallery.s.sol >/dev/null
count=$(ls gallery/*.svg | wc -l | tr -d ' ')

section_title() {
  case "$1" in
    1) echo "Accessories (all 15)";;
    2) echo "Expressions (all 10)";;
    3) echo "Patterns (all 10)";;
    4) echo "Body colors (all 30)";;
    5) echo "Random seeds";;
    6) echo "Eye colors (all 20)";;
    *) echo "Other";;
  esac
}

{
  cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OPOSSUM NFT — Render Gallery</title>
<style>
  :root { color-scheme: dark; }
  body { background:#15151b; color:#e8e8ee; font-family:system-ui,-apple-system,sans-serif; margin:24px; }
  h1 { font-size:22px; margin:0 0 4px; }
  .sub { color:#9a9aa8; margin:0 0 24px; font-size:13px; }
  h2 { font-size:15px; margin:28px 0 12px; padding-bottom:6px; border-bottom:1px solid #33333f; color:#cfcfe0; }
  .grid { display:flex; flex-wrap:wrap; gap:14px; }
  figure { margin:0; background:#23232c; border-radius:10px; padding:8px; width:170px; box-sizing:border-box; text-align:center; }
  figure svg { width:154px; height:154px; display:block; border-radius:6px; }
  figcaption { font-size:11px; margin-top:6px; color:#b6b6c4; word-break:break-word; line-height:1.3; }
  .toggle { position:fixed; top:16px; right:16px; background:#2d2d38; border:1px solid #44444f; color:#e8e8ee; padding:6px 12px; border-radius:8px; cursor:pointer; font-size:12px; }
  body.light-bg figure svg { outline:2px solid #fff; }
</style>
</head>
<body>
<button class="toggle" onclick="document.body.classList.toggle('light-bg')">toggle outline</button>
<h1>OPOSSUM NFT — Render Gallery</h1>
HTML
  echo "<p class=\"sub\">${count} tiles · each tile shows its own on-chain background. Note anything off and I'll fix it.</p>"

  last=""
  for f in $(ls gallery/*.svg | sort); do
    name=$(basename "$f" .svg)
    sec="${name:0:1}"
    if [ "$sec" != "$last" ]; then
      [ -n "$last" ] && echo "</div>"
      echo "<h2>$(section_title "$sec")</h2><div class=\"grid\">"
      last="$sec"
    fi
    caption="${name:1}"            # strip the section-order digit
    caption="${caption//_/ }"      # underscores -> spaces
    echo "<figure>$(cat "$f")<figcaption>${caption}</figcaption></figure>"
  done
  echo "</div>"

  echo "</body></html>"
} > gallery.html

echo "Wrote gallery.html (${count} tiles). Open it with: open gallery.html"
