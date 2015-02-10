# This puppet file simply installs the required packages for provisioning and gets the base 
# provisioning from the correct repos. The VM can then provision itself from there. 

package {puppet:ensure=> [latest,installed]}
package {ruby:ensure=> [latest,installed]}

# Modify global settings
class { '::cloudera':
  cm_server_host => 'smhost.localdomain',
  install_lzo    => true,
}

class { '::cloudera::repo':
  cdh_version => '5.3.1',
  cm_version  => '5.3.1',
}



node 'cmserver' {
  class { '::cloudera':
    install_cmserver => true,
  }
}

node /supervisor[1-9]/ {
  class { 'storm::supervisor': }
}

node /zookeeper[1-9]/ {
  class { 'zookeeper': hostnames => [ $::fqdn ],  realm => '' }
}

