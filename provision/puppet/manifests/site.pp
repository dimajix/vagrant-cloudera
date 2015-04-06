# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}


# Configure Cloudera repositories
stage { 'init':
  before => Stage['main'],  
}
class { '::cloudera::cdh5::repo':
  version   => '5.3.2',
  stage => init
}
class { '::cloudera::cm5::repo':
  version   => '5.3.2',
  stage => init
}
class { '::osfixes::ubuntu::hosts':
  stage => init
}

# Make sure Java is installed on hosts, select specific version
class { 'java':
  distribution => 'jre',
  stage => init
} 


# Put global Hadoop configuration into a dedicated class, which will
# be included by relevant nodes. This way only nodes which need Hadoop
# will get Hadoop and its dependencies.
class hadoop_config {
    # Modify global Hadoop settings
    class{ "hadoop":
      hdfs_hostname => "namenode.${domain}",
      yarn_hostname => "namenode.${domain}",
      slaves => [ "datanode1.${domain}", "datanode2.${domain}" ],
      frontends => [ "client.${domain}" ],
      perform => false,
      # security needs to be disabled explicitly by using empty string
      realm => '',
      properties => {
        # Please no replication in our virtual dev cluster
        'dfs.replication' => 1,
        'hadoop.proxyuser.hive.groups' => 'hive,users,supergroup',
        'hadoop.proxyuser.hive.hosts' => '*',
        # Setup zookeeper for hbase, otherwise it won't work in Hadoop
        'hbase.zookeeper.quorum' => "zookeeper1.${domain}",
        # Limit CPU usage
        'yarn.nodemanager.resource.cpu-vcores' => '4',
        # Enable log aggregation
        'yarn.log-aggregation-enable' => 'true',
        # Turn off security
        'dfs.namenode.acls.enabled' => 'false',
        'dfs.permissions.enabled' => 'false',
        # Enable shortcircuit reads for impala
        'dfs.client.read.shortcircuit' => 'true',
        'dfs.domain.socket.path' => '/var/lib/hadoop-hdfs/dn_socket',
        'dfs.client.file-block-storage-locations.timeout.millis' => '10000',
        'dfs.datanode.hdfs-blocks-metadata.enabled' => 'true'
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
      hdfs_hostname => "namenode.${domain}",
      metastore_hostname => "hivenode.${domain}",
      server2_hostname => "hivenode.${domain}",
      # security needs to be disabled explicitly by using empty string
      realm => '',
      features  => { },
      db        => 'mysql',
      db_host   => 'mysql.${domain}',
      db_name   => 'hive',
      db_user   => 'hive',
      db_password => 'hivepassword',
    }
}


class hbase_config {
    include hadoop_config
    
    class { "hbase":
      hdfs_hostname => "namenode.${domain}",
      master_hostname => "hbasenode.${domain}",
      zookeeper_hostnames => [ "zookeeper1.${domain}" ],  
      external_zookeeper => true,    
      slaves => [ "datanode1.${domain}", "datanode2.${domain}" ],
      frontends => [ "client.${domain}" ],
      perform => false,
      realm => '',
      features  => { },
    }
}


class impala_config {
    include hadoop_config
    include hbase_config
    include hive_config
    
    class { "impala":
      catalog_hostname => "hivenode.${domain}",
      statestore_hostname => "hivenode.${domain}"
    }
}


class spark_config {
    include hadoop_config
    
    class { "spark": 
      master_hostname => "sparknode.${domain}",
      workers => [ "datanode1.${domain}", "datanode2.${domain}" ]
    }
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
  include impala_config
  # Hive Server
  include hive::metastore
  include hive::server2
  # Hive HDFS dependency
  include hive::hdfs

  # Impala catalog
  include impala::catalog
  # Impala statestore
  include impala::statestore
  
  Class['mysql::bindings'] ->
  Class['hadoop::common::config'] -> 
  Class['hive::metastore'] ->
  Class['hive::server2'] ->
  Class['impala::catalog'] ->
  Class['impala::statestore']
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


node 'sparknode' {
  include hadoop_config
  include spark_config
  # Spark master
  include spark::master

  Class['hadoop::common::config'] -> 
  Class['spark::master']
}


node 'client' {
  include hive_config
  include hbase_config
  include hadoop_config
  include impala_config
  include spark_config

  # client
  include hadoop::frontend
  # Hive client
  include hive::frontend
  include hive::hcatalog
  # HBase client
  include hbase::frontend
  # mysql client
  include mysql::client
  # Impala client
  include impala::frontend
  # Spark client
  include spark::frontend

  Class['hadoop::common::config'] -> 
  Class['hadoop::frontend'] ->
  Class['hive::frontend'] ->
  Class['hive::hcatalog'] ->
  Class['hbase::frontend'] ->
  Class['impala::frontend'] ->
  Class['spark::frontend']
}


node /datanode[1-9]/ {
  include hadoop_config
  include hbase_config
  include impala_config
  include spark_config

  # slave (HDFS)
  include hadoop::datanode
  # slave (YARN)
  include hadoop::nodemanager
  # hbase slave
  include hbase::regionserver
  # Impala server
  include impala::server
  # Spark worker
  include spark::worker

  Class['hadoop::common::config'] -> 
  Class['hadoop::datanode'] ->
  Class['hadoop::nodemanager'] ->
  Class['hbase::regionserver'] ->
  Class['spark::worker'] ->
  Class['impala::server']
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
  
  Class['java'] ->
  Class['hive::frontend'] -> 
  Mysql::Db['hive']
}

