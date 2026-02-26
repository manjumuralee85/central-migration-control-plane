#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Run centralized migration locally against a local repository (no GitHub Actions).

Usage:
  scripts/run-local-migration.sh \
    --target-repo-path /abs/path/to/target-repo \
    [--profile <migration-profile>] \
    [--java-version <11|17|21>] \
    [--spring-boot-version <version>] \
    [--control-plane-dir /abs/path/to/control-plane]

Examples:
  scripts/run-local-migration.sh \
    --target-repo-path /Users/me/work/jm-java8-boot-1 \
    --java-version 11 \
    --spring-boot-version 2.7.18

  scripts/run-local-migration.sh \
    --target-repo-path /Users/me/work/spring-petclinic \
    --profile spring-petclinic \
    --java-version 21 \
    --spring-boot-version 3.3.6
EOF
}

TARGET_REPO_PATH=""
PROFILE=""
TARGET_JAVA_VERSION="21"
TARGET_BOOT_VERSION="3.3.6"
CONTROL_PLANE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-repo-path)
      TARGET_REPO_PATH="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --java-version)
      TARGET_JAVA_VERSION="$2"
      shift 2
      ;;
    --spring-boot-version)
      TARGET_BOOT_VERSION="$2"
      shift 2
      ;;
    --control-plane-dir)
      CONTROL_PLANE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_REPO_PATH" ]]; then
  echo "Missing required argument: --target-repo-path"
  usage
  exit 1
fi

if [[ ! -d "$TARGET_REPO_PATH" ]]; then
  echo "Target repo path does not exist: $TARGET_REPO_PATH"
  exit 1
fi

if [[ ! -f "$TARGET_REPO_PATH/pom.xml" && ! -f "$TARGET_REPO_PATH/build.gradle" && ! -f "$TARGET_REPO_PATH/build.gradle.kts" ]]; then
  echo "No supported build file found in $TARGET_REPO_PATH (pom.xml/build.gradle/build.gradle.kts)."
  exit 1
fi

if [[ "$TARGET_JAVA_VERSION" != "11" && "$TARGET_JAVA_VERSION" != "17" && "$TARGET_JAVA_VERSION" != "21" ]]; then
  echo "Unsupported --java-version: $TARGET_JAVA_VERSION (allowed: 11, 17, 21)"
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  PROFILE="$("$CONTROL_PLANE_DIR/scripts/detect-profile.sh" "$TARGET_REPO_PATH")"
fi

if [[ "$PROFILE" == "unsupported" ]]; then
  echo "Could not detect a supported profile. Pass --profile explicitly."
  exit 1
fi

if [[ "$TARGET_JAVA_VERSION" -le 11 && "$TARGET_BOOT_VERSION" =~ ^3\. ]]; then
  echo "Java $TARGET_JAVA_VERSION cannot use Spring Boot $TARGET_BOOT_VERSION. Falling back to 2.7.18 for local run."
  TARGET_BOOT_VERSION="2.7.18"
fi

echo "Local migration starting"
echo "  target repo       : $TARGET_REPO_PATH"
echo "  profile           : $PROFILE"
echo "  target java       : $TARGET_JAVA_VERSION"
echo "  spring boot input : $TARGET_BOOT_VERSION"
echo "  control plane dir : $CONTROL_PLANE_DIR"

mkdir -p "$TARGET_REPO_PATH/.github/rewrite"

ANALYSIS_FILE="$TARGET_REPO_PATH/.github/rewrite/analysis.json"
RECIPE_FILE="$TARGET_REPO_PATH/.github/rewrite/migration-recipe.yml"
REPORT_FILE="$TARGET_REPO_PATH/.github/rewrite/dependency-upgrade-report.md"

"$CONTROL_PLANE_DIR/scripts/analyze-repo.sh" "$TARGET_REPO_PATH" > "$ANALYSIS_FILE"
"$CONTROL_PLANE_DIR/scripts/generate-recipe.sh" "$ANALYSIS_FILE" "$TARGET_BOOT_VERSION" "$TARGET_JAVA_VERSION" "$RECIPE_FILE" "$CONTROL_PLANE_DIR/templates/migration-recipe.yml"
"$CONTROL_PLANE_DIR/scripts/generate-upgrade-report.sh" "$ANALYSIS_FILE" "$TARGET_BOOT_VERSION" "$TARGET_JAVA_VERSION" "$REPORT_FILE"
"$CONTROL_PLANE_DIR/scripts/migrate-repo.sh" "$TARGET_REPO_PATH" "$PROFILE" "$TARGET_BOOT_VERSION" "$CONTROL_PLANE_DIR" "$ANALYSIS_FILE" "$TARGET_JAVA_VERSION"

echo
echo "Local migration completed."
echo "Review generated files:"
echo "  $ANALYSIS_FILE"
echo "  $RECIPE_FILE"
echo "  $REPORT_FILE"
echo
echo "If the target repo is a git working tree, inspect changes with:"
echo "  git -C \"$TARGET_REPO_PATH\" status"
echo "  git -C \"$TARGET_REPO_PATH\" diff"
