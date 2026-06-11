output "cluster_name" {
  value       = google_container_cluster.langops.name
  description = "GKE Autopilot cluster name"
}

output "cluster_location" {
  value       = google_container_cluster.langops.location
  description = "GKE cluster location"
}

output "db_private_ip" {
  value       = google_sql_database_instance.langfuse.private_ip_address
  description = "Use this as postgresql.host in Langfuse values.yaml"
}

output "db_instance_name" {
  value       = google_sql_database_instance.langfuse.name
  description = "CloudSQL instance name"
}

output "langfuse_db_secret_id" {
  value       = google_secret_manager_secret.langfuse_db_secret.id
  description = "Google Secret Manager secret ID containing the Langfuse DB password"
}

output "artifact_registry_repo" {
  value       = google_artifact_registry_repository.apps.repository_id
  description = "Artifact Registry repository for container images"
}

