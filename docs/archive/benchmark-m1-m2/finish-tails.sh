#!/usr/bin/env bash
# Хвосты бенчмарка m1: дифф sdd + ruff-гейт + архив. Идемпотентно.
# Запуск: bash refactor_v4/sdd-kit/benchmark/archive-m1-m2/finish-tails.sh
set -u
cd /home/octrow/cybernet/refactor_v4/sdd-kit-claude/web-backend-new
mkdir -p ~/bench/results-manual
R=~/bench/results-manual/WEB-2314-sdd-m1

# 1. Дифф (рабочее дерево остаётся нетронутым)
git add -A
git diff --cached bench-base > "$R.diff"
git status --short > "$R.files.txt"
git reset -q
echo "PASS diff-captured ($(wc -l < "$R.diff") lines)" > "$R.gates.txt"

# 2. Ruff-гейт: новые нарушения vs bench-base (CPY001 исключён)
agg() { grep -oE '^[^ :]+:[0-9]+:[0-9]+: [A-Z]+[0-9]+' | grep -v CPY001 \
  | awk -F: '{gsub(/^ /,"",$4); print $1, $4}' | sort | uniq -c \
  | awk '{print $2, $3, $1}'; }
CHANGED_PY=$(grep -E '^\+\+\+ b/.*\.py$' "$R.diff" | sed 's|^+++ b/||' | sort -u)
uvx ruff check --output-format concise $CHANGED_PY 2>/dev/null | agg > "$R.ruff-after.txt"

WT=$(mktemp -d)
for f in $CHANGED_PY; do
  if git cat-file -e "bench-base:$f" 2>/dev/null; then
    mkdir -p "$WT/$(dirname "$f")"
    git show "bench-base:$f" > "$WT/$f"
  fi
done
cp api-gateway-service/pyproject.toml "$WT/api-gateway-service/" 2>/dev/null
[ -f ruff.toml ] && cp ruff.toml "$WT/"
(cd "$WT" && uvx ruff check --output-format concise $(find . -name '*.py' | sed 's|^\./||') 2>/dev/null) | agg > "$R.ruff-before.txt"
rm -rf "$WT"

python3 - "$R" <<'EOF'
import sys
R=sys.argv[1]
def load(p):
    d={}
    for l in open(p):
        parts=l.split()
        if len(parts)==3: d[(parts[0],parts[1])]=int(parts[2])
    return d
b=load(f"{R}.ruff-before.txt"); a=load(f"{R}.ruff-after.txt")
new=[(k,a[k]-b.get(k,0)) for k in sorted(a) if a[k]>b.get(k,0)]
with open(f"{R}.gates.txt","a") as out:
    if not new: out.write("PASS ruff (no new violations)\n")
    else:
        out.write(f"FAIL ruff ({sum(n for _,n in new)} new)\n")
        for (f,c),n in new: out.write(f"  new: {f} {c} +{n}\n")
EOF

# 3. Архив
bash /home/octrow/cybernet/refactor_v4/logs/sync-logs.sh
mkdir -p /home/octrow/cybernet/refactor_v4/logs/manual-m1
rsync -a ~/bench/results-manual/ /home/octrow/cybernet/refactor_v4/logs/manual-m1/

echo "=== ИТОГ ==="
cat "$R.gates.txt"
echo "files: $(grep -c '^diff --git' "$R.diff") changed"
