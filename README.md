# GitHub Workflow Templates

Reusable GitHub Actions workflows for use across multiple repositories.

## Workflows

| Workflow | Description |
|----------|-------------|
| `ci.yml` | CI pipeline (build, lint, type-check, test) |
| `agent-worker.yml` | Autonomous agent that works on labeled issues |
| `agent-coordinator.yml` | Scans codebase and creates maintenance issues |
| `agent-ci-fix.yml` | Auto-fixes CI failures on agent branches |
| `claude.yml` | Responds to `@claude` mentions in issues/PRs |
| `claude-code-review.yml` | Automated PR code review |
| `pr-merged-labels.yml` | Adds `released` label to issues when PR merges |

## Setup

Before using these workflows, each consuming repo needs the required GitHub labels. Run the setup script:

```bash
# From the template repo directory
./setup-labels.sh geastwood/rolekit-ai
./setup-labels.sh geastwood/unisun-hub

# Or from inside a repo (auto-detects)
./setup-labels.sh
```

This creates all required labels:

| Label | Purpose |
|-------|---------|
| `agent:pending` | Task waiting for an agent |
| `agent:in-progress` | Agent is working on it |
| `agent:done` | Agent completed the task |
| `agent:blocked` | Agent needs help |
| `agent:tests` | Test coverage task |
| `agent:docs` | Documentation task |
| `agent:refactor` | Refactoring task |
| `agent:feature` | Feature implementation |
| `agent:bugfix` | Bug fix task |
| `needs-human` | Requires human intervention |
| `ci-passed` | All CI checks passed |
| `released` | Merged and released |

## Usage

Each consuming repo creates thin caller workflows that reference these templates.

**Important**: Reusable workflows don't inherit the caller's `github.event` context. Callers must explicitly pass event data as inputs. See examples below.

### Example: CI

```yaml
# .github/workflows/ci.yml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    uses: geastwood/github-workflow-templates/.github/workflows/ci.yml@main
    with:
      package_manager: pnpm
      build_command: "pnpm build"
      event_name: ${{ github.event_name }}
      pr_number: ${{ github.event.pull_request.number && format('{0}', github.event.pull_request.number) || '' }}
      env_vars: |
        DATABASE_URL=postgresql://ci:ci@localhost:5432/ci_db
        NODE_ENV=test
    secrets: inherit
```

### Example: Agent Worker

```yaml
# .github/workflows/agent-worker.yml
name: Agent Worker
on:
  issues:
    types: [labeled]

concurrency:
  group: agent-worker-${{ github.event.issue.number }}
  cancel-in-progress: false

jobs:
  worker:
    uses: geastwood/github-workflow-templates/.github/workflows/agent-worker.yml@main
    with:
      agent_prompt: "You are working on MyProject, a Next.js application."
      issue_number: ${{ format('{0}', github.event.issue.number) }}
      issue_title: ${{ github.event.issue.title }}
      issue_body: ${{ github.event.issue.body }}
      label_name: ${{ github.event.label.name }}
      issue_state: ${{ github.event.issue.state }}
      event_action: ${{ github.event.action }}
      env_vars: |
        DATABASE_URL=postgresql://ci:ci@localhost:5432/ci_db
    secrets: inherit
```

## Issue Templates

Issue templates in `issue-templates/` must be manually copied into each repo's `.github/ISSUE_TEMPLATE/` directory — they cannot be shared via reusable workflows.

```bash
cp issue-templates/*.md /path/to/your-repo/.github/ISSUE_TEMPLATE/
```

## Configurable Inputs

### Common inputs (CI, Agent Worker, Agent CI Fix)

| Input | Default | Description |
|-------|---------|-------------|
| `node_version` | `"20"` | Node.js version |
| `package_manager` | `"pnpm"` | pnpm, npm, or yarn |
| `pnpm_version` | `"9"` | pnpm version (when using pnpm) |
| `install_command` | `"pnpm install --frozen-lockfile"` | Install command |
| `build_command` | `"pnpm build"` | Build command |
| `lint_command` | `"pnpm lint"` | Lint command |
| `typecheck_command` | `"pnpm type-check"` | Type check command |
| `env_vars` | `""` | Newline-separated KEY=VALUE env vars |

### Agent-specific inputs

| Input | Default | Description |
|-------|---------|-------------|
| `agent_prompt` | `""` | Custom prompt with project context |
| `max_issues_per_run` | `3` | Max issues coordinator creates |
| `max_retries` | `3` | Max CI fix attempts |
| `agent_branch_prefixes` | `"agent/,claude/"` | Branch prefixes for auto-fix |

### Required Secrets

- `CLAUDE_CODE_OAUTH_TOKEN` — Required for all Claude-powered workflows
- `GITHUB_TOKEN` — Automatically provided by GitHub Actions

## Kill Switch

To pause all agent workflows in a repo, create a file at `.github/AGENTS_PAUSED`:

```bash
echo "Paused for maintenance" > .github/AGENTS_PAUSED
git add .github/AGENTS_PAUSED && git commit -m "Pause agents" && git push
```

Remove it to resume:

```bash
git rm .github/AGENTS_PAUSED && git commit -m "Resume agents" && git push
```

The agent-worker, agent-coordinator, and agent-ci-fix workflows all check for this file before proceeding.
