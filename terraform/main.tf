terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {}

# Use data sources to fetch existing resources data from OpenStack
# Here, we fetch the ID of the default external network router
data "openstack_networking_router_v2" "router1" {
  name = "router1"
}

# Create a new image from a remote source URL
resource "openstack_images_image_v2" "ubuntu-22.04" {
  name             = "ubuntu-22.04"
  image_source_url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  disk_format      = "qcow2"
  container_format = "bare"
  visibility       = "private"

  tags = {
    os      = "ubuntu"
    version = "22.04"
  }
}

# Import a SSH key pair from the local file system
resource "openstack_compute_keypair_v2" "main" {
  name       = "main"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# Create security groups
resource "openstack_networking_secgroup_v2" "ssh" {
  name        = "ssh"
  description = "Allow SSH traffic"
}

resource "openstack_networking_secgroup_v2" "bdd" {
  name        = "bdd"
  description = "Allow DB traffic"
}

resource "openstack_networking_secgroup_v2" "web" {
  name        = "web"
  description = "Allow Web traffic"
}

# Create security group rules
resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  # Reference the security group by ID from the resource above
  security_group_id = openstack_networking_secgroup_v2.ssh.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "mysql_ingress" {
  security_group_id = openstack_networking_secgroup_v2.bdd.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_group_id   = openstack_networking_secgroup_v2.web.id
}

resource "openstack_networking_secgroup_rule_v2" "http_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "https_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

# Create a network
resource "openstack_networking_network_v2" "mynetwork" {
  name         = "mynetwork"
  admin_state_up = true
}

# Create a subnet
resource "openstack_networking_subnet_v2" "mysubnet" {
  name            = "mysubnet"
  network_id      = openstack_networking_network_v2.mynetwork.id
  cidr            = "10.2.0.0/24"
  ip_version      = 4
}

# Add network interface to the instance
resource "openstack_networking_router_interface" "router1_interface1" {
  router_id = data.openstack_networking_router_v2.router1.id
  subnet_id = openstack_networking_subnet_v2.mysubnet.id
}

resource "openstack_compute_instance_v2" "bdd" {
  name            = "bdd"
  flavor_name     = "ds1G"
  image_id        = openstack_images_image_v2.ubuntu-22.04.id
  key_pair        = openstack_compute_keypair_v2.main.name
  security_groups = [openstack_networking_secgroup_v2.bdd.name, openstack_networking_secgroup_v2.ssh.name]
  network {
    name = openstack_networking_network_v2.mynetwork.name
  }
}

# Floating IPs
resource "openstack_networking_floatingip_v2" "ip_bdd" {
  pool = "public"
}

resource "openstack_networking_floatingip_v2" "ip_web" {
  pool = "public"
}

# Create instance
resource "openstack_compute_instance_v2" "bdd" {
  name            = "bdd"
  flavor_name     = "ds1G"
  image_id        = openstack_images_image_v2.ubuntu-22.04.id
  key_pair        = openstack_compute_keypair_v2.main.name
  # Associate the security group with the instance
  security_groups = [openstack_networking_secgroup_v2.bdd.name, openstack_networking_secgroup_v2.ssh.name]
  # Create a network interface and associate it with the instance
  network {
    name = openstack_networking_network_v2.mynetwork.name
  }
}

resource "openstack_compute_instance_v2" "web" {
  name            = "web"
  flavor_name     = "ds1G"
  image_id        = openstack_images_image_v2.ubuntu-22.04.id
  key_pair        = openstack_compute_keypair_v2.main.name
  security_groups = [openstack_networking_secgroup_v2.web.name, openstack_networking_secgroup_v2.ssh.name]
  network {
    name = openstack_networking_network_v2.mynetwork.name
  }
}

# Associate the floating IP with the instance
resource "openstack_compute_floatingip_associate_v2" "bdd_float" {
  floating_ip = openstack_networking_floatingip_v2.ip_bdd.address
  instance_id = openstack_compute_instance_v2.bdd.id
  fixed_ip    = openstack_compute_instance_v2.bdd.network.0.fixed_ip_v4
}

# Associate the floating IP with the instance
resource "openstack_compute_floatingip_associate_v2" "web_float" {
  floating_ip = openstack_networking_floatingip_v2.ip_web.address
  instance_id = openstack_compute_instance_v2.web.id
  fixed_ip    = openstack_compute_instance_v2.web.network.0.fixed_ip_v4
}

# Output the IP addresses of the instance

output "bdd_ip" {
  value = openstack_networking_floatingip_v2.ip_bdd.address
}

output "web_ip" {
  value = openstack_networking_floatingip_v2.ip_web.address
}

output "bdd_private_ip" {
  value = openstack_compute_instance_v2.bdd.network.0.fixed_ip_v4
}

output "web_private_ip" {
  value = openstack_compute_instance_v2.web.network.0.fixed_ip_v4
}

