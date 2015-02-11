# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}


# Configure Cloudera repositories
stage { 'repo_init':
  before => Stage['main'],  
}
class { '::cloudera::cdh5::repo':
  version   => '5.3.1',
  stage => repo_init
}
class { '::cloudera::cm5::repo':
  version   => '5.3.1',
  stage => repo_init
}

# Fix Ubuntu crap
file_line { 'ubuntu broken host entry':
  ensure => present,
  match  => '^127\.0\.1\.1.*',
  line   => '127.0.1.1 ubuntu-localhost',
  path   => '/etc/hosts',
}


# Make sure Java is installed on hosts, select specific version
class { 'java':
    distribution => 'jre'
} 
Class['java'] -> Class['hadoop::common::install']


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
  } 
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

