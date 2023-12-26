provider "google" {
  project = "albem-dev"
  region  = "asia-northeast1"
}

resource "google_storage_bucket" "bucket" {
  name     = "gcf-script-bucket"
  location = "asia-northeast1"
}

# Cloud Functionsにアップロードするファイルをzipに固める。
data "archive_file" "function_archive" {
  type        = "zip"
  source_dir  = "./src"
  output_path = "./src.zip"
}

resource "google_storage_bucket_object" "archive" {
  name   = "index.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.function_archive.output_path
}

resource "google_service_account" "cloud_function_sa" {
  account_id   = "list-wav-files-sa"
  display_name = "list-wav-files-sa"
  description  = "Service account for Cloud Function, list_wav_files"
}

resource "google_cloudfunctions_function" "function" {
  name        = "list_wav_files"
  description = "list wav files in the Google Drive."
  runtime     = "python312"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "hello"
  service_account_email = google_service_account.cloud_function_sa.email
}

locals {
  github_repo_owner = "reveal-17"
  github_repo_name  = "listening_demo"
}

# 下記のエラーが解決せず
# The provider provider.google does not support resource type
# "google_iam_workload_identity_pool".
# resource "google_iam_workload_identity_pool" "main" {
#   workload_identity_pool_id = "github"
#   display_name              = "GitHub"
#   description               = "GitHub Actions 用 Workload Identity Pool"
#   disabled                  = false
# }

# resource "google_iam_workload_identity_pool_provider" "main" {
#   workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
#   workload_identity_pool_provider_id = "github"
#   display_name                       = "GitHub"
#   description                        = "GitHub Actions 用 Workload Identity Poolプロバイダ"
#   disabled                           = false
#   attribute_condition                = "assertion.repository_owner == \"${local.github_repo_owner}\""
#   attribute_mapping = {
#     "google.subject" = "assertion.repository"
#   }
#   oidc {
#     issuer_uri = "https://token.actions.githubusercontent.com"
#   }
# }

# resource "google_service_account_iam_member" "workload_identity_sa_iam" {
#   service_account_id = google_service_account.github_actions_service_account.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.main.name}/subject/${local.github_repo_owner}/${local.github_repo_name}"
# }

resource "google_service_account" "github_actions_service_account" {
  account_id   = "albem-dev-github-actions"
  display_name = "albem-dev-github-actions"
}

resource "google_project_iam_member" "github_actions_service_account" {
  count = "${length(var.github_actions_roles)}"
  role   = "${element(var.github_actions_roles, count.index)}"
  member = "serviceAccount:${google_service_account.github_actions_service_account.email}"
}

variable "github_actions_roles" {
  default = [
    "roles/cloudfunctions.admin",
    "roles/storage.objectAdmin",
  ]
}
