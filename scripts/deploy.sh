#!/usr/bin/env bash

export RPCD_LOGSTASH=${RPCD_LOGSTASH:-"FALSE"}
export RPCD_AIO=${RPCD_AIO:-"FALSE"}

# Enable logstash if wanted
if [ "${RPCD_LOGSTASH}" == "yes" ]; then
  mv /etc/openstack_deploy/user_logging_variables.yml.example /etc/openstack_deploy/user_logging_variables.yml
fi

# basic setup
cd /opt/rpc-extras/os-ansible-deployment/
./scripts/bootstrap-ansible.sh
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_extras_secrets.yml
cd /opt/rpc-extras/os-ansible-deployment/playbooks/
openstack-ansible setup-hosts.yml

# setup logstash
cd /opt/rpc-extras/rpcd/playbooks/
openstack-ansible setup-logging.yml

# setup openstack
cd /opt/rpc-extras/os-ansible-deployment/
./scripts/run-playbooks.sh

# setup the rest
cd /opt/rpc-extras/rpcd/playbooks/
openstack-ansible horizon_extensions.yml
openstack-ansible rpc-support.yml
openstack-ansible setup-maas.yml
