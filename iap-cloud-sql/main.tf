# Declare provider 
provider "google" {
  project = "kimambo-sandbox"
  region  = "europe-west3"
  zone    = "europe-west3-a"
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
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
}
resource "google_project_service" "cloudsql" {
  service = "sql-component.googleapis.com"
}
# required for the use of cloud sql proxy
resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
}

#----------------------------------------------------
#                Networking resources               #
#----------------------------------------------------

# VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "ard-sql-demo-${random_id.suffix.hex}"
  auto_create_subnetworks = false
}

# application subnet
resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "apps-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc_network.self_link
  region        = "europe-west3"
}

# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
  name          = "sql-ip-${random_id.suffix.hex}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering              = google_service_networking_connection.private_vpc_connection.peering
  network              = google_compute_network.vpc_network.name
  import_custom_routes = true
  export_custom_routes = true
}

# firewall rule to allow IAP connections
resource "google_compute_firewall" "iap_to_instance" {
  name    = "allow-iap-to-instance"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "3306"] // This assumes SSH and MySQL access; adjust if needed.
  }

  // IAP's IP range
  source_ranges = ["35.235.240.0/20"]

  target_tags = ["iap-protected-instance"]
}

#----------------------------------------------------
#                Cloud SQL resources                #
#----------------------------------------------------
resource "google_sql_database_instance" "db_server" {
  name             = "ard-demo-${random_id.suffix.hex}"
  database_version = "MYSQL_8_0"
  region           = "europe-west3"
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled                                  = false
      enable_private_path_for_google_cloud_services = true
      private_network                               = google_compute_network.vpc_network.self_link
    }
    disk_autoresize             = true
    deletion_protection_enabled = false
  }
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# create a database
resource "google_sql_database" "db" {
  name      = "ard-demo"
  charset   = "utf8mb3"
  collation = "utf8mb3_general_ci"
  instance  = google_sql_database_instance.db_server.name
}

resource "google_sql_user" "db_user" {
  depends_on = [google_sql_database.db]
  name       = "root"
  instance   = google_sql_database_instance.db_server.name
  password   = "d75*Fdqa&S8*pm3^" # this is only for demo purposes
}

# create a service account for the cloud sql instance
resource "google_service_account" "cloudsql-sa" {
  account_id = "cloudsql-sa"
}

resource "google_project_iam_member" "cloudsql-sa-member" {
  project = data.google_project.project.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloudsql-sa.email}"
}

resource "google_project_iam_member" "cloudsql-compute-member" {
  project = data.google_project.project.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.cloudsql-sa.email}"
}
# # create compute instance
resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-medium"
  zone         = "europe-west3-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }
  # attach the instance to the vpc network using a private ip address
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.vpc_subnet.self_link
    ## private ip (if access_config is not set, the instance will not have an external IP address)
    # access_config {
    #   // Ephemeral IP
    # }
  }
  can_ip_forward = true

  metadata_startup_script = file("${path.module}/startup.sh")

  service_account {
    email  = google_service_account.cloudsql-sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["iap-protected-instance"]
}