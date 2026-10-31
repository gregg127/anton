#!/usr/bin/env bash

set -euo pipefail
NAME="${1:?usage: $0 <dir-name>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Searching for *secret* files under $NAME/ in $ROOT"
count=0
while IFS= read -r -d '' f; do
  echo "decrypting $f"
  ./manage-secrets-sops.sh decrypt "$f" </dev/null || echo "  failed: $f"
  count=$((count + 1))
done < <(find . -type f -path "*/$NAME/*" -name '*secret*' -not -path '*/.git/*' -print0)

echo "done, $count file(s)"
