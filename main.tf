locals {
  repo_files = fileset(var.repos_directory, "*.yaml")

  repos_raw = {
    for f in local.repo_files : trimsuffix(basename(f), ".yaml") => yamldecode(file("${var.repos_directory}/${f}"))
  }

  repos = {
    for name, cfg in local.repos_raw : name => {
      name                   = name
      description            = try(cfg.description, null)
      visibility             = try(cfg.visibility, "private")
      default_branch         = try(cfg.default_branch, cfg["default-branch"], "main")
      homepage_url           = try(cfg.homepage_url, null)
      has_issues             = try(cfg.has_issues, true)
      has_projects           = try(cfg.has_projects, false)
      has_wiki               = try(cfg.has_wiki, false)
      has_downloads          = try(cfg.has_downloads, true)
      has_discussions        = try(cfg.has_discussions, false)
      allow_merge_commit     = try(cfg.allow_merge_commit, true)
      allow_squash_merge     = try(cfg.allow_squash_merge, true)
      allow_rebase_merge     = try(cfg.allow_rebase_merge, true)
      allow_auto_merge       = try(cfg.allow_auto_merge, false)
      delete_branch_on_merge = try(cfg.delete_branch_on_merge, true)
      is_template            = try(cfg.is_template, false)
      archived               = try(cfg.archived, false)
      topics                 = try(cfg.topics, [])
      vulnerability_alerts             = try(cfg.vulnerability_alerts, true)
      require_pull_request             = try(cfg.require_pull_request, false)
      require_pull_request_reviews     = try(cfg.require_pull_request_reviews, false)
      template                         = try(cfg.template, {})
    }
  }

  collaborators = flatten([
    for repo_name, cfg in local.repos_raw : [
      for username, user_cfg in try(cfg.allowed_users, {}) : {
        key        = "${repo_name}:${username}"
        repo_name  = repo_name
        username   = username
        permission = try(user_cfg.permission, "push")
        owner      = try(user_cfg.owner, false)
      }
    ]
  ])
}

resource "github_repository" "repos" {
  for_each = local.repos

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility

  homepage_url           = each.value.homepage_url
  has_issues             = each.value.has_issues
  has_projects           = each.value.has_projects
  has_wiki               = each.value.has_wiki
  has_downloads          = each.value.has_downloads
  has_discussions        = each.value.has_discussions
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = each.value.allow_auto_merge
  delete_branch_on_merge = each.value.delete_branch_on_merge
  is_template            = each.value.is_template
  archived                               = each.value.archived
  ignore_vulnerability_alerts_during_read = false
  topics                                 = each.value.topics

  dynamic "template" {
    for_each = length(each.value.template) > 0 ? [each.value.template] : []
    content {
      owner      = template.value.owner
      repository = template.value.repository
    }
  }

}

resource "github_repository_collaborator" "collaborators" {
  for_each = {
    for c in local.collaborators : c.key => c
    if !c.owner && c.username != var.github_owner
  }

  repository = github_repository.repos[each.value.repo_name].name
  username   = each.value.username
  permission = each.value.permission
}

resource "github_branch_default" "default" {
  for_each = local.repos

  repository = github_repository.repos[each.key].name
  branch     = each.value.default_branch
}

resource "github_branch_protection" "default" {
  for_each = {
    for name, cfg in local.repos : name => cfg
    if cfg.require_pull_request
  }

  repository_id = github_repository.repos[each.key].node_id
  pattern       = each.value.default_branch

  required_pull_request_reviews {
    required_approving_review_count = each.value.require_pull_request_reviews ? 1 : 0
  }
}

resource "github_repository_vulnerability_alerts" "alerts" {
  for_each = {
    for name, cfg in local.repos : name => cfg
    if cfg.vulnerability_alerts
  }

  repository = github_repository.repos[each.key].name
}
