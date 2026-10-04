variable "project_id" {
  type    = string
  default = "gke-sre-assesment"
}
module "cluster" {
  source              = "../../../modules/gke_cluster"
  project_id          = var.project_id
  name                = "gke-primary"
  location            = "us-central1-a"
  network             = "gke-assessment-vpc"
  subnetwork          = "gke-primary-subnet"
  pods_range_name     = "primary-pods"
  services_range_name = "primary-services"
}
