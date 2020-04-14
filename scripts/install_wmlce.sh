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

#source env file
source /tmp/scripts/env.sh

#Install Miniconda
#Sometimes wget fails to resolve repo.anaconda.com, that's why, adding a retry loop
retry=0
maxRetries=5
retryInterval=5
until [ ${retry} -ge ${maxRetries} ]
do
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-ppc64le.sh && break
	retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done

if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

bash Miniconda3-latest-Linux-ppc64le.sh -b -f
rm Miniconda3-latest-Linux-ppc64le.sh

#Get conda command to work
eval "$($HOME/miniconda3/bin/conda shell.bash hook)"

#Setup conda environment
conda config --prepend channels https://wml-ce-proxy-cos.s3.direct.us-east.cloud-object-storage.appdomain.cloud/
conda create --name wmlce_env_${WMLCE_VERSION}  python=${PYTHON_VERSION} -y
conda activate wmlce_env_${WMLCE_VERSION}

#Install wmlce
export IBM_POWERAI_LICENSE_ACCEPT=yes
conda install powerai=${WMLCE_VERSION} -y

#Activate this env every time user ssh into this VM
echo "source ${HOME}/miniconda3/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
echo "conda activate wmlce_env_${WMLCE_VERSION}" >> ${HOME}/.bashrc
