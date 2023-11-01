variable "project" {
  type        = string
  description = "The project ID to use."
}

variable "location" {
  type        = string
  description = "The GCS location."
}

variable "bucket_name" {
  type = string
}

resource "google_storage_bucket" "mybucket" {
  name     = var.bucket_name
  project  = var.project
  location = var.location
}
