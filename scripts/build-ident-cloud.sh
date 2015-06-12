#!/usr/bin/env bash

set -e -u -x
set -o pipefail

# Common Paths
RPC_WORKING_FOLDER=${RPC_WORKING_FOLDER:-"/opt/rpc-openstack"}
OSAD_DIR='${RPC_WORKING_FOLDER}/os-ansible-deployment'
RPCD_DIR='${RPC_WORKING_FOLDER}/rpcd'

# Optional Work Scopes
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"no"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}

source ${OSAD_DIR}/scripts/scripts-library.sh

# Perform OSAD for deployment -----------------------------------------------
# setup the haproxy load balancer
cd ${OSAD_DIR}/playbooks/

if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    install_bits haproxy-install.yml
fi

# setup the hosts and build the basic containers
install_bits setup-hosts.yml

# setup the infrastructure
install_bits setup-infrastructure.yml

# setup keystone only
install_bits os-keystone-install.yml

# Perform RPC for deployment ------------------------------------------------
# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# build the RPC python package repository
install_bits repo-build.yml

# configure all hosts and containers to use the RPC python packages
install_bits repo-pip-setup.yml

# configure everything for RPC support access
install_bits rpc-support.yml

# configure the horizon extensions
# disabled until such time as we are ready to deploy horizon in this cloud
# install_bits horizon_extensions.yml

# deploy and configure RAX MaaS
if [[ "${DEPLOY_MAAS}" == "yes" ]]; then
  install_bits setup-maas.yml
fi

# deploy and configure the ELK stack
if [[ "${DEPLOY_ELK}" == "yes" ]]; then
  install_bits setup-logging.yml

  # deploy the LB required for the ELK stack
  if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
    install_bits haproxy.yml
  fi
fi
