# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}

# Configure Cloudera repositories
class { '::cloudera::cdh5::repo':
  version     => '5.3.1',
}
class { '::cloudera::cm5::repo':
  version     => '5.3.1',
}


# Update apt cache
#class { '::apt::update':
#  require => ['::cloudera::cdh5::repo' ,'::cloudera::cm5::repo']
#}

# Make sure Java is installed on hosts, select specific version
class { 'java':
    distribution => 'jre'
} ->
# Modify global settings
class{ "hadoop":
  hdfs_hostname => 'namenode.localcluster',
  yarn_hostname => 'namenode.localcluster',
  slaves => [ 'datanode1.localcluster' ],
  frontends => [ 'client.localcluster' ],
  perform => false,
  # security needs to be disabled explicitly by using empty string
  realm => '',
  properties => {
    'dfs.replication' => 1,
  }, 
}


node 'namenode' {
  # Format
  #include hadoop::format
  # HDFS
  include hadoop::namenode
  # YARN
  include hadoop::resourcemanager
  # MAPRED
  include hadoop::historyserver
}

node 'client' {
  # client
  include hadoop::frontend
}

node /datanode[1-9]/ {
  # slave (HDFS)
  include hadoop::datanode
  # slave (YARN)
  include hadoop::nodemanager
}

