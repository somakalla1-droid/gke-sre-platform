module "foundation" {
  source           = "../../../modules/foundation"
  project_id       = var.project_id
  primary_region   = var.primary_region
  secondary_region = var.secondary_region
}
