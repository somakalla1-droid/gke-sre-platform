variable "project_id" {
  type    = string
  default = "gke-sre-assesment"
}
module "cluster" {
  source              = "../../../modules/gke_cluster"
  project_id          = var.project_id
  name                = "gke-primary"
  location            = "us-central1-a"
  region              = "us-central1"
  network             = "gke-assessment-vpc"
  subnetwork          = "gke-primary-subnet"
  pods_range_name     = "primary-pods"
  services_range_name = "primary-services"

  artifact_registry_location   = "us-central1"
  artifact_registry_repository = "gke-apps"

  # Evaluate the Terraform-managed project singleton policy. The initial
  # policy uses DRYRUN_AUDIT_LOG_ONLY, so violations are logged, not blocked.
  binary_authorization_evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"

  # Three nodes leave schedulable capacity for both two-replica assessment
  # applications after GKE system add-ons are accounted for.
  node_count = 3
}
