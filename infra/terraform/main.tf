data "google_client_config" "current" {}

# VPC
resource "google_compute_network" "langops" {
  name                    = "langops-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "langops" {
  name          = "langops-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.langops.id
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# Private services connection (needed for CloudSQL private IP)
resource "google_compute_global_address" "private_ip_range" {
  name          = "private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.langops.id
}

resource "google_service_networking_connection" "private_vpc" {
  network                 = google_compute_network.langops.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# GKE Autopilot Cluster
resource "google_container_cluster" "langops" {
  name     = "langops-cluster"
  location = var.region
  enable_autopilot    = true
  deletion_protection = false
  network    = google_compute_network.langops.name
  subnetwork = google_compute_subnetwork.langops.name
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# CloudSQL Postgres
resource "google_sql_database_instance" "langfuse" {
  name             = "langfuse-postgres"
  database_version = "POSTGRES_15"
  region           = var.region
  deletion_protection = false
  settings {
    tier      = "db-g1-small"
    disk_size = 20
    backup_configuration { enabled = true }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.langops.id
    }
  }
  depends_on = [google_service_networking_connection.private_vpc]
}

resource "google_sql_database" "langfuse" {
  name     = "langfuse"
  instance = google_sql_database_instance.langfuse.name
}

# Generate random password for Langfuse DB
resource "random_password" "langfuse_db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "langfuse" {
  name     = "langfuse"
  instance = google_sql_database_instance.langfuse.name
  password = random_password.langfuse_db_password.result
}

# Store password in Google Secret Manager
resource "google_secret_manager_secret" "langfuse_db_secret" {
  secret_id = "langops-langfuse-db-password"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "langfuse_db_secret_version" {
  secret      = google_secret_manager_secret.langfuse_db_secret.id
  secret_data = random_password.langfuse_db_password.result
}

# Artifact Registry
resource "google_artifact_registry_repository" "apps" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
}
