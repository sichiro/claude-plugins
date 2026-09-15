#!/bin/sh
# run.sh — 하네스 해시를 fixture 위에 materialize 하고 사례마다 claude -p 를 돌려 grade 한다.
#   run.sh --harness <sha> --out <dir> [--sealed <dir>] [--dry-run] [--repeat N]
#   run.sh --materialize <case dir> <work dir> --harness <sha>      (테스트용)
#   run.sh --sealed-manifest <dir>                                  (봉인 묶음 manifest 를 stdout 에)
# 평가 대상의 cwd 에는 하네스(.claude · CLAUDE.md — .claude/harness 제외, settings.json 의 enabledPlugins 제거)와 fixture 만 있다. 정답·grader 는 없다.
# 저장소 루트는 CLAUDE_PROJECT_DIR, 없으면 cwd 의 git toplevel 이다. 평가기는 플러그인(이 스크립트의 디렉터리)에 있다.
# --repeat N: 사례마다 N 회 돌린다. results.jsonl 의 줄에 run(1..N) 이 붙고 N>1 이면 파일명에 .r<i> 가 붙는다.
# meta.json 은 실행이 끝난 뒤 쓴다 — model(첫 실제 결과의 modelUsage 중 출력 토큰 최대 키)·claude_version 이 그때 정해진다.
# ponytail: 비적대적 전제 — 대상 프로세스는 사용자 권한 그대로라 저장소 밖 파일을 읽을 수 있다 (계획서 Global Constraints).
set -eu
unset MAKELEVEL   # 러너를 make 아래에서 띄워도 평가 대상의 직접 receipt 호출이 실행 증거로 둔갑하지 않게 — via_make 는 fixture 의 make 만 준다
E=$(cd "$(dirname "$0")" && pwd)
ROOT=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
SHA=""; OUT=""; SEALED=""; DRY=0; MAT_CASE=""; MAT_WORK=""; MANIFEST_DIR=""; REPEAT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) SHA=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --sealed) SEALED=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    --repeat) REPEAT=$2; REPEAT_RAW=$2; shift 2;;
    --materialize) MAT_CASE=$2; MAT_WORK=$3; shift 3;;
    --sealed-manifest) MANIFEST_DIR=$2; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
for c in jq git timeout shasum; do command -v "$c" >/dev/null 2>&1 || { echo "$c 가 없다" >&2; exit 2; }; done
REPEAT=$(printf '%s' "$REPEAT" | sed 's/^0*//'); [ -n "$REPEAT" ] || REPEAT=0   # 앞의 0 을 지운다 — 산술 $((…)) 은 08 을 8진수로 읽어 실패한다
case "$REPEAT" in *[!0-9]*|0) echo "--repeat 는 1 이상의 정수다: ${REPEAT_RAW:-$REPEAT}" >&2; exit 2;; esac

sealed_manifest() { # <dir> → "사례명<TAB>sha256" 줄들. 상대경로 + 파일 내용만 해시한다 — mtime·소유자에 무관
  for d in "$1"/*/; do
    n=$(basename "$d")
    h=$( ( cd "$d" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; shasum -a 256 < "$f" | cut -d' ' -f1; done ) | shasum -a 256 | cut -d' ' -f1 )
    printf '%s\t%s\n' "$n" "$h"
  done
}
if [ -n "$MANIFEST_DIR" ]; then sealed_manifest "$MANIFEST_DIR"; exit 0; fi

[ -n "$SHA" ] || { echo "--harness <sha> 가 필요하다" >&2; exit 2; }
git -C "$ROOT" rev-parse --verify -q "$SHA^{commit}" >/dev/null || { echo "하네스 커밋이 아니다: $SHA" >&2; exit 2; }
[ "$DRY" = 1 ] || [ -n "$MAT_CASE" ] || command -v claude >/dev/null 2>&1 || { echo "claude 가 없다" >&2; exit 2; }

materialize() { # <case dir> <work dir>
  mkdir -p "$2"
  TARF=$(mktemp)
  # git archive 는 없는 pathspec 에 실패한다 — 그 커밋에 실재하는 것만 넘긴다 (CLAUDE.md 없는 저장소가 있다)
  PATHS=$(git -C "$ROOT" ls-tree --name-only "$SHA" -- .claude CLAUDE.md)
  [ -n "$PATHS" ] || { echo "하네스 커밋에 .claude 도 CLAUDE.md 도 없다: $SHA" >&2; exit 2; }
  git -C "$ROOT" archive -o "$TARF" "$SHA" -- $PATHS   # 파이프가 아니라 파일로 — 실패가 rc 에 남는다
  tar -xf "$TARF" -C "$2"; rm -f "$TARF"
  rm -rf "$2/.claude/harness"
  # 프로젝트 수준으로 켠 플러그인이 평가 대상 세션에 실리지 않게 한다 — 클린룸
  if [ -f "$2/.claude/settings.json" ]; then
    jq 'del(.enabledPlugins)' "$2/.claude/settings.json" > "$2/.claude/settings.json.tmp" && mv "$2/.claude/settings.json.tmp" "$2/.claude/settings.json"
  fi
  cp -R "$1/fixture/." "$2/"
  cp "$E/receipt.sh" "$2/.harness-receipt.sh"; chmod +x "$2/.harness-receipt.sh"
}
if [ -n "$MAT_CASE" ]; then materialize "$MAT_CASE" "$MAT_WORK"; exit 0; fi
[ -n "$OUT" ] || { echo "--out <dir> 가 필요하다" >&2; exit 2; }

# 실행 전 검사 — 보고서와 게이트가 대조할 값들
[ -z "$(git -C "$ROOT" status --porcelain -- .claude/harness/cases .claude/harness/sealed.manifest)" ] || { echo ".claude/harness/cases 또는 sealed.manifest 가 dirty 다 — 커밋한 사례만 평가한다" >&2; exit 2; }
SUITE=$(git -C "$ROOT" rev-parse --verify -q "HEAD:.claude/harness/cases") || { echo "HEAD 에 .claude/harness/cases 가 없다" >&2; exit 2; }
SEALED_DIGEST=none
mkdir -p "$OUT"
if [ -n "$SEALED" ]; then
  sealed_manifest "$SEALED" > "$OUT/sealed.manifest.actual"
  cmp -s "$OUT/sealed.manifest.actual" "$ROOT/.claude/harness/sealed.manifest" || { echo "봉인 묶음이 sealed.manifest 와 다르다 — 묶음을 되돌리거나 manifest 를 새 커밋으로 갱신한다" >&2; exit 2; }
  SEALED_DIGEST=$(shasum -a 256 "$ROOT/.claude/harness/sealed.manifest" | cut -d' ' -f1)
fi
MANAGED=false; [ -f "/Library/Application Support/ClaudeCode/managed-settings.json" ] && MANAGED=true
if [ "$DRY" = 1 ]; then CLAUDE_VERSION=dry-run; MODEL=dry-run; else CLAUDE_VERSION=$(claude --version 2>/dev/null | awk '{print $1}'); MODEL=none; fi
[ -n "$CLAUDE_VERSION" ] || CLAUDE_VERSION=unknown
rm -f "$OUT/meta.json"   # 끝난 뒤 다시 쓴다 — 중간에 멈춘 실행은 meta 가 없어 보고서를 만들 수 없다
: > "$OUT/results.jsonl"
SCHEMA=$(cat "$E/verdict.schema.json")

run_case() { # <case dir> <run index>
  name=$(basename "$1"); i=$2
  if [ "$REPEAT" = 1 ]; then stem="$OUT/$name"; else stem="$OUT/$name.r$i"; fi
  work=$(mktemp -d)
  materialize "$1" "$work"
  rec="$stem.receipts.jsonl"; : > "$rec"
  res="$stem.result.json"
  if [ "$DRY" = 1 ]; then
    # 모델 없이도 fixture 의 make 를 돌려 영수증을 실제로 만든다 — grade 의 require_targets 검사가 그것을 본다
    for t in $(jq -r '.require_targets[]?' "$1/expect.json"); do ( cd "$work" && EVAL_RECEIPTS="$rec" make "$t" >/dev/null 2>&1 ) || true; done
    cp "$1/dry-run.result.json" "$res" 2>/dev/null || : > "$res"
  else
    ( cd "$work" && EVAL_RECEIPTS="$rec" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
      timeout 300 claude -p "$(cat "$1/prompt.md")" \
        --output-format json --json-schema "$SCHEMA" \
        --setting-sources project --settings "$E/settings.json" \
        --allowedTools Bash,Read,Grep --max-turns 15 --max-budget-usd 1 --no-session-persistence \
        > "$res" 2> "$stem.stderr" ) || true
    if [ "$MODEL" = none ] && [ -s "$res" ]; then
      MODEL=$(jq -r '(.modelUsage // {}) | to_entries | map(select(.value.outputTokens != null)) | max_by(.value.outputTokens) | .key // "unknown"' "$res" 2>/dev/null || echo unknown)
      [ -n "$MODEL" ] || MODEL=unknown
    fi
  fi
  sh "$E/grade.sh" "$1" "$res" "$rec" | jq -c --argjson r "$i" '. + {run:$r}' >> "$OUT/results.jsonl"
  rm -rf "$work"
}

for c in "$ROOT"/.claude/harness/cases/*/; do i=1; while [ "$i" -le "$REPEAT" ]; do run_case "${c%/}" "$i"; i=$((i+1)); done; done
if [ -n "$SEALED" ]; then for c in "$SEALED"/*/; do i=1; while [ "$i" -le "$REPEAT" ]; do run_case "${c%/}" "$i"; i=$((i+1)); done; done; fi
[ "$MODEL" = none ] && MODEL=unknown
jq -n --arg h "$SHA" --arg s "$SUITE" --arg d "$SEALED_DIGEST" --argjson m "$MANAGED" --argjson r "$REPEAT" --arg mo "$MODEL" --arg v "$CLAUDE_VERSION" \
  --arg ts "$(date +%Y-%m-%dT%H:%M:%S%z)" \
  '{harness_sha:$h,suite_sha:$s,sealed_digest:$d,managed:$m,repeat:$r,model:$mo,claude_version:$v,generated_at:$ts}' > "$OUT/meta.json"
jq -r '"\(.case)\t\(.run)\t\(.verdict)\t\(.reason)"' "$OUT/results.jsonl"
