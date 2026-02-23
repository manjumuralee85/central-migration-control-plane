#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-central-migration-control-plane/config/repos.json}"
TARGET_REPO="${2:-}"

python3 - "$CONFIG_FILE" "$TARGET_REPO" << 'PY'
import json
import sys

config_file = sys.argv[1]
target_repo = sys.argv[2]

with open(config_file, "r", encoding="utf-8") as f:
    data = json.load(f)

repos = data.get("repositories", [])
selected = []
for repo in repos:
    if not repo.get("enabled", False):
        continue
    if target_repo and repo.get("repo") != target_repo:
        continue
    selected.append(repo)

print(json.dumps({"include": selected}, separators=(",", ":")))
PY
