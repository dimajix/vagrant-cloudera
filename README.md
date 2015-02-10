# vagrant-cloudera
A Vagrant setup to run a virtual Cloudera cluster

# Issues

The Cloudera Puppet module wants to change the kernel settings for transparent hugepages. This might now be possible in some virtual environment (most notably with LXC). In this case, you need to change the setting in the host environment

    echo never > /sys/kernel/mm/transparent_hugepage/defrag


