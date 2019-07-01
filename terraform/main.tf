terraform {
  required_version = ">=0.11,<0.12"
}

provider "google" {
  version = "2.0.0"
  project = "${var.project}"
  region  = "${var.region}"
}

resource "google_container_cluster" "primary" {
  name     = "k8s-1"
  zone     = "${var.zone}"
  remove_default_node_pool = true
  initial_node_count = 1
  addons_config {
    kubernetes_dashboard {
        disabled = "false"
    }

  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "k8s-1-node"
  zone       = "${var.zone}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "${var.machine_type}"

    // metadata {
    //   disable-legacy-endpoints = "true"
    // }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}
