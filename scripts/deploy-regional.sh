# cherry-pick the required patches for os-ansible-deployment
RPC_WORKING_FOLDER=${RPC_WORKING_FOLDER:-"/opt/rpc-openstack"}
cd ${RPC_WORKING_FOLDER}/os-ansible-deployment
# lp1463366
git fetch https://review.openstack.org/stackforge/os-ansible-deployment
refs/changes/64/189664/1 && git cherry-pick FETCH_HEAD
# lp 1462529
git fetch https://review.openstack.org/stackforge/os-ansible-deployment
refs/changes/26/188926/3 && git cherry-pick FETCH_HEAD

# set the variables to deploy the AIO without the ELK stack (to cut build time)
cd ${RPC_WORKING_FOLDER}
export DEPLOY_AIO="yes"
export DEPLOY_ELK="no"

# resurrect the ssh_retry plugin for your sanity
mkdir -p os-ansible-deployment/playbooks/plugins/connection_plugins/
wget -O os-ansible-deployment/playbooks/plugins/connection_plugins/ssh_retry.py
\
https://raw.githubusercontent.com/stackforge/os-ansible-deployment/juno/rpc_deployment/plugins/connection_plugins/ssh_retry.py
sed -i '/lookup_plugins/a \
\
# ssh_retry connection plugin \
connection_plugins = plugins/connection_plugins \
transport = ssh_retry' os-ansible-deployment/playbooks/ansible.cfg
sed -i '/lookup_plugins/a \
\
# ssh_retry connection plugin \
connection_plugins =
/opt/rpc-openstack/os-ansible-deployment/playbooks/plugins/connection_plugins \
transport = ssh_retry' rpcd/playbooks/ansible.cfg

# set the region and build
export SERVICE_REGION=${SERVICE_REGION:-"Region1"}
./scripts/deploy.sh

