#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$1"

cd "$REPO_DIR"

# Current implemented migration profile
if [[ -f "pom.xml" ]] && rg -q "springframework\.samples\.petclinic|Spring Framework Petclinic|spring/data-access\.properties|src/main/resources/spring/business-config\.xml" -S .; then
  echo "spring-petclinic"
  exit 0
fi

if [[ -f "pom.xml" || -f "build.gradle" || -f "build.gradle.kts" ]]; then
  echo "generic-java-service"
  exit 0
fi

echo "unsupported"
