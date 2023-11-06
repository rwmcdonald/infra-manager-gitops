terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id  = var.project_id
  enable_apis = var.enable_apis

  activate_apis = [
    "config.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com"
  ]
  disable_services_on_destroy = false
}

// Create a secret containing the personal access token and grant permissions to the Service Agent
resource "google_secret_manager_secret" "github_token_secret" {
  project   = var.project_id
  secret_id = var.git_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_token_secret_version" {
  secret      = google_secret_manager_secret.github_token_secret.id
  secret_data = var.git_personal_access_token
}

data "google_iam_policy" "serviceagent_secretAccessor" {
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = ["serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  project     = google_secret_manager_secret.github_token_secret.project
  secret_id   = google_secret_manager_secret.github_token_secret.secret_id
  policy_data = data.google_iam_policy.serviceagent_secretAccessor.policy_data
}

// Create the GitHub connection
resource "google_cloudbuildv2_connection" "my_connection" {
  project  = var.project_id
  location = var.location
  name     = var.git_connection_name

  github_config {
    app_installation_id = var.git_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version.id
    }
  }
  depends_on = [google_secret_manager_secret_iam_policy.policy]
}

resource "google_cloudbuildv2_repository" "my-repository" {
  name              = var.cloudbuild_repo_name
  location          = var.location
  parent_connection = google_cloudbuildv2_connection.my_connection.id
  remote_uri        = var.git_repo_url
}

resource "google_cloudbuild_trigger" "pull-request-trigger" {
  location = var.location
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  repository_event_config {
    repository = google_cloudbuildv2_repository.my-repository.id
    pull_request {
      branch = var.git_branch_name
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }
  build {
    step {
      name = "gcr.io/cloud-builders/gsutil"
      script = "signedUrl=$(gcloud infra-manager deployments export-statefile ${var.deployment_name} --location=${var.location} | cut -c 12-) && curl $${signedUrl} --output ${var.git_source_directory}/terraform.tfstate"
    }
    step {
      name = "hashicorp/terraform:latest"
      script = "terraform -chdir=${var.git_source_directory} init"
    }
    step {
      name = "hashicorp/terraform:latest"
      script = "terraform -chdir=${var.git_source_directory} plan -no-color"
    }
  }
}

resource "google_cloudbuild_trigger" "push-request-trigger" {
  location = var.location
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  repository_event_config {
    repository = google_cloudbuildv2_repository.my-repository.id
    push {
      branch = var.git_branch_name
    }
  }
  build {
    step {
      name = "gcr.io/cloud-builders/gsutil"
      script = "gcloud infra-manager deployments apply ${var.deployment_name} --location=${var.location}    --project=${var.project_id}     --git-source-repo=${var.git_repo_url}    --git-source-directory=${var.git_source_directory}     --git-source-ref=${var.git_branch_name}     --service-account=projects/${var.project_id}/serviceAccounts/${var.service_account}@${var.project_id}.iam.gserviceaccount.com"
    }
  }
}
