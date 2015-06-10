#!/usr/bin/env bash
# Copyright 2015, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This configures a demo network on Rackspace public cloud.
# If planning a production deployment read the documentation

## Shell Opts ----------------------------------------------------------------

set -e -u

## Ensure required ENV vars set ----------------------------------------------

if [ -z $IDENT_NUMBER ]; then
    echo "export IDENT_NUMBER=some_number and try again."
    exit 1
fi
if [ -z $MGMT_NET ]; then
    echo "export MGMT_NET="some value" and try again."
    exit 1
fi

## Main ----------------------------------------------------------------------

# Rewrite the management network
INTERFACES="/etc/network/interfaces"
INTERFACES_D="/etc/network/interfaces.d"

# Define hostnames if missing
if [ $(grep ident1 /etc/hosts | grep ident2 | wc -l) -eq 0 ]; then
  cat >> /etc/hosts <<EOF
172.29.236.1 ident1
172.29.236.2 ident2
172.29.236.3 ident3
EOF
fi

found=0
tmp_file=$(mktemp)

for interface in eth1 eth2; do
  ifdown $interface
done

# Retain public and private network
cat $INTERFACES | while read line; do
  if echo "$line" | grep "# Label ${MGMT_NET}"; then
    found=1
  fi

  if [ $found -eq 1 ] && [ "$line" = "" ]; then
    found=0
  elif [ $found -eq 0 ]; then
    echo "$line" >> $tmp_file
  fi
done

echo "source ${INTERFACES_D}/*.cfg" >> $tmp_file

mv -f $tmp_file ${INTERFACES}

# rewrite the tenent network portion, adding bridge on vxlan2 over it
cat > ${INTERFACES_D}/eth2.cfg <<EOF
auto eth2
iface eth2 inet static
    address 172.29.232.${IDENT_NUMBER}
    netmask 255.255.252.0
EOF

cat > ${INTERFACES_D}/vxlan2.cfg <<EOF
auto vxlan2
iface vxlan2 inet manual
        pre-up ip link add vxlan2 type vxlan id 2 group 239.0.0.16 ttl 4 dev eth2
        up ip link set vxlan2 up
        down ip link set vxlan2 down
EOF

cat > ${INTERFACES_D}/br-mgmt.cfg <<EOF
auto br-mgmt
iface br-mgmt inet static
    address 172.29.236.${IDENT_NUMBER}
    netmask 255.255.252.0
    bridge_ports vxlan2
EOF

ifup -a
