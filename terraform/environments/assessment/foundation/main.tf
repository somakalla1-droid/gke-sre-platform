module "foundation" {
  source                                = "../../../modules/foundation"
  project_id                            = var.project_id
  primary_region                        = var.primary_region
  secondary_region                      = var.secondary_region
  gateway_hostname                      = var.gateway_hostname
  binary_authorization_enforcement_mode = var.binary_authorization_enforcement_mode
}
