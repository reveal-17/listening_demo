terraform {
	required_providers {
		archive = {
			source = "hashicorp/archive"
		}
		google = {
			source  = "hashicorp/google"
		}
	}
}

provider "google" {
	project = "albem-dev"
	region  = "asia-northeast1"
}

# Cloud Functionsのスクリプトを格納するバケット
resource "google_storage_bucket" "bucket" {
	name     = "gcf-script-bucket"
	location = "asia-northeast1"
	# 均一なアクセス
	uniform_bucket_level_access = true
	# 非公開バケット
	public_access_prevention = "enforced"
}

# Cloud Functionsにアップロードするファイルをzipに固める。
data "archive_file" "function_archive" {
	type        = "zip"
	source_dir  = "./src"
	output_path = "./archive/listen_demo/src.zip"
}

# Cloud FunctionsのスクリプトをGCSへアップロード
resource "google_storage_bucket_object" "archive" {
	name   = "${data.archive_file.function_archive.output_md5}.zip"
	bucket = google_storage_bucket.bucket.name
	source = data.archive_file.function_archive.output_path
}

# Cloud Functionsのサービスアカウント
resource "google_service_account" "listen_wav_file_sa" {
	account_id   = "listen-wav-files-sa"
	display_name = "listen-wav-files-sa"
	description  = "Service account for Cloud Function, listen_wav_files"
}

resource "google_project_iam_member" "listen_wav_file_sa" {
	project = "albem-dev"
	role   = "roles/iam.serviceAccountUser"
	member = "serviceAccount:${google_service_account.github_actions_service_account.email}"
}

# Cloud Functionsの構成情報
resource "google_cloudfunctions_function" "function" {
	name        = "listen_wav_files"
	description = "listen wav files in the Google Drive."
	runtime     = "python312"

	available_memory_mb   = 128
	source_archive_bucket = google_storage_bucket.bucket.name
	source_archive_object = google_storage_bucket_object.archive.name
	trigger_http          = true
	entry_point           = "hello"
	service_account_email = google_service_account.listen_wav_file_sa.email
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

# Github Actions用のサービスアカウントを作成する。
resource "google_service_account" "github_actions_service_account" {
	project = "albem-dev"
	account_id   = "albem-dev-github-actions"
	display_name = "albem-dev-github-actions"
}

# Github Actions用のサービスアカウントにIAMロールを付与する。
resource "google_project_iam_member" "github_actions_service_account" {
	project = "albem-dev"
	count = length(var.github_actions_roles)
	role   = element(var.github_actions_roles, count.index)
	member = "serviceAccount:${google_service_account.github_actions_service_account.email}"
}

# Github Actions用のサービスアカウントにIAMロールを付与する。
variable "github_actions_roles" {
	default = [
		"roles/cloudfunctions.admin",
		"roles/storage.objectAdmin",
	]
}
