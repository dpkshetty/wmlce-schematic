# Copyright 2020. IBM All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  ports = "${list("22", "80", "443")}"
}

resource ibm_is_vpc "vpc" {
  name = "${var.basename}-vpc"
}

resource "ibm_is_public_gateway" "publicgateway" {
  name = "gateway"
  vpc  = "${ibm_is_vpc.vpc.id}"
  zone = "${var.vpc_zone}"
}

resource "ibm_is_subnet" "subnet" {
  name                     = "${var.basename}-subnet"
  vpc                      = "${ibm_is_vpc.vpc.id}"
  zone                     = "${var.vpc_zone}"
  ip_version               = "ipv4"
  total_ipv4_address_count = 16
  public_gateway           = "${ibm_is_public_gateway.publicgateway.id}"
}

# Create an public/private ssh key pair to be used to login to VMs
resource ibm_is_ssh_key "public_key" {
  name = "${var.basename}-public-key"
  public_key = "${tls_private_key.ssh_key_keypair.public_key_openssh}"
}

# Create a public floating IP so that the app is available on the Internet
resource "ibm_is_floating_ip" "fip1" {
  name = "${var.basename}-fip"
  target = "${ibm_is_instance.vm-main.primary_network_interface.0.id}"
}

# Enable ssh into the VM instances
resource "ibm_is_security_group_rule" "sg1-tcp-rule" {
  count = "${length(local.ports)}"
  depends_on = [
    "ibm_is_floating_ip.fip1"
  ]
  group = "${ibm_is_vpc.vpc.default_security_group}"
  direction = "inbound"
  remote = "0.0.0.0/0"


  tcp = {
    port_min = "${element(local.ports, count.index)}"
    port_max = "${element(local.ports, count.index)}"
  }
}

data ibm_is_image "bootimage" {
    name = "${var.boot_image_name}"
}

resource "ibm_is_instance" "vm-main" {
  name = "${var.basename}-vm-main"
  image = "${data.ibm_is_image.bootimage.id}"
  profile = "${var.vm_profile}"

  primary_network_interface = {
    subnet = "${ibm_is_subnet.subnet.id}"
  }

  vpc = "${ibm_is_vpc.vpc.id}"
  zone = "${var.vpc_zone}"
  keys      = ["${ibm_is_ssh_key.public_key.id}"]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "ibm_is_instance" "vm-worker" {
  count   = "${var.vm_count - 1}"
  name    = "${format("vm-worker-%02d", count.index + 1)}"
  image   = "${data.ibm_is_image.bootimage.id}"
  profile = "${var.vm_profile}"

  primary_network_interface {
    subnet = "${ibm_is_subnet.subnet.id}"
  }

  vpc  = "${ibm_is_vpc.vpc.id}"
  zone = "${var.vpc_zone}"
  keys = ["${ibm_is_ssh_key.public_key.id}"]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}
# Create a ssh keypair which will be used to provision code onto the system - and also access the VM for debug if needed.
resource tls_private_key "ssh_key_keypair" {
  algorithm = "RSA"
  rsa_bits = "2048"
}

resource "null_resource" "provisioners" {
  depends_on = ["ibm_is_security_group_rule.sg1-tcp-rule" ]

  provisioner "remote-exec" {
  inline = ["date"]
  connection {
    type = "ssh"
    user = "root"
    agent = false
    timeout = "2m"
    host = "${ibm_is_floating_ip.fip1.address}"
    private_key = "${tls_private_key.ssh_key_keypair.private_key_pem}"
    }
  }

  provisioner "local-exec" {
    working_dir = "ansible"
    command = "ansible-playbook -vvv --timeout 1800 -i .  main.yml"
  }
}
