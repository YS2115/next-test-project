# main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "tf-state-${var.project_id}"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "nextjs_repo" {
  location      = var.region
  repository_id = "nextjs-app"
  description   = "Docker repository for Next.js application"
  format        = "DOCKER"
}

# Cloud Run service
resource "google_cloud_run_service" "nextjs_app" {
  name     = "nextjs-app"
  location = var.region

  template {
    spec {
      containers {
        # Update image path to use Artifact Registry instead of Container Registry
        image = "${var.region}-docker.pkg.dev/${var.project_id}/nextjs-app/nextjs-app:${var.image_tag}"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        env {
          name  = "NODE_ENV"
          value = "production"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # Add explicit dependency on the Artifact Registry repository
  depends_on = [
    google_artifact_registry_repository.nextjs_repo
  ]
}

# IAM policy to make the service public
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.nextjs_app.name
  location = google_cloud_run_service.nextjs_app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
