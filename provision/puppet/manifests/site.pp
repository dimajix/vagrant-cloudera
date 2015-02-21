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
class { '::osfixes::ubuntu::hosts':
  stage => init
}


class java_config {
    # Make sure Java is installed on hosts, select specific version
    class { 'java':
        distribution => 'jre'
    } 
}


# Put global Hadoop configuration into a dedicated class, which will
# be included by relevant nodes. This way only nodes which need Hadoop
# will get Hadoop and its dependencies.
class hadoop_config {
    include java_config
        
    # Modify global Hadoop settings
    class{ "hadoop":
      hdfs_hostname => 'namenode.localcluster',
      yarn_hostname => 'namenode.localcluster',
      slaves => [ 'datanode1.localcluster', 'datanode2.localcluster' ],
      frontends => [ 'client.localcluster' ],
      perform => false,
      # security needs to be disabled explicitly by using empty string
      realm => '',
      properties => {
        'dfs.replication' => 1,
        'hadoop.proxyuser.hive.groups' => 'hive,users',
        'hadoop.proxyuser.hive.hosts' => '*',
      } 
    }

    # Setup basic hadoop configuration
    include hadoop::common::install
    include hadoop::common::config
    
    Class['java'] ->
    Class['hadoop::common::install'] ->
    Class['hadoop::common::config']
}


class hive_config {
    include hadoop_config
    
    class { 'mysql::bindings':
      java_enable => true,
    }

    # Modify global Hive settings
    class { "hive":
      hdfs_hostname => 'namenode.localcluster',
      metastore_hostname => 'hivenode.localcluster',
      server2_hostname => 'hivenode.localcluster',
      # security needs to be disabled explicitly by using empty string
      realm => '',
      features  => { },
      db        => 'mysql',
      db_host   => 'mysql.localcluster',
      db_name   => 'hive',
      db_user   => 'hive',
      db_password => 'hivepassword',
    }
    Class['java'] -> Class['hive']
}


class hbase_config {
    include hadoop_config
    
    class { "hbase":
      hdfs_hostname => 'namenode.localcluster',
      master_hostname => 'hbasenode.localcluster',
      zookeeper_hostnames => [ 'zookeeper1.localcluster' ],  
      external_zookeeper => true,    
      slaves => [ 'datanode1.localcluster', 'datanode2.localcluster' ],
      frontends => [ 'client.localcluster' ],
      perform => false,
      realm => '',
      features  => { },
    }
    Class['java'] -> Class['hbase']
}


node 'namenode' {
  include hadoop_config
  # HDFS
  include hadoop::namenode
  # YARN
  include hadoop::resourcemanager
  # MAPRED
  include hadoop::historyserver
}

node 'hivenode' {
  include hive_config
  include hadoop_config
  # Hive Server
  include hive::metastore
  include hive::server2
  # Hive HDFS dependency
  include hive::hdfs
  
  Class['mysql::bindings'] ->
  Class['hadoop::common::config'] -> 
  Class['hive::metastore'] ->
  Class['hive::server2']
}

node 'hbasenode' {
  include hbase_config
  include hadoop_config
  # HBase Server
  include hbase::master
  # HBase HDFS dependency
  include hbase::hdfs
  # HBase Thrift API
  include hbase::thriftserver
  # HBase REST API
  include hbase::restserver
  
  Class['hadoop::common::config'] -> 
  Class['hbase::master'] ->
  Class['hbase::hdfs'] ->
  Class['hbase::thriftserver'] ->
  Class['hbase::restserver']
}

node 'client' {
  include hive_config
  include hbase_config
  include hadoop_config
  # client
  include hadoop::frontend
  # Hive client
  include hive::frontend
  include hive::hcatalog
  # HBase client
  include hbase::frontend
  # mysql client
  include mysql::client
}

node /datanode[1-9]/ {
  include hadoop_config
  include hbase_config
  # slave (HDFS)
  include hadoop::datanode
  # slave (YARN)
  include hadoop::nodemanager
  # hbase slave
  include hbase::regionserver

  Class['hadoop::common::config'] -> 
  Class['hadoop::datanode'] ->
  Class['hadoop::nodemanager'] ->
  Class['hbase::regionserver']
}

node /zookeeper[1-9]/ {
  class { 'zookeeper': hostnames => [ $::fqdn ],  realm => '' }
}

node mysql {
  include hive_config
  # Hive client (for mysql schema templates)
  include hive::frontend
  
  # MySQL server
  class { 'mysql::server':
    root_password           => '1234',
    remove_default_accounts => true,
    override_options => { 'mysqld' => { 'bind-address' => '0.0.0.0' } }
  }
  
  # Hive metastore database
  mysql::db { 'hive':
    user     => 'hive',
    password => 'hivepassword',
    host     => '%',
    grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
    sql      => '/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.13.0.mysql.sql',
  }
  Class['hive::frontend'] -> Mysql::Db['hive']
}

