#!/usr/bin/env bash
set -euo pipefail

# Import an existing GitHub repository into the OpenTofu state.
# Prompts for the repository name and the GitHub owner (default: wavermartijn).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OWNER="${OWNER:-wavermartijn}"
REPO_NAME="${REPO_NAME:-}"
TF_VAR_github_token="${TF_VAR_github_token:-}"
OVERWRITE_YAML="${OVERWRITE_YAML:-false}"

if ! command -v tofu >/dev/null 2>&1; then
  echo "Error: tofu command not found. Install OpenTofu and add it to your PATH." >&2
  exit 1
fi

if [ -z "$REPO_NAME" ]; then
  read -rp "Enter the repository name to import (bare name or owner/repo): " REPO_NAME
fi

if [ -z "$REPO_NAME" ]; then
  echo "Error: Repository name is required." >&2
  exit 1
fi

# Strip owner prefix if the user supplied "owner/repo"
if [[ "$REPO_NAME" == */* ]]; then
  OWNER="${REPO_NAME%%/*}"
  REPO_NAME="${REPO_NAME##*/}"
else
  read -rp "Enter the GitHub owner (default: $OWNER): " input_owner
  if [ -n "$input_owner" ]; then
    OWNER="$input_owner"
  fi
fi

# Prompt for GitHub token if not already set in the environment.
if [ -z "$TF_VAR_github_token" ]; then
  read -rsp "Enter your GitHub personal access token: " TF_VAR_github_token
  echo ""
fi

if [ -z "$TF_VAR_github_token" ]; then
  echo "Error: GitHub token is required." >&2
  exit 1
fi

# Export vars so tofu picks them up without interactive prompts.
export TF_VAR_github_token
export TF_VAR_github_owner="$OWNER"

# The for_each key in OpenTofu is the YAML filename stem, which equals the bare repo name.
REPO_KEY="$REPO_NAME"
REPOS_DIR="${REPO_ROOT}/repos"
YAML_FILE="${REPOS_DIR}/${REPO_KEY}.yaml"

# Fetch real repository properties from the GitHub API and write the YAML.
if [ ! -f "$YAML_FILE" ] || [ "$OVERWRITE_YAML" = "true" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required to generate the YAML from GitHub API data. Install it and retry." >&2
    exit 1
  fi

  echo "Fetching repository metadata from GitHub API..."
  API_RESPONSE=$(curl -sf \
    -H "Authorization: Bearer $TF_VAR_github_token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO_NAME}")

  # Fetch vulnerability alerts status (requires separate API call with preview header).
  VULN_HTTP_CODE=$(curl -so /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TF_VAR_github_token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO_NAME}/vulnerability-alerts")
  if [ "$VULN_HTTP_CODE" = "204" ]; then
    VULN_ALERTS="true"
  else
    VULN_ALERTS="false"
  fi

  mkdir -p "$REPOS_DIR"
  jq -r '
    "description: " + ((.description // "") | @json),
    "visibility: " + .visibility,
    "default_branch: " + (.default_branch | @json),
    "homepage_url: " + ((.homepage // "") | @json),
    "has_issues: " + (.has_issues | tostring),
    "has_projects: " + (.has_projects | tostring),
    "has_wiki: " + (.has_wiki | tostring),
    "has_downloads: " + (.has_downloads | tostring),
    "has_discussions: " + (.has_discussions | tostring),
    "allow_merge_commit: " + (.allow_merge_commit | tostring),
    "allow_squash_merge: " + (.allow_squash_merge | tostring),
    "allow_rebase_merge: " + (.allow_rebase_merge | tostring),
    "allow_auto_merge: " + (.allow_auto_merge | tostring),
    "delete_branch_on_merge: " + (.delete_branch_on_merge | tostring),
    "is_template: " + (.is_template | tostring),
    "archived: " + (.archived | tostring)
  ' <<< "$API_RESPONSE" > "$YAML_FILE"
  echo "vulnerability_alerts: ${VULN_ALERTS}" >> "$YAML_FILE"

  # Append topics list
  TOPICS=$(jq -r '.topics[] | "  - " + @json' <<< "$API_RESPONSE")
  if [ -n "$TOPICS" ]; then
    echo "topics:" >> "$YAML_FILE"
    echo "$TOPICS" >> "$YAML_FILE"
  else
    echo "topics: []" >> "$YAML_FILE"
  fi

  echo "YAML written to $YAML_FILE from live GitHub data."
fi

VULN_ALERTS="false"
if grep -qx 'vulnerability_alerts: true' "$YAML_FILE"; then
  VULN_ALERTS="true"
fi

REPO_RESOURCE="github_repository.repos[\"$REPO_KEY\"]"
BRANCH_DEFAULT_RESOURCE="github_branch_default.default[\"$REPO_KEY\"]"
VULN_ALERTS_RESOURCE="github_repository_vulnerability_alerts.alerts[\"$REPO_KEY\"]"

echo "Importing repository into OpenTofu state..."
echo "  Owner    : $OWNER"
echo "  Repo     : $REPO_NAME"
echo "  Tofu key : $REPO_KEY"

cd "$REPO_ROOT"

# The GitHub provider import ID for github_repository is just the bare repo name.
if tofu state show "$REPO_RESOURCE" >/dev/null 2>&1; then
  echo "Repository resource already exists in state; skipping import."
else
  tofu import "$REPO_RESOURCE" "$REPO_NAME"
fi

echo ""
echo "Importing default branch resource..."
if tofu state show "$BRANCH_DEFAULT_RESOURCE" >/dev/null 2>&1; then
  echo "Default branch resource already exists in state; skipping import."
elif ! tofu import "$BRANCH_DEFAULT_RESOURCE" "$REPO_NAME"; then
  echo "Warning: Default branch import returned a non-zero exit code. This may be expected if the repository has no default branch or the feature is unavailable." >&2
fi

echo ""
if [ "$VULN_ALERTS" = "true" ]; then
  echo "Importing vulnerability alerts resource..."
  if tofu state show "$VULN_ALERTS_RESOURCE" >/dev/null 2>&1; then
    echo "Vulnerability alerts resource already exists in state; skipping import."
  elif ! tofu import "$VULN_ALERTS_RESOURCE" "$REPO_NAME"; then
    echo "Warning: Vulnerability alerts import returned a non-zero exit code." >&2
  fi
else
  echo "Vulnerability alerts are disabled; no resource is configured to import."
fi

echo ""
echo "Import complete. Run 'tofu plan' to verify the configuration matches the remote state."
