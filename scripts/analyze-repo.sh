#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$1"

python3 - "$REPO_DIR" << 'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

repo_dir = Path(sys.argv[1]).resolve()

analysis = {
    "build_tool": "unknown",
    "java_version": None,
    "spring_boot_version": None,
    "dependencies": [],
    "flags": {
        "has_spring": False,
        "has_spring_boot": False,
        "has_dropwizard": False,
        "has_jakarta": False,
        "has_javax": False,
        "has_log4j": False,
    },
}

pom = repo_dir / "pom.xml"
gradle = repo_dir / "build.gradle"
gradle_kts = repo_dir / "build.gradle.kts"

def safe_text(node):
    return (node.text or "").strip() if node is not None else None

def resolve_placeholder(value, props):
    if not value:
        return value
    m = re.fullmatch(r"\$\{([^}]+)\}", value.strip())
    if m:
        return props.get(m.group(1), value)
    return value

def analyze_maven():
    tree = ET.parse(pom)
    root = tree.getroot()
    ns_uri = root.tag[root.tag.find("{")+1:root.tag.find("}")]
    ns = {"m": ns_uri}

    analysis["build_tool"] = "maven"
    props = {}
    for prop in root.findall("./m:properties/*", ns):
        key = prop.tag.split("}", 1)[-1]
        props[key] = safe_text(prop)

    java_version = props.get("java.version")
    if not java_version:
        source = root.find(".//m:plugin[m:artifactId='maven-compiler-plugin']/m:configuration/m:source", ns)
        java_version = safe_text(source)
    analysis["java_version"] = java_version

    parent_boot = root.find("./m:parent[m:groupId='org.springframework.boot']/m:version", ns)
    if parent_boot is not None:
        analysis["spring_boot_version"] = resolve_placeholder(safe_text(parent_boot), props)
        analysis["flags"]["has_spring_boot"] = True

    deps = []
    for dep in root.findall(".//m:dependencies/m:dependency", ns):
        group = safe_text(dep.find("m:groupId", ns)) or ""
        artifact = safe_text(dep.find("m:artifactId", ns)) or ""
        version = resolve_placeholder(safe_text(dep.find("m:version", ns)), props)
        if not group or not artifact:
            continue
        deps.append({"groupId": group, "artifactId": artifact, "version": version})
        if group.startswith("org.springframework") or group.startswith("org.springframework.boot"):
            analysis["flags"]["has_spring"] = True
        if group.startswith("org.springframework.boot"):
            analysis["flags"]["has_spring_boot"] = True
        if group.startswith("io.dropwizard"):
            analysis["flags"]["has_dropwizard"] = True
        if group.startswith("jakarta.") or artifact.startswith("jakarta."):
            analysis["flags"]["has_jakarta"] = True
        if group.startswith("javax.") or artifact.startswith("javax."):
            analysis["flags"]["has_javax"] = True
        if group.startswith("org.apache.logging.log4j"):
            analysis["flags"]["has_log4j"] = True
    analysis["dependencies"] = deps

def analyze_gradle():
    analysis["build_tool"] = "gradle"
    text = ""
    if gradle.exists():
        text = gradle.read_text(encoding="utf-8", errors="ignore")
    elif gradle_kts.exists():
        text = gradle_kts.read_text(encoding="utf-8", errors="ignore")

    m = re.search(r"(?:sourceCompatibility|targetCompatibility)\s*=\s*['\"]?(\d+)", text)
    if m:
        analysis["java_version"] = m.group(1)

    boot = re.search(r"id\s+['\"]org\.springframework\.boot['\"]\s+version\s+['\"]([^'\"]+)['\"]", text)
    if boot:
        analysis["spring_boot_version"] = boot.group(1)
        analysis["flags"]["has_spring_boot"] = True

    dep_matches = re.findall(r"['\"]([A-Za-z0-9_.-]+):([A-Za-z0-9_.-]+):([^'\"]+)['\"]", text)
    deps = []
    for group, artifact, version in dep_matches:
        deps.append({"groupId": group, "artifactId": artifact, "version": version})
        if group.startswith("org.springframework") or group.startswith("org.springframework.boot"):
            analysis["flags"]["has_spring"] = True
        if group.startswith("org.springframework.boot"):
            analysis["flags"]["has_spring_boot"] = True
        if group.startswith("io.dropwizard"):
            analysis["flags"]["has_dropwizard"] = True
        if group.startswith("jakarta.") or artifact.startswith("jakarta."):
            analysis["flags"]["has_jakarta"] = True
        if group.startswith("javax.") or artifact.startswith("javax."):
            analysis["flags"]["has_javax"] = True
        if group.startswith("org.apache.logging.log4j"):
            analysis["flags"]["has_log4j"] = True
    analysis["dependencies"] = deps

if pom.exists():
    analyze_maven()
elif gradle.exists() or gradle_kts.exists():
    analyze_gradle()

has_javax_imports = False
has_jakarta_imports = False
for base in ("src/main/java", "src/test/java"):
    src_dir = repo_dir / base
    if not src_dir.exists():
        continue
    for p in src_dir.rglob("*.java"):
        try:
            txt = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        if "import javax." in txt:
            has_javax_imports = True
        if "import jakarta." in txt:
            has_jakarta_imports = True
        if has_javax_imports and has_jakarta_imports:
            break
    if has_javax_imports and has_jakarta_imports:
        break

analysis["flags"]["has_javax"] = analysis["flags"]["has_javax"] or has_javax_imports
analysis["flags"]["has_jakarta"] = analysis["flags"]["has_jakarta"] or has_jakarta_imports

print(json.dumps(analysis, indent=2))
PY
