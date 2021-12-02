variable "region" {
  description = "Please Enter Cloud Region ex. ap-mumbai-1"
}

variable "rc_node" {
  default = 0
}

variable "rc_node_index" {
  default = 0
}

variable "openshift_iso_cmd" {
  description = "Please paste wget command you got from OpenShift Assisted Installer"
}

variable "tenancy_ocid" {
  description = "Please Enter Oracle Cloud Tenancy ID"
}

variable "compartment_ocid" {
  description = "Please Enter Compartment OCID"
}

variable "number_of_nodes" {
  description = "Please Enter Number of Required Nodes"
}

variable "os_compartment_name" {
  description = "Please Enter New Compartment Name for OpenShift"
}

variable "zone_name" {
  description = "Public DNS Zone Name for the OpenShift"
}


provider "oci" {
  auth   = "InstancePrincipal"
  region = var.region
}

data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_regions" "home-region" {
  filter {
    name   = "key"
    values = [data.oci_identity_tenancy.tenancy.home_region_key]
  }
}

provider "oci" {
  alias  = "home"
  region = data.oci_identity_regions.home-region.regions[0]["name"]
}

resource "oci_identity_compartment" "openshift_compartment" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  description    = "OpenShift Compartment"
  name           = var.os_compartment_name
}

resource "oci_core_vcn" "openshift_vcn" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  cidr_block     = "10.0.0.0/16"
  display_name   = "OpenShift VCN"
  dns_label      = "openshift"
}

data "oci_core_vcn" "openshift_vcn" {
  vcn_id = oci_core_vcn.openshift_vcn.id
}

resource "oci_core_subnet" "openshift_public_lb_subnet" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id

  display_name      = "OpenShift Public LB Subnet"
  dns_label         = "public"
  route_table_id    = oci_core_vcn.openshift_vcn.default_route_table_id
  security_list_ids = [oci_core_vcn.openshift_vcn.default_security_list_id]
}

resource "oci_core_nat_gateway" "openshift_cluster_nat_gateway" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "OpenShift Cluster NAT Gateway"
}


resource "oci_core_route_table" "openshift_cluster_route_table" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id

  display_name = "OpenShift Cluster Route Table"
  route_rules {
    network_entity_id = oci_core_nat_gateway.openshift_cluster_nat_gateway.id
    description       = "OpenShift Cluster Route Table"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_default_security_list" "oci_core_default_security" {
  compartment_id             = oci_identity_compartment.openshift_compartment.id
  manage_default_resource_id = oci_core_vcn.openshift_vcn.default_security_list_id
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = "22"
      max = "22"
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = "443"
      max = "443"
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = "80"
      max = "80"
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = "3"
      code = "4"
    }
  }

}

resource "oci_core_subnet" "openshift_cluster_subnet" {
  cidr_block     = "10.0.1.0/24"
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id

  display_name               = "OpenShift Cluster Subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.openshift_cluster_route_table.id
  security_list_ids          = [oci_core_vcn.openshift_vcn.default_security_list_id]
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_internet_gateway" "openshift_internet_gateway" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id
}

resource "oci_core_default_route_table" "openshift_public_route_table" {
  compartment_id             = oci_identity_compartment.openshift_compartment.id
  manage_default_resource_id = oci_core_vcn.openshift_vcn.default_route_table_id

  route_rules {
    #Required
    network_entity_id = oci_core_internet_gateway.openshift_internet_gateway.id
    destination       = "0.0.0.0/0"
  }
}

data "oci_identity_availability_domains" "get_availability_domains" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
}


data "oci_core_images" "get_images" {
  #Required
  compartment_id   = oci_identity_compartment.openshift_compartment.id
  operating_system = "Oracle Linux"
  shape            = "VM.Standard2.1"

}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.tpl")
  vars = {
    iso_download_cmd = "${var.openshift_iso_cmd}"
  }
}

resource "oci_core_instance" "ipxe_web_server" {
  availability_domain = data.oci_identity_availability_domains.get_availability_domains.availability_domains[0].name
  compartment_id      = oci_identity_compartment.openshift_compartment.id
  shape               = "VM.Standard2.1"
  display_name        = "ipxe web server"
  source_details {
    source_id   = data.oci_core_images.get_images.images[0].id
    source_type = "image"

    #Optional
    #boot_volume_size_in_gbs = var.instance_source_details_boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub")
    user_data           = base64encode(data.template_file.user_data.rendered)
  }

  create_vnic_details {
    subnet_id  = oci_core_subnet.openshift_public_lb_subnet.id
    private_ip = "10.0.0.8"
  }
  #preserve_boot_volume = false
}

data "template_file" "pxe_boot" {
  template = file("${path.module}/pxe_boot.tpl")
  vars = {
    pxe_server_ip = "${oci_core_instance.ipxe_web_server.private_ip}"
  }
}

resource "time_sleep" "wait" {
  depends_on = [oci_core_instance.ipxe_web_server]

  create_duration = "300s"


}


resource "oci_core_instance" "os_cluster_nodes" {
  count               = var.number_of_nodes
  availability_domain = data.oci_identity_availability_domains.get_availability_domains.availability_domains[0].name
  compartment_id      = oci_identity_compartment.openshift_compartment.id
  shape               = "VM.Standard2.4"
  depends_on          = [time_sleep.wait]
  display_name        = "openshift-cn${count.index}"
  ipxe_script         = data.template_file.pxe_boot.rendered
  source_details {
    #Required
    source_id   = data.oci_core_images.get_images.images[0].id
    source_type = "image"

    #Optional
    boot_volume_size_in_gbs = "200"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.openshift_cluster_subnet.id
    assign_public_ip = "false"
    private_ip       = "10.0.1.1${count.index}"
  }
  preserve_boot_volume = true
}


resource "oci_load_balancer_load_balancer" "openshift_private_lb" {
  depends_on     = [oci_core_instance.os_cluster_nodes]
  compartment_id = oci_identity_compartment.openshift_compartment.id
  display_name   = "OpenShift Private LB"
  shape          = "100Mbps"
  subnet_ids     = [oci_core_subnet.openshift_cluster_subnet.id]

  #Optional
  ip_mode    = "IPV4"
  is_private = "true"
  #network_security_group_ids = var.load_balancer_network_security_group_ids
}

resource "oci_core_network_security_group" "openshift_public_lb_network_security_group" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  vcn_id         = oci_core_vcn.openshift_vcn.id

  display_name = "openshift_public_lb_network_security_group"
}

#Rules_TBD

resource "oci_load_balancer_load_balancer" "openshift_public_lb" {
  #Required
  compartment_id = oci_identity_compartment.openshift_compartment.id
  display_name   = "OpenShift Public LB"
  shape          = "100Mbps"
  subnet_ids     = [oci_core_subnet.openshift_public_lb_subnet.id]

  #Optional
  ip_mode    = "IPV4"
  is_private = "false"
  #network_security_group_ids = var.load_balancer_network_security_group_ids
}

resource "oci_load_balancer_backend_set" "api_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "6443"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  name             = "api_backend_set"
  policy           = "ROUND_ROBIN"

}

resource "oci_load_balancer_backend_set" "http_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "80"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  name             = "http_backend_set"
  policy           = "ROUND_ROBIN"

}

resource "oci_load_balancer_backend_set" "https_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "443"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  name             = "https_backend_set"
  policy           = "ROUND_ROBIN"

}

resource "oci_load_balancer_backend_set" "bs_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "22623"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  name             = "bs_backend_set"
  policy           = "ROUND_ROBIN"

}

resource "oci_load_balancer_backend" "bs_backend" {
  count            = var.number_of_nodes
  backendset_name  = oci_load_balancer_backend_set.bs_backend_set.name
  ip_address       = oci_core_instance.os_cluster_nodes[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  port             = "22623"
}
resource "oci_load_balancer_backend" "http_backend" {
  count            = var.number_of_nodes
  backendset_name  = oci_load_balancer_backend_set.http_backend_set.name
  ip_address       = oci_core_instance.os_cluster_nodes[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  port             = "80"
}

resource "oci_load_balancer_backend" "https_backend" {
  count            = var.number_of_nodes
  backendset_name  = oci_load_balancer_backend_set.https_backend_set.name
  ip_address       = oci_core_instance.os_cluster_nodes[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  port             = "443"
}

resource "oci_load_balancer_backend" "api_backend" {
  count            = var.number_of_nodes
  backendset_name  = oci_load_balancer_backend_set.api_backend_set.name
  ip_address       = oci_core_instance.os_cluster_nodes[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.openshift_private_lb.id
  port             = "6443"
}
resource "oci_load_balancer_listener" "api_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.api_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_private_lb.id
  name                     = "api_listener"
  port                     = "6443"
  protocol                 = "TCP"
}
resource "oci_load_balancer_listener" "http_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.http_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_private_lb.id
  name                     = "http_listener"
  port                     = "80"
  protocol                 = "TCP"
}
resource "oci_load_balancer_listener" "https_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.https_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_private_lb.id
  name                     = "https_listener"
  port                     = "443"
  protocol                 = "TCP"
}

resource "oci_load_balancer_listener" "bs_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.bs_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_private_lb.id
  name                     = "bs_listener"
  port                     = "22623"
  protocol                 = "TCP"
}

resource "oci_load_balancer_backend_set" "public_http_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "80"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_public_lb.id
  name             = "http_backend_set"
  policy           = "ROUND_ROBIN"

}

resource "oci_load_balancer_backend_set" "public_https_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = "443"
  }
  load_balancer_id = oci_load_balancer_load_balancer.openshift_public_lb.id
  name             = "https_backend_set"
  policy           = "ROUND_ROBIN"

}
resource "oci_load_balancer_backend" "public_http_backend" {
  backendset_name  = oci_load_balancer_backend_set.public_http_backend_set.name
  ip_address       = oci_load_balancer_load_balancer.openshift_private_lb.ip_address_details[0]["ip_address"]
  load_balancer_id = oci_load_balancer_load_balancer.openshift_public_lb.id
  port             = "80"
}

resource "oci_load_balancer_backend" "public_https_backend" {
  backendset_name  = oci_load_balancer_backend_set.public_https_backend_set.name
  ip_address       = oci_load_balancer_load_balancer.openshift_private_lb.ip_address_details[0]["ip_address"]
  load_balancer_id = oci_load_balancer_load_balancer.openshift_public_lb.id
  port             = "443"
}
resource "oci_load_balancer_listener" "public_http_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.public_http_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_public_lb.id
  name                     = "http_listener"
  port                     = "80"
  protocol                 = "TCP"
}
resource "oci_load_balancer_listener" "public_https_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.public_https_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.openshift_public_lb.id
  name                     = "https_listener"
  port                     = "443"
  protocol                 = "TCP"
}

resource "oci_dns_zone" "openshift_zone" {
  compartment_id = oci_identity_compartment.openshift_compartment.id
  name           = var.zone_name
  zone_type      = "PRIMARY"

}
resource "oci_dns_rrset" "api-int" {
  zone_name_or_id = oci_dns_zone.openshift_zone.id
  domain          = "api-int.${var.zone_name}"
  rtype           = "A"
  items {
    rtype  = "A"
    domain = "api-int.${var.zone_name}"
    rdata  = oci_load_balancer_load_balancer.openshift_private_lb.ip_address_details[0]["ip_address"]
    ttl    = "300"
  }
}
resource "oci_dns_rrset" "api" {
  zone_name_or_id = oci_dns_zone.openshift_zone.id
  domain          = "api.${var.zone_name}"

  rtype = "A"
  items {
    rtype  = "A"
    domain = "api.${var.zone_name}"
    rdata  = oci_load_balancer_load_balancer.openshift_private_lb.ip_address_details[0]["ip_address"]
    ttl    = "300"
  }
}
resource "oci_dns_rrset" "apps_wildcard" {
  zone_name_or_id = oci_dns_zone.openshift_zone.id
  domain          = "*.apps.${var.zone_name}"
  rtype           = "A"
  items {
    domain = "*.apps.${var.zone_name}"
    rtype  = "A"
    rdata  = oci_load_balancer_load_balancer.openshift_public_lb.ip_address_details[0]["ip_address"]
    ttl    = "300"
  }
}

output "nameservers" {
  value       = oci_dns_zone.openshift_zone.nameservers
  description = "Please Update your DNS Registar/Master Zone with these values"
}

output "openshift_nodes" {
  value = oci_core_instance.os_cluster_nodes[0].boot_volume_id
}

