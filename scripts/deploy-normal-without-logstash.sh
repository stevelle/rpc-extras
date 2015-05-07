#!/usr/bin/env bash

cd /opt/rpc-extras/os-ansible-deployment/
./scripts/bootstrap-ansible.sh
./scripts/run-playbooks.sh
cd /opt/rpc-extras/rpcd/playbooks/
openstack-ansible site.yml
