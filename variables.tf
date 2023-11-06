variable "project_id" {
  type        = string
  description = "The project ID to use."
}

variable "location" {
  type        = string
  description = "The GCS location."
}

variable "deployment_name" {
  type = string
  description = "Name of the IM deployment"
}

variable "service_account" {
    type = string
    description = "Name of the IM SA"
}

variable "git_repo_url" {
  type = string
  description = "The git repo url ending with .git"
}

variable "git_connection_name" {
  type = string
  description = "The name of the git connection for this repo"
}

variable "git_installation_id" {
  type = string
  description = "The git installation id for cloud build Github app"
}

variable "git_secret_id" {
  type = string
  description = "Unique name of the secret for github PAT"
}

variable "git_personal_access_token" {
  type      = string
  sensitive = true
  description = "Git Personal Access Token"
}

variable "cloudbuild_repo_name" {
    type = string
    description = "Name of the cloudbuild repository"
}

variable "enable_apis" {
  type      = bool
  default   = true
}

variable "git_branch_name" {
  type = string
  default = "main"
  description = "The git branch to create triggers on"
}

variable git_source_directory {
  type = string
  default = "./"
  description = "The path to the terraform module"
}
