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
3. If the environment will be running httpd (e.g. ppc64le to support agent-based installs), add an httpd_port.
4. If you want to set the ports manually and not rely on the automation, set the key `generate_ports: false` in the profile.
5. Execute the ```generate-ports.sh``` script to update the yaml file libvirt port configuration with the default values for libvirt, api, http and https using the cluster capacity and cluster id.

[1] Sample ```profile_${HOSTNAME}.yaml``` file
```
profile:
  arch: "{architecture_name}"
  cluster_capacity: {cluster_capacity}
  cluster_id: {cluster_id}
  environment: "{env_name}"
```

## Generate leases network json

To generate the ```libvirt-${arch}.json``` files for your profiles:
1. Ensure that each of the ```profile_${HOSTNAME}.yaml``` have a valid profile.
2. Execute the ```generate-leases-network-json.py``` script to update the ```libvirt-${arch}.json``` files with information about the hostname, subnet, IP addresses*, and MAC addresses*.
* These are only used in UPI based deployments.
3. Got to `https://vault.ci.openshift.org`, login with your SSO credentials, and select `kv`. You should see `libvirt-${arch}` entries. If not, reach out on `#forum-ocp-multi-arch-ci` in Red Hat internal slack to be given access.
4. Select an architecture, and click on the corresponding `libvirt-${arch}` entry. Then, select `leases` followed by `Create a new version +`.
5. Copy the contents of the generated ```libvirt-${arch}.json``` in its entity, click on the eye icon in the value (i.e. second column) of the row whose first column value is `leases`, and replace the contents of that text box with the contents of your clipboard.
6. Finally, scroll to the bottom of the page and hit save. Then, hit save again.
7. To verify that you entered the data correctly, you may need to reload the vault page before displaying the entries since it takes a second to propagate.
