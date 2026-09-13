#!/usr/bin/env python3
"""플러그인 매니페스트와 문서 참조를 검사한다. 통과하면 종료코드 0."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = []

# 1. 매니페스트가 유효한 JSON 이고, 가리키는 source 가 실재한다
def load_json(path, label):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        errors.append(f"{label}: 파일이 없다 — {path}")
    except json.JSONDecodeError as exc:
        errors.append(f"{label}: JSON 이 깨졌다 — {exc}")
    return None

market = load_json(ROOT / ".claude-plugin/marketplace.json", "marketplace.json") or {}
for entry in market.get("plugins", []):
    name = entry.get("name", "<이름 없음>")
    source = entry.get("source")
    if not source:
        errors.append(f"marketplace.json: {name} 항목에 source 가 없다")
        continue
    src = ROOT / source
    if not src.is_dir():
        errors.append(f"marketplace.json: source 가 없다 — {source}")
        continue
    load_json(src / ".claude-plugin/plugin.json", f"{name}/plugin.json")

# 2. 설치처에 없는 저장소 경로를 참조하지 않는다
STALE = re.compile(r"`\.claude/(rules|commands|skills)/")
# 3. ${CLAUDE_PLUGIN_ROOT} 로 가리킨 경로가 실재한다
PLUGIN_REF = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\s`)]+)")

for doc in (ROOT / "plugins").rglob("*.md"):
    text = doc.read_text()
    rel = doc.relative_to(ROOT)
    for m in STALE.finditer(text):
        errors.append(f"{rel}: 설치처에 없는 경로를 참조한다 — {m.group(0)}")
    plugin_root = doc
    while plugin_root.parent != ROOT / "plugins":
        plugin_root = plugin_root.parent
    for m in PLUGIN_REF.finditer(text):
        target = plugin_root / m.group(1)
        if not target.exists():
            errors.append(f"{rel}: 참조 대상이 없다 — {m.group(1)}")

# 4. 모든 SKILL.md 에 name 과 description 이 있다
for skill in (ROOT / "plugins").rglob("skills/*/SKILL.md"):
    text = skill.read_text()
    head = text.split("---")[1] if text.startswith("---") else ""
    for key in ("name", "description"):
        if not re.search(rf"^{key}:", head, re.M):
            errors.append(f"{skill.relative_to(ROOT)}: frontmatter 에 {key}: 가 없다")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("통과")
