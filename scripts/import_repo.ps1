#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Import an existing GitHub repository into the OpenTofu state.

.DESCRIPTION
  Prompts for the repository name and the GitHub owner (default: wavermartijn),
  then runs `tofu import` for the matching github_repository and github_branch_default
  resources.
#>

param(
  [string]$Owner = "wavermartijn",
  [string]$RepoName = ""
)

if (-not (Get-Command tofu -ErrorAction SilentlyContinue)) {
  Write-Error "tofu command not found. Install OpenTofu and add it to your PATH."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Read-Host "Enter the repository name to import"
}

if ([string]::IsNullOrWhiteSpace($RepoName)) {
  Write-Error "Repository name is required."
  exit 1
}

if ($Owner -eq "wavermartijn") {
  $inputOwner = Read-Host "Enter the GitHub owner (default: wavermartijn)"
  if (-not [string]::IsNullOrWhiteSpace($inputOwner)) {
    $Owner = $inputOwner
  }
}

$repoResource = "github_repository.repos[`"$RepoName`"]"
$branchDefaultResource = "github_branch_default.default[`"$RepoName`"]"
$vulnAlertsResource = "github_repository_vulnerability_alerts.alerts[`"$RepoName`"]"

Write-Host "Importing repository into OpenTofu state..." -ForegroundColor Cyan
Write-Host "Owner    : $Owner" -ForegroundColor Gray
Write-Host "Repo     : $RepoName" -ForegroundColor Gray

& tofu import $repoResource $RepoName
if ($LASTEXITCODE -ne 0) {
  Write-Error "Failed to import repository."
  exit $LASTEXITCODE
}

Write-Host "`nImporting default branch resource..." -ForegroundColor Cyan
& tofu import $branchDefaultResource $RepoName
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Default branch import returned a non-zero exit code. This may be expected if the resource does not exist in state or the branch is already tracked."
}

Write-Host "`nImporting vulnerability alerts resource..." -ForegroundColor Cyan
& tofu import $vulnAlertsResource $RepoName
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Vulnerability alerts import returned a non-zero exit code. This may be expected if the feature is unavailable for the repository or already tracked."
}

Write-Host "`nImport complete. Run 'tofu plan' to verify the configuration matches the remote state." -ForegroundColor Green
