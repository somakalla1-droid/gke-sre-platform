variable "project_id" {
  type    = string
  default = "gke-sre-assesment"
}
module "cluster" {
  source              = "../../../modules/gke_cluster"
  project_id          = var.project_id
  name                = "gke-secondary"
  location            = "us-east1-b"
  region              = "us-east1"
  network             = "gke-assessment-vpc"
  subnetwork          = "gke-secondary-subnet"
  pods_range_name     = "secondary-pods"
  services_range_name = "secondary-services"

  artifact_registry_location   = "us-central1"
  artifact_registry_repository = "gke-apps"

  # Match the primary security posture while the project singleton policy is
  # still DRYRUN_AUDIT_LOG_ONLY.
  binary_authorization_evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"

  # Match the proven primary capacity so both two-replica applications and
  # GKE system add-ons remain schedulable in the secondary region.
  node_count = 3
}
