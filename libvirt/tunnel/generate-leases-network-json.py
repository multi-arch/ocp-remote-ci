#!/usr/bin/python3

import json
import logging
import os
import random
import re
import yaml

BOOSTRAP_OFFSET = 10
CONTROL_PLANE_OFFSET = 11
COMPUTE_OFFSET = 51

# Setting random to 0 for partial determinism
# If running on the same input, the generated mac addresses should be the same
# for all users
random.seed(0)


def build_network(networks, filename):
    with open(filename, "r") as stream:
        try:
            profile = yaml.safe_load(stream)
            logging.debug(profile)
        except yaml.YAMLError as exc:
            logging.error(str.format("Failed to parse: {0}", filename))
            logging.exception(exc)
            return

        # Sanitize input
        try:
            arch = profile['profile']['arch']
        except AttributeError as exc:
            logging.error("Couldn't find arch for profile: {0}", profile)
            logging.exception(exc)
        try:
            # The profile's cluster_id variable is really a 0 indexed host identifier
            host_id = profile['profile']['cluster_id']
        except AttributeError as exc:
            logging.error(str.format(
                "Couldn't find cluster_id for profile: {0}", profile))
            logging.exception(exc)
        try:
            cluster_capacity = profile['profile']['cluster_capacity']
        except AttributeError as exc:
            logging.error(str.format(
                "Couldn't find cluster_capacity for profile: {0}", profile))
            logging.exception(exc)

        # Initialize arch-based dictionary
        if arch not in networks:
            networks[arch] = {}

        if cluster_capacity <= 1:
            logging.warning(str.format(
                "Profile {0} sets cluster capacity to 0. No leases will be created.", filename))
            return

        for cluster_id in range(cluster_capacity):
            lease = str.format(
                "libvirt-{0}-{1}-{2}", arch, host_id, cluster_id)
            logging.debug(str.format("Setting network for lease: {0}", lease))
            networks[arch][lease] = {
                'hostname': filename.split("_")[1].split(".")[0],
                'subnet': 126 if cluster_id == 0 else cluster_id,
                'control-plane': [],
                'compute': [],
                'bootstrap': []
            }
            # Bootstrap Network
            networks[arch][lease]['bootstrap'].append({
                'ip': str.format("192.168.{0}.{1}", networks[arch][lease]['subnet'], BOOSTRAP_OFFSET),
                'mac': str.format("02:00:00:{0:02x}:{1:02x}:{2:02x}", random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
            })

            # Control Plane
            for i in range(3):
                networks[arch][lease]['control-plane'].append({
                    'ip': str.format("192.168.{0}.{1}", networks[arch][lease]['subnet'], CONTROL_PLANE_OFFSET + i),
                    'mac': str.format("02:00:00:{0:02x}:{1:02x}:{2:02x}", random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
                })

            # Compute Nodes
            for i in range(2):
                networks[arch][lease]['compute'].append({
                    'ip': str.format("192.168.{0}.{1}", networks[arch][lease]['subnet'], COMPUTE_OFFSET + i),
                    'mac': str.format("02:00:00:{0:02x}:{1:02x}:{2:02x}", random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
                })


networks = {}
directory = os.fsencode(os.getcwd())

for file in os.listdir(directory):
    filename = os.fsdecode(file)
    if re.match("profile_.*\.y[a]?ml", filename):
        print(str.format("Profile found: {0}", os.path.join(
            os.fsdecode(directory), filename)))
        build_network(networks, filename)

    else:
        logging.info(str.format("Skipping file: {0}", os.path.join(
            os.fsdecode(directory), filename)))
        continue

for arch in networks:
    with open(str.format("libvirt-{0}.json", arch), "w") as lease_file:
        json.dump(networks[arch], lease_file, indent=2)
