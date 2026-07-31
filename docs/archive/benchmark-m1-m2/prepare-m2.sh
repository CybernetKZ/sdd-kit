#!/usr/bin/env bash
# Подготовка ручного бенчмарка m2 (WEB-2234): свежие клоны, .env, kit на arm B, проверки.
# Запуск: bash refactor_v4/sdd-kit/benchmark/archive-m1-m2/prepare-m2.sh
set -uo pipefail
cd /home/octrow/cybernet/refactor_v4   # cwd вызова может быть внутри удаляемого клона

SRC=/home/octrow/cybernet/web-backend-new
NUDE_DIR=/home/octrow/cybernet/refactor_v4/nude-claude
SDD_DIR=/home/octrow/cybernet/refactor_v4/sdd-kit-claude
NUDE=$NUDE_DIR/web-backend-new
SDD=$SDD_DIR/web-backend-new
KIT=/home/octrow/cybernet/sdd-kit
LOGS=/home/octrow/cybernet/refactor_v4/logs
YT_DIR=/home/octrow/dev/youtrack-mcp
TASK=Web-2234
SNAP=$LOGS/prep-m2-snapshot.txt

fail() { echo "FAIL: $*" >&2; exit 1; }
note() { echo "== $*"; echo "== $*" >> "$SNAP"; }

mkdir -p "$LOGS" ~/bench
: > "$SNAP"
echo "m2 prep $(date -Iseconds)" >> "$SNAP"

# 0. Страховка: архивы m1 должны существовать до удаления клонов
[ -s "$LOGS/manual-m1/WEB-2314-nude-m1.diff" ] || fail "нет архива nude-m1 диффа"
[ -s "$LOGS/manual-m1/WEB-2314-sdd-m1.diff" ]  || fail "нет архива sdd-m1 диффа"
note "архивы m1 на месте — клоны можно удалять"

# 1. Текст тикета WEB-2234 -> ~/bench/prompt-m2.md
TOKEN=$(grep -m1 -E '^[A-Z_]*TOKEN[A-Z_]*=' "$YT_DIR/.env" | cut -d= -f2- | tr -d '"' )
[ -n "$TOKEN" ] || fail "не нашёл токен в $YT_DIR/.env"
curl -sf -H "Authorization: Bearer $TOKEN" \
  "https://cybernet.youtrack.cloud/api/issues/$TASK?fields=idReadable,summary,description" \
  > /tmp/yt-2234.json || fail "youtrack REST не ответил"
python3 - <<'EOF' || fail "не распарсил тикет"
import json
d = json.load(open("/tmp/yt-2234.json"))
with open(f"{__import__('os').path.expanduser('~')}/bench/prompt-m2.md", "w") as f:
    f.write(f"# {d['idReadable']}: {d['summary']}\n\n{d.get('description') or ''}\n")
print("ticket:", d["idReadable"], "-", d["summary"])
EOF
note "тикет сохранён: ~/bench/prompt-m2.md"

# 2. SHA: текущий origin/dev рабочего репо (fetch, при офлайне — локальный dev)
git -C "$SRC" fetch origin dev 2>/dev/null || echo "warn: fetch не удался, беру локальный dev"
SHA=$(git -C "$SRC" rev-parse origin/dev 2>/dev/null || git -C "$SRC" rev-parse dev)
[ -n "$SHA" ] || fail "не определил SHA"
note "base SHA: $SHA"

# 3. Свежие клоны (старые удаляются — диффы m1 уже в архиве)
rm -rf "$NUDE" "$SDD"
mkdir -p "$NUDE_DIR" "$SDD_DIR"
for DEST in "$NUDE" "$SDD"; do
  git clone --quiet --local "$SRC" "$DEST" || fail "clone -> $DEST"
  git -C "$DEST" checkout -q -B bench-base "$SHA" || fail "checkout $SHA в $DEST"
  git -C "$DEST" remote remove origin
  rm -f "$DEST/.claude/settings.local.json"
done
note "клоны пересозданы на $SHA, push отключён"

# 4. Копия реальных .env в оба клона (в git их нет, в дифф не попадут)
CNT=0
while IFS= read -r f; do
  rel=${f#"$SRC"/}
  for DEST in "$NUDE" "$SDD"; do
    mkdir -p "$DEST/$(dirname "$rel")"
    cp "$f" "$DEST/$rel"
  done
  CNT=$((CNT+1))
done < <(find "$SRC" -maxdepth 2 -name '.env' -not -path '*/.git/*')
note ".env скопированы: $CNT файлов в каждый клон"

# 5. Арма B: обновлённый kit + реалистичное состояние
SDD_KIT_ASSUME_YES=1 bash "$KIT/bootstrap.sh" "$SDD" || fail "bootstrap упал"
# курированный AGENTS.md и добытые спеки из рабочего репо (если есть)
[ -f "$SRC/AGENTS.md" ] && cp "$SRC/AGENTS.md" "$SDD/AGENTS.md"
[ -d "$SRC/openspec/specs" ] && rsync -a "$SRC/openspec/specs/" "$SDD/openspec/specs/"
# graphify-кэш (вне git через info/exclude)
if [ -d "$SRC/graphify-out" ]; then
  rsync -a "$SRC/graphify-out/" "$SDD/graphify-out/"
  grep -q '^graphify-out/' "$SDD/.git/info/exclude" 2>/dev/null || echo 'graphify-out/' >> "$SDD/.git/info/exclude"
  note "graphify-кэш скопирован ($(du -sh "$SDD/graphify-out" | cut -f1))"
fi
(cd "$SDD" && make sdd-check) >> "$SNAP" 2>&1 && note "sdd-check: PASS" || note "sdd-check: FAIL (см. снапшот)"
(cd "$SDD" && make sdd-doctor) >> "$SNAP" 2>&1 || true
git -C "$SDD" add -A
git -C "$SDD" commit -qm "install sdd-kit, seed agents.md and specs for bench-base" || note "commit arm B: нечего коммитить?"
note "арма B закоммичена в bench-base: $(git -C "$SDD" rev-parse --short HEAD)"

# 6. Арма A: должна быть голой
for f in .claude AGENTS.md CLAUDE.md .mcp.json; do
  [ -e "$NUDE/$f" ] && note "ВНИМАНИЕ: в nude-клоне есть $f (пришёл из git на этом SHA)"
done

# 7. OTEL-коллектор
docker start bench-otel >/dev/null 2>&1 && note "otel: bench-otel запущен" || note "otel: НЕ ЗАПУСТИЛСЯ — проверь docker"

# 8. Конфиги арм
[ -d ~/bench/cfg-a ] || fail "нет ~/bench/cfg-a"
ls ~/bench/cfg-a >> "$SNAP"
for t in serena headroom; do
  grep -q "$t" ~/bench/cfg-b/.claude.json 2>/dev/null && note "cfg-b: $t ok" || note "cfg-b: $t ОТСУТСТВУЕТ"
done
command -v rtk >/dev/null && note "rtk: $(rtk --version 2>/dev/null | head -1)" || note "rtk отсутствует"
command -v graphify >/dev/null && note "graphify: ok" || note "graphify отсутствует"

# 9. Версии в снапшот
{ claude --version; python3 --version; uvx ruff --version; } >> "$SNAP" 2>&1

echo
echo "=== ИТОГ ==="
cat "$SNAP"
echo
echo "Экспорт-блоки для сессий (порядок m2: СНАЧАЛА sdd, ПОТОМ nude) — см. benchmark/manual-run-m2.md"
