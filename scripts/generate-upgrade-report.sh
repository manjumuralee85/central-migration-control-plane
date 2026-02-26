#!/usr/bin/env bash
set -euo pipefail

ANALYSIS_JSON="$1"
TARGET_SPRING_BOOT_VERSION="${2:-3.3.6}"
TARGET_JAVA_VERSION="${3:-21}"
OUTPUT_REPORT="${4:-.github/rewrite/dependency-upgrade-report.md}"

python3 - "$ANALYSIS_JSON" "$TARGET_SPRING_BOOT_VERSION" "$TARGET_JAVA_VERSION" "$OUTPUT_REPORT" << 'PY'
import json
import sys
from pathlib import Path

analysis_path = Path(sys.argv[1])
target_boot = sys.argv[2]
target_java = int(sys.argv[3])
output_path = Path(sys.argv[4])

data = json.loads(analysis_path.read_text(encoding="utf-8"))
flags = data.get("flags", {})
deps = data.get("dependencies", [])

def add(lines, text=""):
    lines.append(text)

target_java_recipe = (
    "com.organization.catalog.Java21Upgrade"
    if target_java >= 21 else
    "com.organization.catalog.Java17Upgrade"
    if target_java >= 17 else
    "com.organization.catalog.Java11Upgrade"
    if target_java >= 11 else
    "(none)"
)

planned = [target_java_recipe]
if flags.get("has_spring") or flags.get("has_spring_boot"):
    if target_java >= 17:
        planned.append("com.organization.catalog.SpringBoot3Core")
        if target_boot.startswith("3.4"):
            planned.append("com.organization.catalog.SpringBootDependencies_3_4")
        elif target_boot.startswith("3.2"):
            planned.append("com.organization.catalog.SpringBootDependencies_3_2")
        else:
            planned.append("com.organization.catalog.SpringBootDependencies_3_3")
        if flags.get("has_javax") or flags.get("has_jakarta"):
            planned.append("com.organization.catalog.JavaxToJakarta")
            planned.append("com.organization.catalog.JakartaEeModernization")
            planned.append("com.organization.catalog.JakartaAnnotationApi")
    else:
        planned.append("com.organization.catalog.SpringBoot2Track")
        planned.append("com.organization.catalog.SpringBoot2Java11Cleanup")
        planned.append("com.organization.catalog.SpringBootDependencies_2_7")
if flags.get("has_dropwizard"):
    planned.append(
        "com.organization.catalog.DropwizardModernTrack"
        if target_java >= 17 else
        "com.organization.catalog.DropwizardJava11Track"
    )
if flags.get("has_log4j"):
    planned.append("com.organization.catalog.Log4jModernization")
planned.append("com.organization.catalog.CommonDependencyModernization")

lines = []
add(lines, "# Migration Dependency Analysis")
add(lines)
add(lines, f"- Build tool: `{data.get('build_tool', 'unknown')}`")
add(lines, f"- Detected Java version: `{data.get('java_version') or 'unknown'}`")
add(lines, f"- Target Java version: `{target_java}`")
add(lines, f"- Detected Spring Boot version: `{data.get('spring_boot_version') or 'not detected'}`")
add(lines, f"- Target Spring Boot version input: `{target_boot}`")
add(lines)
add(lines, "## Detected Framework Flags")
for k in sorted(flags.keys()):
    add(lines, f"- `{k}`: `{bool(flags.get(k))}`")
add(lines)
add(lines, "## Planned Upgrade Actions")
for item in planned:
    add(lines, f"- `{item}`")
add(lines)
add(lines, "## Detected Dependencies")
if deps:
    for dep in deps:
        gv = f"{dep.get('groupId','')}:{dep.get('artifactId','')}"
        vv = dep.get("version") or "(managed/unspecified)"
        add(lines, f"- `{gv}` -> `{vv}`")
else:
    add(lines, "- No explicit dependencies parsed from build files.")

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
