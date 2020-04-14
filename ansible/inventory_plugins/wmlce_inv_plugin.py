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

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
    name: wmlce_inv_plugin
    plugin_type: inventory
    short_description: Returns Ansible inventory from terraform tfstate file
    description: Returns Ansible inventory from Terraform tfstate file
    options:
      plugin:
          description: Name of the plugin
          required: true
          choices: ['wmlce_inv_plugin']
      terraform_file:
        description: Name of the terraform file with relative/absolute path to the file
        required: true
'''



from ansible.plugins.inventory import BaseInventoryPlugin
from ansible.errors import AnsibleError, AnsibleParserError
import os
import json

class InventoryModule(BaseInventoryPlugin):
    NAME = 'wmlce_inv_plugin'


    def verify_file(self, path):
        '''
        Return true/false if this is possibly a valid file for this plugin to consume
        '''
        valid = False
        if super(InventoryModule, self).verify_file(path):
            # base class verifies that file exists and is readable by current user
            if path.endswith(('wmlce_inv.yaml',
                              'wmlce_inv.yml')):
                valid = True

        return valid

    def parse(self, inventory, loader, path, cache):
        '''Return dynamic inventory from source '''
        super(InventoryModule, self).parse(inventory, loader, path, cache)

        # Read the inventory YAML file
        self._read_config_data(path)
        try:
            # Store the options from the YAML file
            self.plugin = self.get_option('plugin')
            self.tf_file = self.get_option('terraform_file')
        except Exception as e:
            raise AnsibleParserError(
            'All correct options required: {}'.format(e))

        #Check if terraform file exists and readable
        if (os.access(self.tf_file, os.R_OK) == False):
            raise AnsibleError('Terraform file {} is not readable by current user'.format(self.tf_file))

        #Read the terraform file
        tfstate = json.load(open(self.tf_file))

        tfstate = tfstate["modules"][0]

        #Get all the IP addresses
        floating_ip=tfstate['outputs']['ssh_floating_ip_address']['value']
        worker_hosts=tfstate['outputs']['ssh_private_ip_addresses']['value']

        #Output a file with env variables
        env_file = "ssh/env.sh"
        self.output_env_file(env_file, tfstate)

        #Output a file with ssh private key
        ssh_key_file = "ssh/private_ssh_key"
        self.output_ssh_key(ssh_key_file, tfstate)

        #Output ssh config
        ssh_cfg_file = "ssh/ssh.cfg"
        self.output_ssh_cfg(ssh_cfg_file, ssh_key_file, tfstate)

        #Add a default group to the inventory
        default_grp='default'
        self.inventory.add_group(default_grp)

        #Add hosts to the default group
        self.inventory.add_host(host=floating_ip, group=default_grp)
        self.inventory.set_variable(floating_ip, 'ansible_ssh_private_key_file', ssh_key_file)
        self.inventory.set_variable(floating_ip, 'ansible_become', 'true')
        self.inventory.set_variable(floating_ip, 'ansible_become_user', 'root')
        self.inventory.set_variable(floating_ip, 'ansible_user', 'root')
        for worker in worker_hosts:
            self.inventory.add_host(host=worker, group=default_grp)
            self.inventory.set_variable(worker, 'ansible_ssh_private_key_file', ssh_key_file)
            self.inventory.set_variable(worker, 'ansible_become', 'true')
            self.inventory.set_variable(worker, 'ansible_become_user', 'root')
            self.inventory.set_variable(worker, 'ansible_user', 'root')

    def output_env_file(self, env_file, tfstate):
        with open(env_file, "w") as env_file_fh:
            print ("export WMLCE_VERSION={}".format(tfstate['outputs']['wmlce_version']['value']), file=env_file_fh)
            print ("export PYTHON_VERSION={}".format(tfstate['outputs']['python_version']['value']), file=env_file_fh)
            vm_profile = tfstate['outputs']['vm_profile']['value']
            print (vm_profile)
            if ('gp' in vm_profile):
                print ("export GPU_CONFIG=1", file=env_file_fh)
            else:
                print ("export GPU_CONFIG=0", file=env_file_fh)


    def output_ssh_key (self, ssh_key_file, tfstate):
        with open(ssh_key_file, "w") as ssh_key_fh:
            print(tfstate['outputs']['ssh_private_key']['value'], file=ssh_key_fh)
        os.chmod(ssh_key_file, 0o600)

    def output_ssh_cfg (self, ssh_cfg_file, ssh_key_file, tfstate):
        floating_ip=tfstate['outputs']['ssh_floating_ip_address']['value']
        worker_hosts=tfstate['outputs']['ssh_private_ip_addresses']['value']
        with open(ssh_cfg_file, "w") as ssh_cfg_fh:
            #Entry for each of the worker VMs
            for worker in worker_hosts:
                print("Host {}".format(worker), file=ssh_cfg_fh)
                print("  HostName {}".format(worker), file=ssh_cfg_fh)
                print("  User root", file=ssh_cfg_fh)
                print("  ProxyCommand ssh -W %h:%p -i {}  root@{}".format(ssh_key_file, floating_ip), file=ssh_cfg_fh)
                print("  IdentityFile {}".format(ssh_key_file), file=ssh_cfg_fh)
                print("  IdentitiesOnly=yes", file=ssh_cfg_fh)

            #Entry for the main VM with floating IP to route all ssh traffic through
            print ("Host {}".format(floating_ip), file=ssh_cfg_fh)
            print ("  HostName {}".format(floating_ip), file=ssh_cfg_fh)
            print ("  User root", file=ssh_cfg_fh)
            print ("  IdentityFile {}".format(ssh_key_file), file=ssh_cfg_fh)
            print ("  IdentitiesOnly=yes", file=ssh_cfg_fh)
            print ("  ControlMaster auto", file=ssh_cfg_fh)
            print ("  ControlPath ~/.ssh/ansible-root@%h:%p", file=ssh_cfg_fh)
            print ("  ControlPersist 50m", file=ssh_cfg_fh)
