#!/usr/bin/env bash
# main-drift.sh - drift report between the openspec branch and the branch where
# development continues (conversation_flow: test-sdd-kit vs main).
#
# Read-only: nothing in the repository is written, no branch is switched, no
# merge is performed. Merging main is Daniil's job; this script only names what
# a merge would bring in and what it would invalidate.
#
# Four kinds of drift, in the order an agent has to work through them:
#   1. ТЗ (patch documents) on main that have no counterpart in openspec/changes
#   2. new §17 changelog entries / a bumped LIVING SPEC version
#   3. code changed on main that is referenced by `enforced:` anchors of our
#      capability specs (those specs will go STALE once main is merged)
#   4. code changed on main that no spec anchors at all (coverage gap)
#
# Exit: 0 = no drift, 1 = drift found (CI signal), 2 = usage/environment error.
# Dependencies: git, awk, sed, grep, sort. No python, no network.
set -eu

SELF=$0
MAIN_REF=""
SELF_CHECK=0

usage() {
    cat <<'EOF'
main-drift.sh - что накопилось на ветке разработки и чего это стоит нашим спекам

Запуск из корня conversation_flow (или любой его поддиректории):

    bash tools/cf/main-drift.sh [--main <ref>] [--self-check] [--help]

    --main <ref>   ветка/ревизия активной разработки. По умолчанию origin/main,
                   если он есть в клоне, иначе локальный main.
    --self-check   прогнать проверку самого скрипта на временном git-репозитории
                   (ничего не читает из текущего репозитория).
    --help         этот текст.

Что печатает:
  0) merge-base и расхождение ветвей;
  1) ТЗ (docs/patches/patchNN-*) на <main>, для которых нет ни активного
     openspec/changes/tz-NNN-*, ни архивного openspec/changes/archive/tz-NNN-*
     (ключ сверки - только номер ТЗ; ведущие нули игнорируются);
  2) новые записи §17 changelog и смену «Версия документа:» в
     docs/DOCUMENTATION.md между merge-base и <main>;
  3) изменённый на <main> код против `enforced:`-якорей openspec/specs/*:
     таблица «файл -> какие спеки станут STALE после мержа»;
  4) итоговые счётчики.

Коды выхода: 0 - дрейфа нет; 1 - дрейф есть; 2 - ошибка запуска.
Скрипт только читает. Мерж, ре-верификацию и обновление маркеров
`> Last verified:` делает человек/агент по tools/cf/sync-main.md.
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --help | -h)
            usage
            exit 0
            ;;
        --self-check)
            SELF_CHECK=1
            ;;
        --main)
            [ $# -ge 2 ] || {
                echo "main-drift: --main требует аргумент" >&2
                exit 2
            }
            MAIN_REF=$2
            shift
            ;;
        --main=*)
            MAIN_REF=${1#--main=}
            ;;
        *)
            echo "main-drift: неизвестный аргумент '$1' (см. --help)" >&2
            exit 2
            ;;
    esac
    shift
done

die() {
    echo "main-drift: $*" >&2
    exit 2
}

# ---------------------------------------------------------------- anchors -----
# The file half of spec-lint.py::resolve_anchor: one `enforced:` value may name
# several files separated by `;`, each optionally suffixed with `:lines`,
# `:12-34` or `:symbol`, themselves `,`-separated. Freshness cares about the
# file set only, so the suffix is dropped here; validating that the suffix
# actually exists is spec-lint's job (templates/spec-lint.py::_resolve_one) and
# duplicating it would mean a second, worse parser. Consequence, on purpose: an
# anchor spec-lint rejects wholesale (one bad part discredits it) still
# contributes its files here - a false STALE warning is cheaper than a miss.
anchor_index() {
    # stdout: "<path>\t<capability>" per anchored file, deduplicated.
    for spec in openspec/specs/*/spec.md openspec/specs/*/*/spec.md; do
        [ -f "$spec" ] || continue
        capability=$(dirname "$spec")
        capability=${capability#openspec/specs/}
        awk -v cap="$capability" '
            /^[[:space:]]*<!--[[:space:]]*enforced:/ {
                line = $0
                sub(/^[[:space:]]*<!--[[:space:]]*enforced:[[:space:]]*/, "", line)
                sub(/[[:space:]]*-->[[:space:]]*$/, "", line)
                n = split(line, part, ";")
                for (i = 1; i <= n; i++) {
                    p = part[i]
                    gsub(/^[[:space:]]+/, "", p)
                    gsub(/[[:space:]]+$/, "", p)
                    sub(/:.*$/, "", p)
                    if (p != "") print p "\t" cap
                }
            }
        ' "$spec"
    done | sort -u
}

# ТЗ numbers already represented in openspec, padded to three digits.
covered_tz() {
    for dir in openspec/changes/*/ openspec/changes/archive/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        case $name in
            tz-*) ;;
            *) continue ;;
        esac
        num=${name#tz-}
        num=${num%%-*}
        # tz-001a-visual-editor and friends: keep the digits, drop the rest
        num=$(printf '%s' "$num" | tr -dc '0-9')
        [ -n "$num" ] || continue
        num=$((10#$num)) # tz-092 is decimal 92, not an octal literal
        case $dir in
            openspec/changes/archive/*) where=archive ;;
            *) where=active ;;
        esac
        printf '%03d\t%s\t%s\n' "$num" "$where" "$name"
    done | sort -u
}

# ------------------------------------------------------------------ report ----
report() {
    root=$(git rev-parse --show-toplevel 2>/dev/null) || die "не git-репозиторий: $PWD"
    cd "$root"
    [ -d openspec/specs ] || die "нет openspec/specs - запускать из репозитория с openspec (сейчас $root)"

    if [ -z "$MAIN_REF" ]; then
        if git rev-parse --verify --quiet origin/main >/dev/null; then
            MAIN_REF=origin/main
        elif git rev-parse --verify --quiet main >/dev/null; then
            MAIN_REF=main
        else
            die "не нашёл ни origin/main, ни main - укажи --main <ref>"
        fi
    fi
    git rev-parse --verify --quiet "$MAIN_REF" >/dev/null || die "ревизия '$MAIN_REF' не найдена"

    here=$(git rev-parse --abbrev-ref HEAD)
    main_sha=$(git rev-parse --short "$MAIN_REF")
    base=$(git merge-base HEAD "$MAIN_REF") || die "нет общего предка HEAD и $MAIN_REF"
    base_short=$(git rev-parse --short "$base")
    ahead_main=$(git rev-list --count "$base..$MAIN_REF")
    ahead_here=$(git rev-list --count "$base..HEAD")

    tmp=$(mktemp -d) || die "mktemp не сработал"
    trap 'rm -rf "$tmp"' EXIT

    echo "== main-drift: $here (openspec) <- $MAIN_REF ($main_sha, разработка)"
    echo "   merge-base: $base_short"
    echo "   на $MAIN_REF коммитов после merge-base: $ahead_main; на $here: $ahead_here"
    if [ "$ahead_main" = 0 ]; then
        echo "   (внимание: $MAIN_REF не ушёл вперёд - если ждёшь свежие коммиты, сделай git fetch)"
    fi

    drift=0

    # --- 1. ТЗ на main без представления в openspec ---------------------------
    git ls-tree -r --name-only "$MAIN_REF" -- docs/patches \
        | awk -F/ '{
              f = $NF
              if (match(f, /^patch[0-9]+-/)) {
                  n = substr(f, 6, RLENGTH - 6)
                  printf "%03d\t%s\n", n, f
              }
          }' | sort -u >"$tmp/patches"
    covered_tz >"$tmp/covered"
    git diff --name-only --diff-filter=A "$base..$MAIN_REF" -- docs/patches >"$tmp/added" || true

    : >"$tmp/pending"
    while IFS="$(printf '\t')" read -r num file; do
        [ -n "${num:-}" ] || continue
        if cut -f1 "$tmp/covered" | grep -qx "$num"; then
            continue
        fi
        mark="был на merge-base"
        if grep -qx "docs/patches/$file" "$tmp/added"; then
            mark="новый на $MAIN_REF"
        fi
        printf '%s\t%s\t%s\n' "$num" "$file" "$mark" >>"$tmp/pending"
    done <"$tmp/patches"

    pending=$(wc -l <"$tmp/pending" | tr -d ' ')
    echo
    echo "== 1. ТЗ без openspec-представления: $pending (из $(wc -l <"$tmp/patches" | tr -d ' ') patchNN-* на $MAIN_REF)"
    if [ "$pending" -gt 0 ]; then
        drift=1
        while IFS="$(printf '\t')" read -r num file mark; do
            echo "   ТЗ №${num#00} docs/patches/$file  [$mark]"
            echo "      -> нет ни openspec/changes/tz-$num-*, ни .../archive/tz-$num-*"
        done <"$tmp/pending"
        echo "   решение реализовано/не реализовано и куда класть change - tools/cf/sync-main.md"
    else
        echo "   все ТЗ на $MAIN_REF имеют tz-* (активный или архивный)"
    fi

    # --- 2. LIVING SPEC: версия и §17 ----------------------------------------
    echo
    echo "== 2. LIVING SPEC (docs/DOCUMENTATION.md)"
    ver_base=$(git show "$base:docs/DOCUMENTATION.md" 2>/dev/null \
        | sed -n 's/.*Версия документа:\*\*[[:space:]]*\([0-9][0-9.]*\).*/\1/p' | head -1)
    ver_main=$(git show "$MAIN_REF:docs/DOCUMENTATION.md" 2>/dev/null \
        | sed -n 's/.*Версия документа:\*\*[[:space:]]*\([0-9][0-9.]*\).*/\1/p' | head -1)
    git diff "$base..$MAIN_REF" -- docs/DOCUMENTATION.md >"$tmp/docdiff" || true
    grep '^+- \*\*\[' "$tmp/docdiff" >"$tmp/changelog" || true
    entries=$(wc -l <"$tmp/changelog" | tr -d ' ')

    if [ "${ver_base:-}" != "${ver_main:-}" ]; then
        drift=1
        echo "   версия документа: ${ver_base:-?} -> ${ver_main:-?}"
    else
        echo "   версия документа: ${ver_main:-?} (не менялась)"
    fi
    echo "   новых записей §17 changelog: $entries"
    if [ "$entries" -gt 0 ]; then
        drift=1
        sed 's/^+/   + /' "$tmp/changelog"
    fi
    if [ -s "$tmp/docdiff" ] && [ "$entries" = 0 ] && [ "${ver_base:-}" = "${ver_main:-}" ]; then
        drift=1
        echo "   DOCUMENTATION.md изменён, но ни версия, ни §17 не тронуты - смотреть git diff вручную"
    fi
    echo "   мерж-конфликт по шапке документа ожидаем (см. tools/cf/sync-main.md)"

    # --- 3. код против enforced-якорей ---------------------------------------
    git diff --name-only "$base..$MAIN_REF" >"$tmp/changed" || true
    grep -v -e '^docs/patches/' -e '^docs/DOCUMENTATION\.md$' "$tmp/changed" >"$tmp/code" || true
    anchor_index >"$tmp/anchors"

    : >"$tmp/stale"
    : >"$tmp/unanchored"
    while IFS= read -r file; do
        [ -n "${file:-}" ] || continue
        caps=$(awk -F'\t' -v f="$file" '$1 == f { print $2 }' "$tmp/anchors" | sort -u | paste -sd, -)
        if [ -n "$caps" ]; then
            printf '%s\t%s\n' "$file" "$caps" >>"$tmp/stale"
        else
            echo "$file" >>"$tmp/unanchored"
        fi
    done <"$tmp/code"

    stale_specs=$(cut -f2 "$tmp/stale" | tr ',' '\n' | sort -u | grep -c . || true)
    echo
    echo "== 3. изменённый на $MAIN_REF код: $(wc -l <"$tmp/code" | tr -d ' ') файл(ов);"
    echo "      покрыто якорями спек: $(wc -l <"$tmp/stale" | tr -d ' ') -> спек под STALE: $stale_specs"
    if [ -s "$tmp/stale" ]; then
        drift=1
        while IFS="$(printf '\t')" read -r file caps; do
            echo "   $file"
            echo "      -> STALE после мержа: $caps"
        done <"$tmp/stale"
    fi
    if [ -s "$tmp/unanchored" ]; then
        drift=1
        echo "   без якорей ни в одной спеке (пробел покрытия либо не-код):"
        sed 's/^/      /' "$tmp/unanchored"
    fi
    echo "   ЛОВУШКА: пока $MAIN_REF не влит в $here, spec-lint этих изменений НЕ видит"
    echo "   (он сравнивает 'Last verified'-коммит с HEAD своей ветки). Порядок работ - tools/cf/sync-main.md"

    # --- 4. итог --------------------------------------------------------------
    echo
    echo "== ИТОГ: ТЗ ждут конвертации: $pending; спек под угрозой STALE: $stale_specs;"
    echo "         изменённых файлов без покрытия спеками: $(wc -l <"$tmp/unanchored" | tr -d ' ')"
    if [ "$drift" = 0 ]; then
        echo "         дрейфа нет"
    fi
    return "$drift"
}

# -------------------------------------------------------------- self-check ----
self_check() {
    tmp=$(mktemp -d) || die "mktemp не сработал"
    trap 'rm -rf "$tmp"' EXIT
    self=$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")
    cd "$tmp"

    git init -q .
    git symbolic-ref HEAD refs/heads/spec
    git config user.email cf@example.com
    git config user.name cf
    git config commit.gpgsign false

    mkdir -p docs/patches app values
    printf '# LIVING SPEC\n\n**Версия документа:** 1.1.0 · **Дата:** 2026-01-01\n\n## 17. Changelog\n\n- **[1.1.0] [2026-01-01]** — базовая запись\n' >docs/DOCUMENTATION.md
    printf '# ТЗ №1\n' >docs/patches/patch01-alpha.md
    printf 'def fn():\n    pass\n' >app/code.py
    printf 'HELPER = 1\n' >app/util.py
    git add -A
    git commit -qm base

    # branch of active development: new ТЗ, bumped version, changed code
    git checkout -q -b main
    printf '# ТЗ №2\n' >docs/patches/patch02-beta.md
    sed -i 's/1\.1\.0 ·/1.2.0 ·/' docs/DOCUMENTATION.md
    sed -i 's/^- \*\*\[1\.1\.0\].*/- **[1.2.0] [2026-01-02]** — новая запись\n&/' docs/DOCUMENTATION.md
    printf 'def fn():\n    return 2\n' >app/code.py
    printf 'HELPER = 2\n' >app/util.py
    printf 'replicas: 3\n' >values/x.yaml
    git add -A
    git commit -qm dev

    # our branch: openspec appears only here, ТЗ №1 already archived
    git checkout -q spec
    mkdir -p openspec/specs/cap openspec/changes/archive/tz-001-alpha
    {
        printf '# cap\n\n> Last verified: 2026-01-01 (commit deadbeef)\n\n## Requirements\n\n'
        printf '### Requirement: A\n<!-- id: cap.a -->\n<!-- enforced: app/code.py:fn; app/util.py:1-2,HELPER -->\n\n'
        printf '#### Scenario: s\n- **WHEN** x\n- **THEN** y\n'
    } >openspec/specs/cap/spec.md
    printf '# tz-001\n' >openspec/changes/archive/tz-001-alpha/proposal.md
    git add -A
    git commit -qm openspec

    fails=0
    check() { # check <label> <expected-in-output|-> ...
        label=$1
        shift
        for want in "$@"; do
            if grep -qF -- "$want" "$tmp/out"; then continue; fi
            echo "main-drift self-check FAIL [$label]: в выводе нет '$want'" >&2
            fails=$((fails + 1))
        done
    }

    set +e
    bash "$self" --main main >"$tmp/out" 2>&1
    code=$?
    set -e
    [ "$code" = 1 ] || {
        echo "main-drift self-check FAIL [drift]: код выхода $code, ожидался 1" >&2
        fails=$((fails + 1))
    }
    check drift \
        "patch02-beta.md" \
        "нет ни openspec/changes/tz-002-*" \
        "1.1.0 -> 1.2.0" \
        "новая запись" \
        "app/code.py" \
        "app/util.py" \
        "STALE после мержа: cap" \
        "values/x.yaml" \
        "ТЗ ждут конвертации: 1" \
        "спек под угрозой STALE: 1"
    if grep -qF "patch01-alpha.md" "$tmp/out"; then
        echo "main-drift self-check FAIL [covered]: конвертированное ТЗ №1 попало в дрейф" >&2
        fails=$((fails + 1))
    fi

    set +e
    bash "$self" --main HEAD >"$tmp/out2" 2>&1
    code=$?
    set -e
    [ "$code" = 0 ] || {
        echo "main-drift self-check FAIL [clean]: код выхода $code, ожидался 0" >&2
        fails=$((fails + 1))
    }
    grep -qF "дрейфа нет" "$tmp/out2" || {
        echo "main-drift self-check FAIL [clean]: нет строки 'дрейфа нет'" >&2
        fails=$((fails + 1))
    }

    if [ "$fails" = 0 ]; then
        echo "main-drift self-check: OK (дрейф найден и посчитан, чистый прогон чист)"
        return 0
    fi
    echo "main-drift self-check: $fails провал(ов)" >&2
    return 1
}

if [ "$SELF_CHECK" = 1 ]; then
    self_check
    exit $?
fi
set +e
report
exit $?
