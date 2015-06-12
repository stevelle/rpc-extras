#!/usr/bin/env bash

# Preamble to deploy
#   Adapted from the prototype RPC regional-deploy script
set -e -u -x
set -o pipefail

# Common Paths
RPC_WORKING_FOLDER=${RPC_WORKING_FOLDER:-"/opt/rpc-openstack"}
OSAD_DIR='${RPC_WORKING_FOLDER}/os-ansible-deployment'
RPCD_DIR='${RPC_WORKING_FOLDER}/rpcd'
ETC_DIR='/etc/openstack_deploy'

# Optional Work Scopes
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"no"}

# Ubuntu repos
UBUNTU_RELEASE=$(lsb_release -sc)
UBUNTU_REPO=${UBUNTU_REPO:-"https://mirror.rackspace.com/ubuntu"}
UBUNTU_SEC_REPO=${UBUNTU_SEC_REPO:-"https://mirror.rackspace.com/ubuntu"}

# Required variables
export SERVICE_REGION=${SERVICE_REGION:-"Region1"}
export PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-$(ip route show | awk '/default/ { print $NF }')}
export PUBLIC_ADDRESS=${PUBLIC_ADDRESS:-$(ip -o -4 addr show dev ${PUBLIC_INTERFACE} | awk -F '[ /]+' '/global/ {print $4}')}
export GET_PIP_URL=${GET_PIP_URL:-"https://bootstrap.pypa.io/get-pip.py"}
export RABBITMQ_PACKAGE_URL=${RABBITMQ_PACKAGE_URL:-""}
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}

source ${OSAD_DIR}/scripts/scripts-library.sh

# Prepare OSAD for deployment -----------------------------------------------
# cherry-pick the required patches for os-ansible-deployment
cd ${OSAD_DIR}
# lp 1463366 - make the service regions work properly
git fetch https://review.openstack.org/stackforge/os-ansible-deployment refs/changes/64/189664/3 && git cherry-pick FETCH_HEAD
# lp 1462529 - allow db configuration per service
git fetch https://review.openstack.org/stackforge/os-ansible-deployment refs/changes/26/188926/4 && git cherry-pick FETCH_HEAD
# lp 1463772 - allow Horizon to be configured for multiple regions
git fetch https://review.openstack.org/stackforge/os-ansible-deployment refs/changes/18/190118/2 && git cherry-pick FETCH_HEAD
# lp 1463862 - split environment file into multiple parts
git fetch https://review.openstack.org/stackforge/os-ansible-deployment refs/changes/20/190220/2 && git cherry-pick FETCH_HEAD
# lp 1464329 - allow haproxy configuration to be overridden
git fetch https://review.openstack.org/stackforge/os-ansible-deployment refs/changes/21/190721/1 && git cherry-pick FETCH_HEAD

# resurrect the ssh_retry plugin for your sanity
cd ${RPC_WORKING_FOLDER}
mkdir -p os-ansible-deployment/playbooks/plugins/connection_plugins/
wget -O os-ansible-deployment/playbooks/plugins/connection_plugins/ssh_retry.py \
https://raw.githubusercontent.com/stackforge/os-ansible-deployment/juno/rpc_deployment/plugins/connection_plugins/ssh_retry.py
sed -i '/lookup_plugins/a \
\
# ssh_retry connection plugin \
connection_plugins = plugins/connection_plugins \
transport = ssh_retry' os-ansible-deployment/playbooks/ansible.cfg
sed -i '/lookup_plugins/a \
\
# ssh_retry connection plugin \
connection_plugins = /opt/rpc-openstack/os-ansible-deployment/playbooks/plugins/connection_plugins \
transport = ssh_retry' rpcd/playbooks/ansible.cfg


# Ensure that the https apt transport is available before doing anything else
apt-get update && apt-get install -y apt-transport-https

# Set the host repositories to only use the same ones, always, for the sake of consistency.
cat > /etc/apt/sources.list <<EOF
# Normal repositories
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE} main restricted
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE}-updates main restricted
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE} universe
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE}-updates universe
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE} multiverse
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE}-updates multiverse
# Backports repositories
deb ${UBUNTU_REPO} ${UBUNTU_RELEASE}-backports main restricted universe multiverse
# Security repositories
deb ${UBUNTU_SEC_REPO} ${UBUNTU_RELEASE}-security main restricted
deb ${UBUNTU_SEC_REPO} ${UBUNTU_RELEASE}-security universe
deb ${UBUNTU_SEC_REPO} ${UBUNTU_RELEASE}-security multiverse
EOF

# Update the package cache
apt-get update
# Remove known conflicting packages in the base image
apt-get purge -y libmysqlclient18 mysql-common

# Install required packages
apt-get install -y bridge-utils \
                   build-essential \
                   curl \
                   git-core \
                   ipython \
                   linux-image-extra-$(uname -r) \
                   lvm2 \
                   python2.7 \
                   python-dev \
                   tmux \
                   vim \
                   vlan \
                   xfsprogs

# Ensure newline at end of file (missing on Rackspace public cloud Trusty image)
if ! cat -E /etc/ssh/sshd_config | tail -1 | grep -q "\$$"; then
  echo >> /etc/ssh/sshd_config
fi

# Remove the pip directory if its found
if [ -d "${HOME}/.pip" ];then
  rm -rf "${HOME}/.pip"
fi

# Install pip
if [ ! "$(which pip)" ];then
    curl ${GET_PIP_URL} > /opt/get-pip.py
    python2 /opt/get-pip.py || python /opt/get-pip.py
fi

# Install requirements if there are any
if [ -f "requirements.txt" ];then
    pip2 install -r requirements.txt || pip install -r requirements.txt
fi

# bootstrap ansible if need be
which openstack-ansible || ./scripts/bootstrap-ansible.sh

# Create /etc/rc.local if it doesn't already exist
if [ ! -f "/etc/rc.local" ];then
  touch /etc/rc.local
  chmod +x /etc/rc.local
fi

# Build the loopback drive for swap to use
if [ ! "$(swapon -s | grep -v Filename)" ]; then
  memory_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  if [ "${memory_kb}" -lt "8388608" ]; then
    swap_size="4294967296"
  else
    swap_size="8589934592"
  fi
  loopback_create "/opt/swap.img" ${swap_size} thick swap
  # Ensure swap will be used on the host
  if [ ! $(sysctl vm.swappiness | awk '{print $3}') == "10" ];then
    sysctl -w vm.swappiness=10 | tee -a /etc/sysctl.conf
  fi
  swapon -a
fi

# Apply OSAD configuration files
cp -R ${OSAD_DIR}/etc/openstack_deploy /etc/

# Ensure the conf.d directory exists
if [ ! -d "/etc/openstack_deploy/conf.d" ];then
  mkdir -p "/etc/openstack_deploy/conf.d"
fi

# Set the running kernel as the required kernel
echo "required_kernel: $(uname --kernel-release)" | tee -a ${ETC_DIR}/user_variables.yml

# Set the Ubuntu apt repository used for containers to the same as the host
echo "lxc_container_template_main_apt_repo: ${UBUNTU_REPO}" | tee -a ${ETC_DIR}/user_variables.yml
echo "lxc_container_template_security_apt_repo: ${UBUNTU_REPO}" | tee -a ${ETC_DIR}/user_variables.yml

if [ ! -z "${RABBITMQ_PACKAGE_URL}" ]; then
  echo "rabbitmq_package_url: ${RABBITMQ_PACKAGE_URL}" | tee -a ${ETC_DIR}/user_variables.yml
fi

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file ${ETC_DIR}/user_secrets.yml

# change the generated passwords for the OpenStack (admin)
sed -i "s/keystone_auth_admin_password:.*/keystone_auth_admin_password: ${ADMIN_PASSWORD}/" ${ETC_DIR}/user_secrets.yml
sed -i "s/external_lb_vip_address:.*/external_lb_vip_address: ${PUBLIC_ADDRESS}/" ${ETC_DIR}/openstack_user_config.yml

# adjust the container layout to only build what's necessary
rm -f ${ETC_DIR}/env.d/*
cp ${OSAD_DIR}/etc/openstack_deploy/env.d/{keystone,galera,infra,memcache,pkg_repo,rabbitmq,shared-infra}.yml /etc/openstack_deploy/env.d/

# Prepare RPC for deployment ------------------------------------------------
# Apply RPC configuration files
cp -R ${RPCD_DIR}/etc/openstack_deploy/* ${ETC_DIR}/
# apply the templates for cross-region identity cloud
mv ${ETC_DIR}/openstack_user_config.yml.cross-region-identity ${ETC_DIR}/openstack_user_config.yml
# apply customizations to user_config.yml
sed -i "s/__EXTERNAL_LB_VIP__/${PUBLIC_ADDRESS}/" ${ETC_DIR}/openstack_user_config.yml
# apply customizations to user_variables.yml
echo "galera_cluster_name: identity_galera_cluster" | tee -a ${ETC_DIR}/user_variables.yml
# ensure that the elasticsearch JVM heap size is limited
sed -i 's/# elasticsearch_heap_size_mb/elasticsearch_heap_size_mb/' ${ETC_DIR}/user_extras_variables.yml
# set the kibana admin password
sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" ${ETC_DIR}/user_extras_secrets.yml
# set the load balancer name to the host's name
sed -i "s/lb_name: .*/lb_name: '$(hostname)'/" ${ETC_DIR}/user_extras_variables.yml
# set the ansible inventory hostname to the host's name
sed -i "s/aio1/$(hostname)/" ${ETC_DIR}/openstack_user_config.yml

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file ${ETC_DIR}/user_extras_secrets.yml

# ensure that the ELK containers aren't created if they're not
# going to be used
if [[ "${DEPLOY_ELK}" != "yes" ]]; then
  rm -f ${ETC_DIR}/env.d/{elasticsearch,logstash,kibana}.yml
fi

# setup the haproxy load balancer
if [[ "${DEPLOY_HAPROXY}" == "yes" ]]; then
  cat ${RPCD_DIR}/scripts/identity_haproxy_variables.yml >> ${ETC_DIR}/user_variables.yml
fi
