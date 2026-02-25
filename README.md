# Central Migration Control Plane

This folder is a template for a dedicated central repository that can orchestrate Java migrations (11/17/21) plus framework/dependency modernization across 50+ repos.

## What it does

- Reads repositories from `config/repos.json`
- Mode `direct_migrate`:
  - Checks out each target repo directly from central workflow
  - Detects current Java/framework/dependency versions (Spring Boot, Dropwizard, Jakarta, Log4j, etc.)
  - Generates repository-specific OpenRewrite recipe config
  - Generates a dependency analysis report artifact (`analysis.json` + markdown summary)
  - Applies migration profile patches plus OpenRewrite code/dependency upgrades
  - Runs build/tests
  - Creates PR in target repo with actual code changes
- Mode `sync_templates`:
  - Opens PRs in target repos with:
    - `.github/workflows/convert-to-spring-boot.yml`
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
      "java_version": "11",
      "spring_boot_version": "3.3.6"
    },
    {
      "repo_url": "https://github.com/your-org/another-service.git",
      "default_branch": "main",
      "enabled": true,
      "spring_boot_version": "3.3.6"
    }
  ]
}
```

You can add more repos as additional objects in the same array.
`repo` (owner/name) is recommended; full GitHub URL is also supported via `repo_url` (or `github_url`).
`migration_profile` is optional if auto-detection can identify the app; otherwise set it explicitly.

## How to use

1. Create a dedicated repo, e.g. `org/migration-control-plane`.
2. Copy all files from this folder to that repo root.
3. Add secret `MIGRATION_BOT_TOKEN`.
4. Run workflow `Migration Orchestrator`:
   - Recommended: `mode=direct_migrate` (no target-repo workflow required)
   - Set `target_java_version` (11/17/21) for the migration goal
   - Optional: `mode=sync_templates` then `mode=trigger_migration`

## Notes

- Keep `templates/convert-to-spring-boot.yml` and `templates/migration-recipe.yml` as centralized sources.
- Adding a new repo is only a config change in `config/repos.json`.
- The central workflow now generates `.github/rewrite/migration-recipe.yml` per target repository using `scripts/analyze-repo.sh` + `scripts/generate-recipe.sh`.
- The generated recipe includes target Java upgrade plus Spring Boot / Dropwizard / Jakarta / common dependency updates when detected and compatible with target Java.
- Centralized reusable OpenRewrite recipe blocks are maintained in `templates/migration-recipe.yml` (catalog), while `generate-recipe.sh` only composes per-repo selector recipes from that catalog.
- Each direct migration run publishes dependency analysis artifacts so you can inspect detected dependencies and planned upgrades before merging.
- Migration logic per app family is defined by `migration_profile` and implemented in `scripts/migrate-repo.sh`.
- Auto-detection is implemented in `scripts/detect-profile.sh`. If detection returns unsupported, add a specific `migration_profile` and corresponding migration logic.
