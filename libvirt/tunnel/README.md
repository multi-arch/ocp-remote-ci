The repository holds ports confirguration for libvirt and bastion tunnels.

# Setup Tunnel

To setup the reverse tunnel for bastion use the ```tunnel.sh``` script. This script takes input from a yaml file consisting of the profiles for a specific architecture along with the cluster capacity and different ports for libvirt, api, http and https. The script uses the HOSTNAME to map the profile.

1. Create a user ```ocp```
2. Switch to that user ```sudo su - ocp```
3. Make sure its ssh key exists ```(set -xe; cd ~/; [[ -d .ssh/ ]] || (mkdir .ssh/; chmod 700 .ssh/); cd .ssh/; ssh-keygen -t rsa -P "" -f id_rsa)```
   And is authorized ```tbd```
4. Clone the ocp-remote-ci repo
5. Add the respective token in ```profile_${HOSTNAME}.yaml```
   For example:
```(cd libvirt/tunnel/; token="example"; sed -i -e 's,token: "",token: "'${token}'",' profile_$(hostname).yaml)```
6. Execute the tunnel script as root to see if everything works ```sudo bash -x /home/ocp/ocp-remote-ci/libvirt/tunnel/tunnel.sh```
7. To run the bastion as a service, we can use ```apici.service```
   To install it do the following:
```
sudo install --owner=root --group=root /home/ocp/ocp-remote-ci/libvirt/tunnel/apici.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start apici.service
sudo systemctl status apici.service
```
8. To view the logs ```journalctl --boot --all --no-pager --unit=apici.service```

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
