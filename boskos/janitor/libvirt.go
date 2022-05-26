package main

import (
	"fmt"
	"flag"
	"log"
	"strings"
	"github.com/libvirt/libvirt-go"
)

func main() {
	var (
	   arch, leasedResource string
	   REMOTE_LIBVIRT_URI string
	   REMOTE_LIBVIRT_HOSTNAME, REMOTE_LIBVIRT_HOSTNAME_1, REMOTE_LIBVIRT_HOSTNAME_2 string
	)
	// check lease name
	flag.StringVar(&leasedResource, "leasedResource", "", "enter leased resource name")
	flag.Parse()
	if len(leasedResource) == 0 {
		fmt.Println("usage: -leasedResource is empty")
		return
	}

	LIBVIRT_HOSTS := make(map[string]string)
	if strings.Contains(leasedResource, "ppc64le"){
		arch = "ppc64le"
	} else {
		arch = "s390x"
	}

	// Setting Hostnames
	if arch == "ppc64le" {
		REMOTE_LIBVIRT_HOSTNAME = "C155F2U33"
		REMOTE_LIBVIRT_HOSTNAME_1 = "C155F2U31"
		REMOTE_LIBVIRT_HOSTNAME_2 = "C155F2U35"
		LIBVIRT_HOSTS["libvirt-ppc64le-0-0"] = REMOTE_LIBVIRT_HOSTNAME
		LIBVIRT_HOSTS["libvirt-ppc64le-0-1"] = REMOTE_LIBVIRT_HOSTNAME
		LIBVIRT_HOSTS["libvirt-ppc64le-0-2"] = REMOTE_LIBVIRT_HOSTNAME
		LIBVIRT_HOSTS["libvirt-ppc64le-0-3"] = REMOTE_LIBVIRT_HOSTNAME
		LIBVIRT_HOSTS["libvirt-ppc64le-0-4"] = REMOTE_LIBVIRT_HOSTNAME
		LIBVIRT_HOSTS["libvirt-ppc64le-1-0"] = REMOTE_LIBVIRT_HOSTNAME_1
		LIBVIRT_HOSTS["libvirt-ppc64le-1-1"] = REMOTE_LIBVIRT_HOSTNAME_1
		LIBVIRT_HOSTS["libvirt-ppc64le-1-2"] = REMOTE_LIBVIRT_HOSTNAME_1
		LIBVIRT_HOSTS["libvirt-ppc64le-1-3"] = REMOTE_LIBVIRT_HOSTNAME_1
		LIBVIRT_HOSTS["libvirt-ppc64le-1-4"] = REMOTE_LIBVIRT_HOSTNAME_1
		LIBVIRT_HOSTS["libvirt-ppc64le-2-0"] = REMOTE_LIBVIRT_HOSTNAME_2
		LIBVIRT_HOSTS["libvirt-ppc64le-2-1"] = REMOTE_LIBVIRT_HOSTNAME_2
		LIBVIRT_HOSTS["libvirt-ppc64le-2-2"] = REMOTE_LIBVIRT_HOSTNAME_2
		LIBVIRT_HOSTS["libvirt-ppc64le-2-3"] = REMOTE_LIBVIRT_HOSTNAME_2
		LIBVIRT_HOSTS["libvirt-ppc64le-2-4"] = REMOTE_LIBVIRT_HOSTNAME_2

	} else{
		REMOTE_LIBVIRT_HOSTNAME := "lnxocp01"
		REMOTE_LIBVIRT_HOSTNAME_1 := "lnxocp02"
		REMOTE_LIBVIRT_HOSTNAME_2 := "lnxocp06"
		LIBVIRT_HOSTS["libvirt-s390x-0-0"] = REMOTE_LIBVIRT_HOSTNAME
                LIBVIRT_HOSTS["libvirt-s390x-0-1"] = REMOTE_LIBVIRT_HOSTNAME
                LIBVIRT_HOSTS["libvirt-s390x-0-2"] = REMOTE_LIBVIRT_HOSTNAME
                LIBVIRT_HOSTS["libvirt-s390x-0-3"] = REMOTE_LIBVIRT_HOSTNAME
                LIBVIRT_HOSTS["libvirt-s390x-0-4"] = REMOTE_LIBVIRT_HOSTNAME
                LIBVIRT_HOSTS["libvirt-s390x-1-0"] = REMOTE_LIBVIRT_HOSTNAME_1
                LIBVIRT_HOSTS["libvirt-s390x-1-1"] = REMOTE_LIBVIRT_HOSTNAME_1
                LIBVIRT_HOSTS["libvirt-s390x-1-2"] = REMOTE_LIBVIRT_HOSTNAME_1
                LIBVIRT_HOSTS["libvirt-s390x-1-3"] = REMOTE_LIBVIRT_HOSTNAME_1
                LIBVIRT_HOSTS["libvirt-s390x-1-4"] = REMOTE_LIBVIRT_HOSTNAME_1
                LIBVIRT_HOSTS["libvirt-s390x-2-0"] = REMOTE_LIBVIRT_HOSTNAME_2
                LIBVIRT_HOSTS["libvirt-s390x-2-1"] = REMOTE_LIBVIRT_HOSTNAME_2
                LIBVIRT_HOSTS["libvirt-s390x-2-2"] = REMOTE_LIBVIRT_HOSTNAME_2
                LIBVIRT_HOSTS["libvirt-s390x-2-3"] = REMOTE_LIBVIRT_HOSTNAME_2
                LIBVIRT_HOSTS["libvirt-s390x-2-4"] = REMOTE_LIBVIRT_HOSTNAME_2

	}

	// get cluster libvirt uri or default it the first host
	remoteLibvirt := LIBVIRT_HOSTS[leasedResource]
	if len(remoteLibvirt) > 0 {
		REMOTE_LIBVIRT_URI = fmt.Sprintf("qemu+tcp://%s/system", remoteLibvirt)
	}else
	{
		REMOTE_LIBVIRT_URI = fmt.Sprintf("qemu+tcp://%s/system", REMOTE_LIBVIRT_HOSTNAME)
	}
	fmt.Println("Remote Host Name: ", REMOTE_LIBVIRT_URI)
	// default to first host
	defer func() {
		if err := recover(); err != nil {
			log.Println("Failed to connect to remote libvirt:", REMOTE_LIBVIRT_URI, err)
		}
	}()
	conn, err := libvirt.NewConnect(REMOTE_LIBVIRT_URI)
	if err != nil {
		fmt.Println("Failed to connect to remote libvirt: ", err)
	}
	defer conn.Close()

	domains, err := conn.ListAllDomains(libvirt.CONNECT_LIST_DOMAINS_ACTIVE)
        if err != nil {
                fmt.Println("Failed to List Active Domains: ",err)
        }
        for _, domain := range domains {
                vmName, err := domain.GetName()
                if err == nil && strings.HasPrefix(vmName, leasedResource) {
                         if ok,_ := domain.IsActive(); ok {
                                fmt.Println("Domain is active, Destroying it.. :", vmName)
                                _ = domain.Destroy()
                        }
                        fmt.Println("Started Undefineing vm: ", vmName)
                        err = domain.Undefine()
                        if err != nil{
                                fmt.Println("Faield delete vm: %s", vmName)
                        }
                }
        }

	
        storagePools, err := conn.ListAllStoragePools(libvirt.CONNECT_LIST_STORAGE_POOLS_ACTIVE)
        if err != nil {
                fmt.Println("Failed to List storage pools:",err)
        }
        for _, pool := range storagePools {
		defer pool.Free()
		poolName, err := pool.GetName()
                if err == nil && strings.Contains(poolName, leasedResource) {
		
		pool, err := conn.LookupStoragePoolByName(poolName)
		if err != nil {
			fmt.Println("Failed get storage pool:", poolName, err)
		}

		// delete all vols that return true from filter.
		vols, err := pool.ListAllStorageVolumes(0)
		if err != nil {
			fmt.Println("Failed to list volumes in: ", poolName, err)
		}

		for _, vol := range vols {
			defer vol.Free()
			vName, err := vol.GetName()
			if err != nil {
				fmt.Println("failed get volume names in: ", poolName, err)
			}
			if err := vol.Delete(0); err != nil {
				fmt.Println("Failed delete volume %q from %q", vName, poolName)
			} else{
				fmt.Printf("delete volume %v from pool %v\n", vName, poolName)
			}
	            }

                        if ok,_ := pool.IsActive(); ok {
                                fmt.Println("Pool is active, Destroying it.. :", poolName)
                                _ = pool.Destroy()
                        }
                        fmt.Println("Start Deleting storage pool: ", poolName)
			err = pool.Delete(0)
                        if err != nil{
                                fmt.Println("Failed delete storage pool:", poolName, err)
                        }else{
				fmt.Println("deleted storage pool ", poolName)
			}
			fmt.Println("Undefine storage pool: ", poolName)
			err = pool.Undefine()
			if err != nil {
				fmt.Println("Failed to Undefine storage Pool:", poolName, err)
			}
		}
	}

	networks, err := conn.ListAllNetworks(libvirt.CONNECT_LIST_NETWORKS_ACTIVE)
	if err != nil {
		fmt.Println("Failed to List All Networks: ",err)
	}
	for _, network := range networks {
		networkName, err := network.GetName()
                if err == nil && strings.Contains(networkName, leasedResource) {
                        if ok,_ := network.IsActive(); ok {
                                fmt.Println("network is active, Destroying it.. :", networkName)
                                _ = network.Destroy()
                        }
                 fmt.Println("Undefine network: ", networkName)
                 err = network.Undefine()
                 if err != nil {
                      fmt.Println("Failed to Undefine network: ", networkName, err)
                 }
        }
}

	return
}
