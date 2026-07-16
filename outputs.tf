output "managed_repositories" {
  description = "Map of managed repository names to their GitHub URLs."
  value = {
    for name, repo in github_repository.repos : name => repo.html_url
  }
}

output "collaborators" {
  description = "List of repository collaborators being managed."
  value = [
    for c in github_repository_collaborator.collaborators : {
      repository = c.repository
      username   = c.username
      permission = c.permission
    }
  ]
}
