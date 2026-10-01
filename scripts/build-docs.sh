#!/bin/sh
# Build the static technical manual with Asciidoctor.
# Input:  docs/index.adoc (+ sections/, images/, theme/)
# Output: build/docs/index.html (self-contained static site)
# Fails clearly if Asciidoctor is missing; never installs anything.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/docs/index.adoc"
OUTDIR="$REPO_ROOT/build/docs"

if ! command -v asciidoctor >/dev/null 2>&1; then
  echo "error: asciidoctor not found." >&2
  echo "" >&2
  echo "Install the minimum dependency first (no Node/npm required):" >&2
  echo "  macOS:                brew install asciidoctor" >&2
  echo "  Debian/Ubuntu:        sudo apt-get install -y asciidoctor" >&2
  echo "  Fedora:               sudo dnf install -y asciidoctor" >&2
  echo "  Any Ruby environment: gem install asciidoctor" >&2
  echo "" >&2
  echo "Optional syntax highlighting backends:" >&2
  echo "  gem install rouge   (recommended) | gem install coderay" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "error: missing source: $SRC" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

# If neither rouge nor coderay is installed, drop the source-highlighter
# attribute instead of failing the build.
HIGHLIGHTER_ARGS=""
if ! (gem list -i rouge >/dev/null 2>&1 || gem list -i coderay >/dev/null 2>&1); then
  HIGHLIGHTER_ARGS="-a source-highlighter!"
fi

asciidoctor \
  -D "$OUTDIR" \
  $HIGHLIGHTER_ARGS \
  "$SRC"

# Ship theme assets and figures alongside the generated HTML.
mkdir -p "$OUTDIR/theme" "$OUTDIR/images"
cp "$REPO_ROOT/docs/theme/docs.css" "$OUTDIR/theme/docs.css"
cp "$REPO_ROOT/docs/theme/nav.js" "$OUTDIR/theme/nav.js"
if ls "$REPO_ROOT/docs/images" >/dev/null 2>&1; then
  cp -R "$REPO_ROOT/docs/images/." "$OUTDIR/images/"
fi

if [ ! -f "$OUTDIR/index.html" ]; then
  echo "error: build failed, no $OUTDIR/index.html produced." >&2
  exit 1
fi

echo "Docs built: $OUTDIR/index.html"
