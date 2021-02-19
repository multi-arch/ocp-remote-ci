The repository holds ports confirguration for libvirt and bastion tunnels.

# Setup Tunnel

To setup the reverse tunnel for bastion use the ```tunnel.sh``` script. This script takes input from a yaml file consisting of the profiles for a specific architecture along with the cluster capacity and different ports for libvirt, api, http and https. The script uses the HOSTNAME to map the profile.

1. Create a user ```ocp```
2. Clone the ocp-remote-ci repo inside ```/home/ocp```
3. Add the respective token in ```profile_${HOSTNAME}.yaml```
4. Execute the tunnel script ```ocp-remote-ci/libvirt/tunnel/tunnel.sh```
4. To run the bastion as a service, we can use ```apici.service```

## Requirements:

- Update yq version 4+ to generate new profiles.
- Verify date package is installed.

## Generate Ports for new profile

To generate the associated ports for a new profile:
1. Create a yaml file with name ```profile_${HOSTNAME}.yaml```.[1]
2. Add the respective token, arch, cluster_capacity, cluster_id and environment.
3. Execute the ```generate-ports.sh``` script to update the yaml file libvirt port configuration with the default values for libvirt, api, http and https using the cluster capacity and cluster id.

[1] Sample ```profile_${HOSTNAME}.yaml``` file
```
profile:
  arch: "{architecture_name}"
  cluster_capacity: {cluster_capacity}
  cluster_id: {cluster_id}
  environment: "{env_name}"
  token: "{access_token}"
```
