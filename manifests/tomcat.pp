# Definition: dspace::tomcat
#
# Installs Apache Tomcat (prerequisite for DSpace) with the
# given parameters, using the following Puppet Tomcat module (or a compatible one)
# https://github.com/puppetlabs/puppetlabs-tomcat/
#
# WARNING: puppetlabs-tomcat must already be installed/available to Puppet
# for this to work!
#
# Optionally, you can also choose to install Tomcat via other means
# (manually or write your own puppet script)
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $package (REQUIRED) => Tomcat package to install (e.g. "tomcat7", "tomcat8", etc)
# - $owner (REQUIRED)   => OS account which should own Tomcat (i.e. who Tomcat should run as)
# - $service            => Name of the default Tomcat service (default is same as $package)
# - $catalina_home      => Full path to Catalina Home (default=/usr/share/$package)
# - $catalina_base      => Full path to Catalina Base (default=/var/lib/$package)
# - $catalina_opts      => Options to pass to Tomcat (default='-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC')
# - $app_base           => Directory where Tomcat should load webapps (default='/home/$owner/dspace/webpps')
#
# Sample Usage:
# dspace::tomcat {
#    package    => "tomcat7",
# }
define dspace::tomcat ($package,
                       $owner,
                       $service = $package,
                       $catalina_home = "/usr/share/${service}",
                       $catalina_base = "/usr/shar/${service}",
                       $app_base      = "/home/${owner}/dspace/webapps",
                       $catalina_opts = "-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC")
{

  # Require that the 'puppetlabs/stdlib' module be initialized,
  # as we utilize 'file_line' from that module
  include stdlib

  # Init Tomcat module
  # (We use https://github.com/puppetlabs/puppetlabs-tomcat/)
  class {'tomcat':
    install_from_source => false,           # Do NOT install from source, we'll use package manager
    catalina_home       => $catalina_home,
    manage_user         => false,           # Don't let Tomcat module manage which user/group to start with, package does this already
    manage_group        => false,
    require             => Class['dspace'], # Require DSpace was initialized, so that Java is installed
  }

->
  # Create a new Tomcat instance & install from package manager
  tomcat::instance { 'default':
    package_name    => $package,         # Name of the tomcat package to install
    package_ensure  => installed,        # Ensure package is installed
  }

->

  # Override the default Tomcat <Host name='localhost'> entry
  # and point it at the DSpace webapps directory (so that it loads all DSpace webapps)
  tomcat::config::server::host { 'localhost':
    app_base              => $app_base,     # Tell Tomcat to load webapps from this directory
    host_ensure           => present,
    catalina_base         => $catalina_base,                 # Tomcat install this pertains to
    additional_attributes => {                               # Additional Tomcat <Host> attributes
      'autoDeploy' => 'true',
      'unpackWARs' => 'true',
    },
    notify                => Service['tomcat'],              # If changes are made, notify Tomcat to restart
  }

->

  # Temporarily stop Tomcat, so that we can modify which user it runs as
  # (We cannot tweak the Tomcat run-as user while it is running)
  exec { 'Stop default Tomcat temporarily':
    command => "service ${service} stop",
  }

->

  # Modify the Tomcat "defaults" file to make Tomcat run as the $owner
  # NOTE: This seems to be the ONLY way to do this in Ubuntu, which is disappointing
  file_line { 'Update Tomcat to run as ${owner}':
    path   => "/etc/default/${service}",    # File to modify
    line   => "TOMCAT7_USER=${owner}",      # Line to add to file
    match  => "^TOMCAT7_USER=.*$",              # Regex for line to replace (if found)
    notify => Service['tomcat'],                # If changes are made, notify Tomcat to restart
  }

->

  # Modify the Tomcat "defaults" file to set custom JAVA_OPTS based on the $catalina_opts
  # Again, seems to be the only way to easily do this in Ubuntu.
  file_line { 'Update Tomcat run options':
    path   => "/etc/default/${service}",        # File to modify
    line   => "JAVA_OPTS=\"${catalina_opts}\"", # Line to add to file
    match  => "^JAVA_OPTS=.*$",                 # Regex for line to replace (if found)
    notify => Service['tomcat'],                # If changes are made, notify Tomcat to restart
  }

->

  # In order for Tomcat to function properly, the entire CATALINA_BASE directory
  # and all subdirectories need to be owned by $owner
  file { $catalina_base:
    ensure  => directory,
    owner   => $owner,    # Change owner
    recurse => true,      # Also change owner of subdirectories/files
    links   => follow,    # Follow any links to and change ownership there too
  }

->

  # This service is auto-created by package manager when installing Tomcat
  # But, we just want to make sure it is running & starts on boot
  service {'tomcat':
    name   => $service,
    enable => 'true',
    ensure => 'running',
  }

}
