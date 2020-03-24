#!/bin/bash -e
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

#Without this sleep, there are errors from update manager's daemon as it is
#being used by another process. Need to figure out a way to wait for it to
#free up before removing the sleep.
sleep 60

#source env file
#source /tmp/scripts/env.sh

echo "In GPU driver install script"
echo "GPU_CONFIG = $GPU_CONFIG"
if [ "$GPU_CONFIG" -eq 1 ]; then

    # Install NVIDIA Driver
    modinfo nvidia && which nvidia-smi
    has_gpu_driver=$?

    if [ $has_gpu_driver -ne 0 ]; then

      # Install Nvidia
      echo "Downloading Nvidia drivers."
      deb_file=nvidia-driver-local-repo-ubuntu1804-440.33.01_1.0-1_ppc64el.deb
      wget http://us.download.nvidia.com/tesla/440.33.01/${deb_file}

      echo "Installing Nvidia drivers."
      dpkg -i ${deb_file}
      apt-key add /var/nvidia-driver-local-repo-440.*/*.pub

      apt-get -o Dpkg::Use-Pty=0 update -qq
      apt-get -o Dpkg::Use-Pty=0 install -qq cuda-drivers

      # Cleaning up
      echo "Removing deb file "
      dpkg -P `dpkg -l | grep nvidia-driver-local-repo | cut -d " " -f 3`
      apt-get clean -y
      rm ${deb_file}

      echo "Reloading the daemon"
      systemctl daemon-reload
      systemctl enable nvidia-persistenced

      nvidia-smi
    else
      echo "Nvidia drivers installed on machine already. Skipping install of drivers."
    fi
fi

