#!/usr/bin/env bash
# Builds preview/index.html from the REAL contracts.
#
# The page contains no rendering rules of its own: every tile is a tokenURI
# produced by OposNFT + OposRenderer, inlined verbatim. Change anything in
# src/ and re-run this (or leave --watch running) and the preview follows.
#
#   scripts/build_preview.sh            build once
#   scripts/build_preview.sh --watch    rebuild whenever src/*.sol changes
set -euo pipefail
cd "$(dirname "$0")/.."

POOL_FILE="preview/pool.txt"
OUT="preview/index.html"

build() {
  forge script script/RenderPreviewPool.s.sol --tc RenderPreviewPool >/dev/null
  local count
  count=$(wc -l < "$POOL_FILE" | tr -d ' ')

  {
    cat <<'HTML_HEAD'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>OPOSSUM NFT — Preview</title>
<style>
  :root {
    --bg: #0e0e10;
    --panel: #1a1a1d;
    --line: #2a2a2f;
    --text: #e8e8ea;
    --muted: #9b9ba1;
    --accent: #ff1493;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, system-ui, Segoe UI, Roboto, sans-serif;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 24px;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 24px;
    flex-wrap: wrap;
    gap: 16px;
  }
  h1 { margin: 0; font-size: 22px; font-weight: 600; }
  .sub { color: var(--muted); font-size: 13px; }
  code { color: var(--text); }
  button {
    padding: 10px 20px;
    background: var(--accent);
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 600;
    font-size: 14px;
  }
  button:hover { filter: brightness(1.1); }
  button.copy {
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--line);
    padding: 4px 10px;
    font-size: 11px;
    font-weight: 500;
  }
  button.copy:hover { color: var(--text); border-color: var(--text); }
  button.copy.copied { color: #6ee7b7; border-color: #6ee7b7; }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 16px;
  }
  .card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 10px;
    overflow: hidden;
  }
  .card img {
    display: block;
    width: 100%;
    height: auto;
    image-rendering: pixelated;
    image-rendering: crisp-edges;
  }
  .meta { padding: 12px; }
  .name { font-weight: 600; font-size: 14px; margin-bottom: 8px; }
  .traits {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 4px 10px;
    font-size: 12px;
    line-height: 1.4;
  }
  .traits .k { color: var(--muted); }
  .traits .v { color: var(--text); }
  .actions { margin-top: 10px; display: flex; gap: 6px; flex-wrap: wrap; }
  .onchain { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 10px; color: var(--muted); margin-top: 6px; }
  .badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    margin-left: 6px;
  }
  .badge.Mythic    { background: #ff1493; color: white; }
  .badge.Legendary { background: #ffd700; color: #1a1a1d; }
  .badge.Epic      { background: #9b30ff; color: white; }
  .badge.Rare      { background: #1e90ff; color: white; }
  .badge.Common    { background: #555; color: white; }
</style>
</head>
<body>
<header>
  <div>
    <h1>OPOSSUM NFT — Preview</h1>
    <div class="sub">
      Generated from the real contracts — every tile below is a <code>tokenURI</code>
      straight out of <code>OposNFT</code> + <code>OposRenderer</code>. This page has no
      drawing rules of its own. Rebuild after editing <code>src/</code> with
      <code>scripts/build_preview.sh</code>.
    </div>
  </div>
  <button onclick="mintTwenty()">Mint 20 New</button>
</header>
<div id="dist-bar" style="background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 12px; margin-bottom: 16px; font-size: 12px; color: var(--muted);"></div>
<div id="grid" class="grid"></div>

<script>
// ───────────────────────────────────────────────────────────
// GENERATED FILE — do not edit by hand.
// Built by scripts/build_preview.sh from script/RenderPreviewPool.s.sol.
//
// POOL holds real `data:application/json;base64,…` tokenURIs minted from the
// actual contracts. Nothing here re-implements the renderer: the page only
// base64-decodes what the chain produced and shows it.
// ───────────────────────────────────────────────────────────
const POOL = [
HTML_HEAD

    # One quoted, comma-terminated JS string per tokenURI.
    sed 's/^/"/; s/$/",/' "$POOL_FILE"

    cat <<'HTML_TAIL'
];

/// Decode a tokenURI into its metadata object. This is the only transformation
/// the page performs — base64 in, contract-authored JSON out.
function decodeTokenURI(uri) {
  return JSON.parse(atob(uri.slice(uri.indexOf(",") + 1)));
}

const METADATA = POOL.map(decodeTokenURI);

// Yield traits are always 0 in the preview (no fees flow here), so they'd add
// two dead rows to every card. Everything else the contract emitted is shown.
const HIDDEN_TRAITS = new Set(["Claimable OPOS", "Lifetime OPOS"]);

function traitValue(meta, name) {
  const a = meta.attributes.find(x => x.trait_type === name);
  return a ? a.value : "";
}

function makeCard(meta) {
  const rarity = traitValue(meta, "Rarity");
  const traitRows = meta.attributes
    .filter(a => !HIDDEN_TRAITS.has(a.trait_type))
    .map(a => `<div class="k">${a.trait_type}</div><div class="v">${a.value}</div>`)
    .join("");
  const div = document.createElement("div");
  div.className = "card";
  div.innerHTML = `
    <img src="${meta.image}" alt="${meta.name}" />
    <div class="meta">
      <div class="name">${meta.name}<span class="badge ${rarity}">${rarity}</span></div>
      <div class="traits">${traitRows}</div>
      <div class="onchain">rendered on-chain</div>
      <div class="actions">
        <button class="copy" data-meta='${escapeAttr(JSON.stringify(meta))}'>Copy JSON</button>
      </div>
    </div>
  `;
  return div;
}

function escapeAttr(s) { return s.replace(/'/g, "&apos;").replace(/"/g, "&quot;"); }

document.addEventListener("click", (e) => {
  const btn = e.target.closest("button.copy");
  if (!btn) return;
  navigator.clipboard.writeText(btn.dataset.meta).then(() => {
    btn.classList.add("copied");
    btn.textContent = "Copied!";
    setTimeout(() => { btn.classList.remove("copied"); btn.textContent = "Copy JSON"; }, 1200);
  });
});

// Tier counts come from the Rarity trait the contract wrote — the page never
// scores rarity itself.
function distributionSummary(sample) {
  const tierNames = ["Mythic", "Legendary", "Epic", "Rare", "Common"];
  const counts = Object.fromEntries(tierNames.map(n => [n, 0]));
  for (const meta of sample) counts[traitValue(meta, "Rarity")]++;
  const parts = tierNames.map(n => {
    const c = counts[n];
    const perNft = c > 0 ? `20% / ${c} = ${(20 / c).toFixed(2)}%` : `20% (banked — no NFT yet)`;
    return `<b style="color:var(--text)">${n}</b> ${c} NFT${c === 1 ? "" : "s"} → ${perNft} each`;
  });
  return "Per fee, each tier earns 20%. From this 20-mint sample: " + parts.join(" · ");
}

function sample(n) {
  const idx = METADATA.map((_, i) => i);
  for (let i = idx.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [idx[i], idx[j]] = [idx[j], idx[i]];
  }
  return idx.slice(0, n).map(i => METADATA[i]);
}

function mintTwenty() {
  const grid = document.getElementById("grid");
  const bar = document.getElementById("dist-bar");
  grid.innerHTML = "";
  const picked = sample(20);
  for (const meta of picked) grid.appendChild(makeCard(meta));
  bar.innerHTML = distributionSummary(picked);
}

mintTwenty();
</script>
</body>
</html>
HTML_TAIL
  } > "$OUT"

  echo "Wrote $OUT from $count on-chain tokenURIs ($(du -h "$OUT" | cut -f1))."
}

# Checksum of everything the render depends on.
fingerprint() {
  cat src/*.sol script/RenderPreviewPool.s.sol 2>/dev/null | shasum | cut -d' ' -f1
}

if [ "${1:-}" = "--watch" ]; then
  build
  last=$(fingerprint)
  echo "Watching src/*.sol — edit and save to rebuild (Ctrl-C to stop)."
  while true; do
    sleep 2
    current=$(fingerprint)
    if [ "$current" != "$last" ]; then
      echo "src changed — rebuilding…"
      build || echo "build failed; leaving the previous $OUT in place"
      last=$(fingerprint)
    fi
  done
else
  build
  echo "Open it with: open $OUT"
fi
