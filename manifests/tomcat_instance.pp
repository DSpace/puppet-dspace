# Definition: dspace::tomcat_instance
#
# Installs an Apache Tomcat instance (prerequisite for DSpace) with the
# given parameters, using the following Puppet Tomcat module (or a compatible one)
# https://github.com/puppetlabs/puppetlabs-tomcat/
#
# WARNING: puppetlabs-tomcat must already be installed/available to Puppet
# for this to work!
#
# Optionally, you can also choose to install Tomcat via other means
# (manually or write your own puppet script). In this situation, this script
# may provide a good starting point.
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $package        => Tomcat package to install/use (e.g. 'tomcat7', 'tomcat8', etc)
# - $owner          => OS account which should own Tomcat (i.e. who Tomcat should run as). Default=name of package (e.g. tomcat8)
# - $group          => OS group which should own Tomcat (default is same as $owner)
# - $service        => Name of the default Tomcat service (default is same as $package)
# - $catalina_home  => Full path to Catalina Home (default=/usr/share/$package), i.e. installation directory
# - $catalina_base  => Full path to Catalina Base (default=/var/lib/$package), i.e. instance directory
# - $app_base       => Directory where Tomcat instance should load webapps (default=$name)
# - $port           => Port this Tomcat instance runs on
# - $ajp_port       => AJP port for Tomcat redirects. Only useful to set if using Apache webserver + Tomcat (see apache_site.pp)
# - $catalina_opts  => Options to pass to Tomcat (default='-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC')
# - $ensure         => Whether to install (ensure=present) or remove (ensure=absent) this Tomcat instance (default=present)
#
# Sample Usage:
# dspace::tomcat_instance {
#    package    => 'tomcat8',
# }
define dspace::tomcat_instance ($package       = $dspace::tomcat_package,
                                $owner         = $dspace::owner,
                                $group         = $dspace::group,
                                $service       = $dspace::tomcat_package,
                                $catalina_home = $dspace::catalina_home,
                                $catalina_base = $dspace::catalina_base,
                                $app_base      = $name,
                                $port          = $dspace::tomcat_port,
                                $ajp_port      = $dspace::tomcat_ajp_port,
                                $catalina_opts = $dspace::catalina_opts,
                                $ensure        = present)
{

  case $ensure
  {
    # Present = Install/Setup Tomcat
    present: {

      # Require that the 'puppetlabs/stdlib' module be initialized,
      # as we utilize 'file_line' from that module
      include stdlib

      # Init Tomcat module with global defaults
      # (We use https://github.com/puppetlabs/puppetlabs-tomcat/)
      class {'tomcat':
        catalina_home       => $catalina_home,  # Installation directory location
        manage_user         => false,           # Don't let Tomcat module manage which user/group to start with, package does this already
        manage_group        => false,
        require             => Class['dspace'], # Require DSpace was initialized, so that Java is installed
      }

      ->

      # Create a new Tomcat instance
      tomcat::instance { $catalina_base:
        install_from_source => false,           # Don't install from source, we'll use package manager to install Tomcat
        package_name        => $package,        # Name of Tomcat package
        package_ensure      => installed,       # Ensure it is installed
        manage_service      => false,           # Don't let module manage the service, as it is installed by package manager
      }

      ->

      # Update the default HTTP connector to use specified $port and UTF-8
      tomcat::config::server::connector { "Default ${package} HTTP connector":
        catalina_base       => $catalina_base,  # Tomcat instance this pertains to
        port                => $port,           # Port to run on
        protocol            => 'HTTP/1.1',
        additional_attributes => {
          'connectionTimeout' => '20000',
          'URIEncoding'       => 'UTF-8'
        },
      }

      ->

      # Override the default Tomcat <Host name='localhost'> entry
      # and point it at the DSpace webapps directory (so that it loads all DSpace webapps)
      tomcat::config::server::host { 'localhost':
        app_base              => $app_base,          # Tell Tomcat to load webapps from this directory
        host_ensure           => present,
        catalina_base         => $catalina_base,     # Tomcat instance this pertains to
        additional_attributes => {                   # Additional Tomcat <Host> attributes
          'autoDeploy' => 'true',
          'unpackWARs' => 'true',
        },
        notify                => Service['tomcat'],   # If changes are made, notify Tomcat to restart
      }

      ->

      # Temporarily stop Tomcat, so that we can modify which user it runs as
      # (We cannot tweak the Tomcat run-as user while it is running)
      exec { 'Stop default Tomcat temporarily':
        command => "service ${service} stop",
        # Must run before making any permission changes to Tomcat
        before  => [File_line["Update Tomcat to run as ${owner}"], File_line['Update Tomcat run options'], File[$catalina_base]]
      }

      ->

      # Modify the Tomcat "defaults" file to make Tomcat run as the $owner
      # NOTE: This seems to be the ONLY way to update /etc/init.d script when installing from packages on Ubuntu.
      file_line { "Update Tomcat to run as ${owner}":
        path    => "/etc/default/${service}",    # File to modify
        line    => join([upcase($service), "_USER=${owner}"], ""),   # Line to add (e.g. TOMCAT8_USER=$owner)
        match   => join(["^", upcase($service), "_USER=.*$"], ""),   # Regex for line to replace (if found)
        require => Tomcat::Instance[$catalina_base],         # Tomcat instance must be created first
        notify  => Service['tomcat'],                         # Notify service to restart
      }

      ->

      # Modify the Tomcat "defaults" file to set custom JAVA_OPTS based on the $catalina_opts
      # Again, seems to be the ONLY way to update /etc/init.d script when installing from packages on Ubuntu.
      file_line { 'Update Tomcat run options':
        path    => "/etc/default/${service}",        # File to modify
        line    => "JAVA_OPTS=\"${catalina_opts}\"", # Line to add to file
        match   => "^JAVA_OPTS=.*$",                 # Regex for line to replace (if found)
        require => Tomcat::Instance[$catalina_base],         # Tomcat instance must be created first
        notify  => Service['tomcat'],                         # Notify service to restart
      }

      ->

      # In order for Tomcat to function properly, the entire CATALINA_BASE directory
      # and all subdirectories need to be owned by $owner
      file { $catalina_base:
        ensure  => directory,
        owner   => $owner,              # Change owner
        recurse => true,                # Also change owner of subdirectories/files
        links   => follow,              # Follow any links to and change ownership there too
        require => Tomcat::Instance[$catalina_base],         # Tomcat instance must be created first
        notify  => Service['tomcat'],                         # Notify service to restart
      }

      # If an AJP port was specified, add an AJP connector for it
      if $ajp_port {
        # Add the AJP connector to use specified $ajp_port and UTF-8
        tomcat::config::server::connector { "Add ${package} AJP connector":
          catalina_base       => $catalina_base,  # Tomcat instance this pertains to
          port                => $ajp_port,
          protocol            => 'AJP/1.3',
          additional_attributes => {
            'URIEncoding'       => 'UTF-8',
          },
          require => Tomcat::Instance[$catalina_base],   # Tomcat instance must be created first
          notify  => Service['tomcat'],                  # Notify service to restart
        }
      }

      # This service is auto-created in /etc/init.d by package manager
      # But, we just want to make sure it is running & starts on boot
      service {'tomcat':
        name    => $service,
        enable  => true,
        ensure  => running,
        require => Tomcat::Instance[$catalina_base],         # Tomcat instance must be created first
      }
    }

    # Absent = Uninstall Tomcat
    absent: {

      # Stop Tomcat
      exec { 'Stop Tomcat':
        command => "service ${service} stop",
        onlyif  => "/usr/bin/test -x /etc/init.d/${service}",
      }

      ->

      # Next, disable the service
      service { 'tomcat':
        enable => false,
      }

      ->

      # Uninstall Tomcat package
      tomcat::install { "Uninstall ${package}":
        install_from_source => false,           # Don't install from source, we'll use package manager to install Tomcat
        package_name        => $package,        # Name of Tomcat package
        package_ensure      => purged,          # Ensure it is REMOVED
      }

    }
    default: { fail "Unknown ${ensure} value for ensure" }
  }
}
