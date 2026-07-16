variable "github_owner" {
  description = "GitHub user or organization that owns the repositories."
  type        = string
  default     = "wavermartijn"
}

variable "github_token" {
  description = "GitHub personal access token with repo and read:org scopes."
  type        = string
  sensitive   = true
}

variable "repos_directory" {
  description = "Directory containing repository YAML definitions."
  type        = string
  default     = "repos"
}
