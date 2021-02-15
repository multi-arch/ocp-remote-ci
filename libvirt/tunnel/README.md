The repository holds ports confirguration for libvirt and bastion tunnels.

# Setup Tunnel

To setup the reverse tunnel for bastion use the ```tunnel.sh``` script. This script takes input from a yaml file consisting of the profiles for a specific architecture along with the cluster capacity and different ports for libvirt, api, http and https. The script uses the HOSTNAME to map the profile.

## Requirements:

yq version 4+ to generate new profiles.

## Generate Ports for new profile

To generate the associated ports for a new profile, create a yaml file with name ```profile_${HOSTNAME}.yaml```. Execute the generate-ports.sh script to update the yaml file with the libvirt port configuration using the default values for libvirt, api, http and https using the cluster capacity and cluster id.

Sample ```profile_${HOSTNAME}.yaml``` file
```
profile:
  arch: "{architecture_name}"
  cluster_capacity: {cluster_capacity}
  cluster_id: {cluster_id}
  environment: "{env_name}"
  token: "{access_token}"
```
