# Declare provider 
provider "google" {
    project     = "kimambo-sandbox"
    region      = "europe-west3"
    zone        = "europe-west3-a"
}
// reference existing project kimambo-sandbox via data 
data "google_project" "project" {
  project_id = "kimambo-sandbox"
}

resource "random_id" "suffix" {
  byte_length = 2
}

#----------------------------------------------------
#                Enable services                    #
#----------------------------------------------------
resource "google_project_service" "iap" {
  service = "iap.googleapis.com"
  disable_dependent_services = false
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  disable_dependent_services = false
}
#----------------------------------------------------
#                Networking resources               #
#----------------------------------------------------

# VPC network
resource "google_compute_network" "vpc_network" {
    name                    = "vault-demo-${random_id.suffix.hex}"
    auto_create_subnetworks = false
}

# application subnet
resource "google_compute_subnetwork" "vpc_subnet" {
    name          = "vault-subnet"
    ip_cidr_range = "10.0.0.0/24"
    network       = google_compute_network.vpc_network.self_link
    region        = "europe-west3"
}

# firewall rule to allow IAP connections
resource "google_compute_firewall" "iap_to_instance" {
  name    = "allow-iap-to-vault-${random_id.suffix.hex}"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80","443", "8200"] 
  }

  // IAP's IP range
  # "35.235.240.0/20"
  source_ranges = ["0.0.0.0/0"]

  target_tags = ["iap-protected-instance"]
}

#----------------------------------------------------
#                   Service Accounts                #
#----------------------------------------------------
resource "google_service_account" "vault-sa" {
    account_id   = "vault-sa-${random_id.suffix.hex}"
    display_name = "Vault Service Account"
}

resource "google_project_iam_member" "roles-compute-admin" {
    project = data.google_project.project.project_id
    role    = "roles/compute.admin"
    member  = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_project_iam_member" "roles-sa-admin" {
    project = data.google_project.project.project_id
    role    = "roles/iam.serviceAccountAdmin"
    member  = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_project_iam_member" "roles-sa-key-admin" {
    project = data.google_project.project.project_id
    role    = "roles/iam.serviceAccountKeyAdmin"
    member  = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_project_iam_member" "roles-project-admin" {
    project = data.google_project.project.project_id
    role    = "roles/resourcemanager.projectIamAdmin"
    member  = "serviceAccount:${google_service_account.vault-sa.email}"
}

resource "google_storage_bucket_iam_binding" "storage-legacy-owner" {
  bucket = google_storage_bucket.vault-storage.name
  role = "roles/storage.legacyBucketOwner"
  members = [
    "serviceAccount:${google_service_account.vault-sa.email}",
  ]
}

#----------------------------------------------------
#                   Compute resources               #
#----------------------------------------------------
resource "google_compute_instance" "vault_server" {
    name         = "vault-${random_id.suffix.hex}"
    machine_type = "e2-medium"
    zone         = "europe-west3-a"

    boot_disk {
        initialize_params {
            image = "ubuntu-os-cloud/ubuntu-2204-lts"
        }
    }
    # attach the instance to the vpc network using a private ip address
    network_interface {
        network = google_compute_network.vpc_network.self_link
        subnetwork = google_compute_subnetwork.vpc_subnet.self_link
        access_config {
            // Ephemeral IP
        }
    }

            

    
    metadata_startup_script = file("${path.module}/startup.sh")
    service_account {
        email  = google_service_account.vault-sa.email
        scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }

    tags = ["iap-protected-instance"]
    lifecycle {
        ignore_changes = [metadata_startup_script] 
    }
  }

#----------------------------------------------------
#           Sample Storage Bucket                   #
#----------------------------------------------------
resource "google_storage_bucket" "vault-storage" {
    name          = "vault-demo-${random_id.suffix.hex}"
    location      = "EU"
    storage_class = "STANDARD"
    force_destroy = true
}