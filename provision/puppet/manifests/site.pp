# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}

# Modify global settings

class{ "hadoop":
  hdfs_hostname => 'cmserver',
  yarn_hostname => 'cmserver',
  slaves => [ 'cmserver' ],
  frontends => [ 'cmserver' ],
  # security needs to be disabled explicitly by using empty string
  realm => '',
  properties => {
    'dfs.replication' => 1,
  }
}


node 'cmserver' {
    class { '::cloudera':
      cm_version     => '5.3.1',
      cdh_version    => '5.3.1',
      cm_server_host => 'cmserver',
      use_parcels    => false,
      # install_cmserver => true,
      install_lzo    => true,
    }

  # HDFS
  include hadoop::namenode
  # YARN
  include hadoop::resourcemanager
  # MAPRED
  include hadoop::historyserver
  # slave (HDFS)
  include hadoop::datanode
  # slave (YARN)
  include hadoop::nodemanager
  # client
  include hadoop::frontend
}

