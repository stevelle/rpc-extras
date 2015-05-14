#!/usr/bin/env python
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# (c) 2015, Nolan Brubaker <nolan.brubaker@rackspace.com>

# This file takes an existing rpc_user_config.yml file and produces
# a 'repo-infra_hosts' stanza to append to the file for 10.x to 11.x upgrades.

from yaml import load, dump

try:
    from yaml import CLoader as Loader
except ImportError:
    from yaml import Loader

import sys

if len(sys.argv) < 2:
    print("Usage: make_repo_stanza.py /path/to/rpc_user_config.yml")
    print("Exit codes:\n")
    print("\t 1 - no infra_hosts stanza found.")
    print("\t 2 - repo-infra_hosts stanza already exists")
    print("\t 3 - no file provided")
    exit(3)

with open(sys.argv[1], 'r') as f:
    data = load(f.read(), Loader=Loader)
    if 'infra_hosts' not in data.keys():
        print("'infra_hosts' stanza not found! Make sure you're using an RPC "
              "9.x or 10.x rpc_user_config.yml file.")
        exit(1)

    # Given how this script is used, we don't want to make a stanza
    # and keep appending it to the file; if one already exists,
    # we should avoid doing anything.
    if 'repo-infra_hosts' in data.keys():
        exit(2)

    # Make a new dictionary so that we get the section name in
    # the dump; if we merely make a new key in the 'data' dict
    # and print data['repo-infra_hosts'], we don't get 'repo-infra_hosts'
    # in the output.
    print_dict = {}
    print_dict['repo-infra_hosts'] = data['infra_hosts']

    # default_flow_style makes sure we have a block syntax
    print(dump(print_dict, default_flow_style=False))
