#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-central-migration-control-plane/config/repos.json}"
TARGET_REPO="${2:-}"

python3 - "$CONFIG_FILE" "$TARGET_REPO" << 'PY'
import json
import re
import sys

config_file = sys.argv[1]
target_repo = sys.argv[2]

with open(config_file, "r", encoding="utf-8") as f:
    data = json.load(f)

repos = data.get("repositories", [])
selected = []
def normalize_repo_name(repo_obj):
    repo_name = (repo_obj.get("repo") or "").strip()
    if repo_name:
        return repo_name
    repo_url = (repo_obj.get("repo_url") or repo_obj.get("github_url") or "").strip()
    if not repo_url:
        return ""
    m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", repo_url)
    return m.group(1) if m else ""

for repo in repos:
    if not repo.get("enabled", False):
        continue
    normalized = normalize_repo_name(repo)
    if not normalized:
        continue
    if target_repo and normalized != target_repo:
        continue
    enriched = dict(repo)
    enriched["repo"] = normalized
    selected.append(enriched)

print(json.dumps({"include": selected}, separators=(",", ":")))
PY
