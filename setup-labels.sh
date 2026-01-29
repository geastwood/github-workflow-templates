#!/usr/bin/env bash
set -euo pipefail

# Creates all required GitHub labels for the workflow templates.
# Usage: ./setup-labels.sh [owner/repo]
#
# If no repo is specified, uses the current directory's git remote.
# Requires: gh CLI authenticated

if [ -n "${1:-}" ]; then
  REPO="$1"
else
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || {
    echo "Error: Could not detect repo. Pass owner/repo as argument or run from a git repo."
    exit 1
  }
fi

echo "Setting up labels for $REPO..."

# Define labels: name|color|description
LABELS=(
  "agent:pending|0E8A16|Task waiting to be picked up by an agent"
  "agent:in-progress|1D76DB|Agent is actively working on this"
  "agent:done|6F42C1|Agent completed the task"
  "agent:blocked|D93F0B|Agent is blocked and needs help"
  "agent:tests|FBCA04|Test coverage task"
  "agent:docs|0075CA|Documentation task"
  "agent:refactor|E4E669|Code quality / refactoring task"
  "agent:feature|A2EEEF|Feature implementation task"
  "agent:bugfix|D73A4A|Bug fix task"
  "agent:solved-merge-conflict|0E8A16|Merge conflict auto-resolved by agent"
  "needs-human|B60205|Requires human intervention"
  "ci-passed|0E8A16|All CI checks passed"
  "released|6F42C1|Merged and released"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color description <<< "$entry"

  if gh label list --repo "$REPO" --json name --jq '.[].name' | grep -qx "$name"; then
    echo "  [exists] $name"
  else
    gh label create "$name" --color "$color" --description "$description" --repo "$REPO"
    echo "  [created] $name"
  fi
done

echo "Done. All labels are set up for $REPO."
