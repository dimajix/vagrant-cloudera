# vagrant-cloudera
A Vagrant setup to run a virtual Cloudera cluster.

Per se, four nodes a configured (see the top of Vagrantfile), but of course you might to use a different configuration. To use a different cluster configuration, you need to change the specified hosts in Vagrantfile and you also need to adopt the Puppet configuration file in `provision/puppet/manifests/site.pp` such that all required services are running on some hosts.

# Compatibility

I only tested the cluster on Ubuntu 14.04 with the `vagrant-lxc` plugin. If you plan to use a big virtual cluster running on a single machine, I strongly recommend using Linux containers (LXC) with `vagrant-lxc` instead of a full blown virtualisation. I guess it would also be possible to setup a virtual host machine running Ubuntu 14.04 on a different OS (even like Windows or Mac OS), and then use Linux containers with `vagrant-lxc` inside the virtual host.

# Dependencies

For best results, you should also install the Vagrant plugin `vagrant-hostmanager` simply by typing

    vagrant plugin install vagrant-hostmanager
    
This neat plugin will make sure that every nodein your cluster gets a `hosts` file containing all other nodes of your Vagrant virtual cluster. This way you do not need to have any DNS bindings for your hosts, and you can simply rely on a DHCP server for assigning IP addresses.

# Starting

In order to start the cluster, simply go into the root directory and run

    vagrant up
    
This will bring up all nodes. Sometimes some provisioning errors might occur during startup. They mostly come by some race conditions of the parallel startup. In most cases, you can simply rerun the provisioning with `vagrant provision <node>` for a specific node.

# Available machines

The following virtual machines will be provided:

    namenode.localcluster  - Hadoop Namenode, Historytracker, YARN Resourcemanager
    datanode1.localcluster - Hadoop Datanode, YARN Nodemanager
    datanode2.localcluster - Hadoop Datanode, YARN Nodemanager
    client.localcluster    - Client machine which should be used to access all services
    
You can ssh into any of the machines using `vagrant` by typing

    vagrant ssh <nodename>
    
where `nodename` is one of `namenode`, `datanode1`, `datanode2`, `mysql` or `client` 
    

# Web Access to Hadoop

Hadoop will make some web interfaces available to the host machine.

    http://namenode.localcluster:50070
    http://datanode1.localcluster:50075/
    http://datanode2.localcluster:50075/

# Issues

The Cloudera Puppet module wants to change the kernel settings for transparent hugepages. This might now be possible in some virtual environment (most notably with LXC). In this case, you need to change the setting in the host environment

    echo never > /sys/kernel/mm/transparent_hugepage/defrag


