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

resource ibm_is_subnet "subnet" {
  name = "${var.basename}-subnet"
  vpc  = "${ibm_is_vpc.vpc.id}"
  zone = "${var.vpc_zone}"
  ip_version = "ipv4"
  total_ipv4_address_count = 16
}

# Create an SSH key which will be used for provisioning by this template, and for debug purposes
resource ibm_is_ssh_key "public_key" {
  name = "${var.basename}-public-key"
  public_key = "${tls_private_key.ssh_key_keypair.public_key_openssh}"
}

# Create a public floating IP so that the app is available on the Internet
resource "ibm_is_floating_ip" "fip1" {
  name = "${var.basename}-fip"
  target = "${ibm_is_instance.vm.primary_network_interface.0.id}"
}

# Enable ssh into the instance for debug
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

resource "ibm_is_instance" "vm" {
  name = "${var.basename}-vm1"
  image = "${data.ibm_is_image.bootimage.id}"
  profile = "${var.vm_profile}"

  primary_network_interface = {
    subnet = "${ibm_is_subnet.subnet.id}"
  }

  vpc = "${ibm_is_vpc.vpc.id}"
  zone = "${var.vpc_zone}"
  keys      = ["${ibm_is_ssh_key.public_key.id}"]
  timeouts {
    create = "120m"
    delete = "120m"
  }
}

resource "ibm_is_instance" "vm-worker" {
  count   = var.vm_count - 1
  name    = format("%s-vm-worker%02d", var.basename, count.index + 1)
  image   = data.ibm_is_image.bootimage.id
  profile = var.vm_profile

  primary_network_interface {
    subnet = ibm_is_subnet.subnet.id
  }

  vpc  = ibm_is_vpc.vpc.id
  zone = var.vpc_zone
  keys = [ibm_is_ssh_key.public_key.id]
  timeouts {
    create = "120m"
    delete = "120m"
  }
}
# Create a ssh keypair which will be used to provision code onto the system - and also access the VM for debug if needed.
resource tls_private_key "ssh_key_keypair" {
  algorithm = "RSA"
  rsa_bits = "2048"
}

resource "null_resource" "provisioners" {

  triggers = {
    vmid = "${ibm_is_instance.vm.id}"
  }

  depends_on = [
    "ibm_is_security_group_rule.sg1-tcp-rule"
  ]

  provisioner "file" {
    source =  "scripts"
    destination = "/tmp"
    connection {
      type = "ssh"
      user = "root"
      agent = false
      timeout = "5m"
      host = "${ibm_is_floating_ip.fip1.address}"
      private_key = "${tls_private_key.ssh_key_keypair.private_key_pem}"
    }
  }

  provisioner "file" {
    content = <<ENDENVTEMPL
#!/bin/bash -xe
export WMLCE_VERSION=${var.wmlce_version}
export PYTHON_VERSION=${var.python_version}
if [[  "${var.vm_profile}" =~ "gp" ]];
then
    export GPU_CONFIG=1
fi
echo "${tls_private_key.ssh_key_keypair.private_key_pem}" >> ~/.ssh/id_rsa

echo "Host *" >> ~/.ssh/config
echo "  StrictHostKeyChecking no" >> ~/.ssh/config
echo "  UserKnownHostsFile=/dev/null" >> ~/.ssh/config
chmod 600 ~/.ssh/id_rsa

ENDENVTEMPL

    destination = "/tmp/scripts/env.sh"
    connection {
      type = "ssh"
      user = "root"
      agent = false
      timeout = "5m"
      host = "${ibm_is_floating_ip.fip1.address}"
      private_key = "${tls_private_key.ssh_key_keypair.private_key_pem}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod u+x /tmp/scripts*/*",
      "/tmp/scripts/env.sh",
      "/tmp/scripts/install_gpu_drivers.sh",
      "/tmp/scripts/install_wmlce.sh",
      "rm -rf /tmp/scripts",
      "exit 0",
    ]
    connection {
      type = "ssh"
      user = "root"
      agent = false
      timeout = "120m"
      host = "${ibm_is_floating_ip.fip1.address}"
      private_key = "${tls_private_key.ssh_key_keypair.private_key_pem}"
    }
  }
}
