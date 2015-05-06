# rpc-extras
Optional add-ons for Rackspace Private Cloud

# os-ansible-deploy integration

The rpc-extras repo includes add-ons for the Rackspace Private Cloud product
that integrate with the 
[os-ansible-deployment](https://github.com/stackforge/os-ansible-deployment)
set of Ansible playbooks and roles.
These add-ons extend the 'vanilla' OpenStack environment with value-added
features that Rackspace has found useful, but are not core to deploying an
OpenStack cloud.

# Ansible Playbooks

Plays:

* `elasticsearch.yml` - deploys an elasticsearch host
* `haproxy` - deploys haproxy configurations for elasticsearch and kibana
* `horizon_extensions.yml` - rebrands the horizon dashboard for Rackspace,
as well as adding a Rackspace tab and a Solutions tab, which provides
Heat templates for commonly deployed applications.
* `kibana.yml` - Setup Kibana on the Kibana hosts for the logging dashboard.
* `logstash.yml` - deploys a logstash host. If this play is used, be sure to 
uncomment the related block in user_extra_variables.yml before this play is 
run and then rerun the appropriate plays in os-ansible-deployment after this 
play to ensure that rsyslog ships logs to logstash. See steps 11 - 13 below 
for more.
* `rpc-support.yml` - provides holland backup service, support SSH key
distribution, custom security group rules, bashrc settings, and other
miscellaneous tasks helpful to support personnel.
* `setup-maas.yml` - deploys, sets up, and installs Rackspace
[MaaS](http://www.rackspace.com/cloud/monitoring) checks
for Rackspace Private Clouds.
* `setup-logging.yml` - deploys and configures Logstash, Elasticsearch, and 
Kibana to tag, index, and expose aggregated logs from all hosts and containers
in the deployment using the related plays mentioned above. See steps 11 - 13 
below for more.
* `site.yml` - deploys all the above playbooks.

Basic Setup:

1. Clone [rpc-extras](https://github.com/rcbops/rpc-extras) with the
--recursive option to get all the submodules from within /opt.
2. Prepare the os-ansible-deployment configuration.
  1. copy everything from os-ansible-deployment/etc/openstack_deploy into
  /etc/openstack_deploy
  2. copy everything from rpcd/etc/openstack_deploy into /etc/openstack_deploy
  3. Edit configurations in /etc/openstack_deploy
    1. example inventory is openstack_user_variables.yml.aio and should be
    renamed if you want to set up an AIO cluster.  There is a tool to
    generate the inventory for RAX datacenters, otherwise it will need to be
    coded by hand.
    2. uncomment the logstash block if desired
3. __Optional__ If building an AIO execute `scripts/bootstrap-aio.sh` within
/opt/rpc-extras/os-ansible-deployment
4. Execute `scripts/bootstrap-ansible.sh` within
/opt/rpc-extras/os-ansible-deployment
5. Generate the random passwords for the extras by executing
`scripts/pw-token-gen.py --file /etc/openstack_deploy/user_extras_secrets.yml`
within /opt/rpc-extras/os-ansible-deployment
6. Change to the `/opt/rpc-extras/os-ansible-deployment/playbooks` directory and
execute the plays. You can optionally execute `scripts/run-playbooks.sh` from
within /opt/rpc-extras/os-ansible-deployment
7. Change to the `/opt/rpc-extras/rpcd/playbooks` directory and execute your
desired plays.  EG:

```bash
openstack-ansible site.yml
```

8. __Optional__ If the logstash play is included in the deployment, from the
os-ansible-deployment/playbooks directory, run the following to apply the
needed changes to rsyslog configurations in order to ship logs to logstash.

```bash
openstack-ansible setup-everything.yml --tags rsyslog-client
```

# Ansible Roles

* `elasticsearch`
* `horizon_extensions`
* `kibana`
* `logstash`
* `rpc_maas`
* `rpc_support`

