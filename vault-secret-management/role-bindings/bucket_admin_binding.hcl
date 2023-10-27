resource "buckets/vault-demo-61ed" {
  roles = [
    "roles/storage.objectAdmin",
    "roles/storage.legacyBucketOwner",
  ]
}