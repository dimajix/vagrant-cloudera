# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}

# Modify global settings

class { '::cloudera::cdh5::repo':
  version     => '5.3.1',
}
class { '::cloudera::cm5::repo':
  version     => '5.3.1',
}
class { '::cloudera::impala::repo':
  version     => '5.3.1',
}

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

