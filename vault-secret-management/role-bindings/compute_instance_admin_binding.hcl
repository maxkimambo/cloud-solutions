# Role binding to allow managing GCE instances and storage buckets
resource "//cloudresourcemanager.googleapis.com/projects/kimambo-sandbox" {
  roles = [
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser",  # required if managing instances that run as service accounts
  ]
}
