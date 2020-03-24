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

output "In order to login to the VM created, save the following ssh key to a file with `chmod 600` permissions to the file" {
  value = "\n${tls_private_key.ssh_key_keypair.private_key_pem}"
}

output "ssh into the VM using root user and the following IP address:" {
  value = "${ibm_is_floating_ip.fip1.address}"
}

output "ssh_private_ip_addresses" {
  value = concat ("${ibm_is_instance.vm-main.*.primary_network_interface.0.primary_ipv4_address}",
                  "${ibm_is_instance.vm-worker.*.primary_network_interface.0.primary_ipv4_address}")
}
