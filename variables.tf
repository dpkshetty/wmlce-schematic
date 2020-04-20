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

variable "ibmcloud_api_key" {
    description = "Denotes the IBM Cloud API key to use"
}

variable "wmlce_version" {
  description = "Watson Machine Learning Community Edition (WMLCE) version to install"
  default = "1.7.0"
}

variable "python_version" {
  description = "python version to install for WMLCE frameworks"
  default = "3.7"
}

variable "vm_count" {
  description = "Number of VMs to be provisioned for WMLCE. Each VM has 2 GPUs."
  default     = "2"
}

variable "vm_profile" {
  description = "What resources or VM profile should we create for compute? Default is 2 GPUs, 16 vCPUs, 128G memory, 48Gbps Network"
  default = "gp2-16x128x2"
}

variable "boot_image_name" {
  description = "name of the base image for the virtual server (should be an Ubuntu 18.04 base)"
  default = "ibm-ubuntu-18-04-3-minimal-ppc64le-4"
}

variable "basename" {
  description = "Denotes the name of the VPC to deploy into. Resources associated will be prepended with this name."
  default = "wmlce-gpu"
}

variable "vpc_region" {
  description = "Target region to create this instance"
  default = "us-south"
}

variable "vpc_zone" {
  description = "Target availbility zone to create this instance"
  default = "us-south-3"
}

