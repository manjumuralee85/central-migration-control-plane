# Central Migration Control Plane

This folder is a template for a dedicated central repository that can orchestrate Java 21 + Spring Boot migration across 50+ repos.

## What it does

- Reads repositories from `config/repos.json`
- Mode `direct_migrate`:
  - Checks out each target repo directly from central workflow
  - Applies migration profile code/pom/properties changes
  - Runs build/tests/CVE scan
  - Creates PR in target repo with actual code changes
- Mode `sync_templates`:
  - Opens PRs in target repos with:
    - `.github/workflows/convert-to-spring-boot.yml`
    - `.github/dependency-check-suppressions.xml`
    - `.github/rewrite/migration-recipe.yml`
- Mode `trigger_migration`:
  - Dispatches `convert-to-spring-boot.yml` in each target repo

## Required GitHub secret

- `MIGRATION_BOT_TOKEN` (PAT or GitHub App token) with permission to:
  - read/write contents
  - create pull requests
  - trigger workflows in target repos

## Configure repositories

Edit `config/repos.json`:

```json
{
  "repositories": [
    {
      "repo": "manjumuralee85/spring-petclinic",
      "default_branch": "main",
      "enabled": true,
      "migration_profile": "spring-petclinic",
      "java_version": "21",
      "spring_boot_version": "3.3.6"
    }
  ]
}
```

You can add more repos as additional objects in the same array.
`migration_profile` is optional if auto-detection can identify the app; otherwise set it explicitly.

## How to use

1. Create a dedicated repo, e.g. `org/migration-control-plane`.
2. Copy all files from this folder to that repo root.
3. Add secret `MIGRATION_BOT_TOKEN`.
4. Run workflow `Migration Orchestrator`:
   - Recommended: `mode=direct_migrate` (no target-repo workflow required)
   - Optional: `mode=sync_templates` then `mode=trigger_migration`

## Notes

- Keep `templates/convert-to-spring-boot.yml` and `templates/migration-recipe.yml` as centralized sources.
- Adding a new repo is only a config change in `config/repos.json`.
- The workflow executes centralized OpenRewrite recipe `com.organization.migrations.Java21SpringBootBaseline` from `.github/rewrite/migration-recipe.yml`.
- Migration logic per app family is defined by `migration_profile` and implemented in `scripts/migrate-repo.sh`.
- Auto-detection is implemented in `scripts/detect-profile.sh`. If detection returns unsupported, add a specific `migration_profile` and corresponding migration logic.
