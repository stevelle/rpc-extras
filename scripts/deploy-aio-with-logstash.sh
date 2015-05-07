#!/usr/bin/env bash

cd /opt/rpc-extras/os-ansible-deployment/
./scripts/bootstrap-aio.sh
./scripts/bootstrap-ansible.sh
cd playbooks
openstack-ansible openstack-hosts-setup.yml lxc-hosts-setup.yml
cd /opt/rpc-extras/rpcd/playbooks/
openstack-ansible elasticsearch.yml logstash.yml
cd /opt/rpc-extras/os-ansible-deployment/
./scripts/run-playbooks.sh
cd /opt/rpc-extras/rpcd/playbooks/
openstack-ansible site.yml
