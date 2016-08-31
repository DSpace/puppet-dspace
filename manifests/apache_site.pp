# Definition: dspace::apache_site
#
# Installs/Creates an Apache site with the given parameters.
# This allows DSpace to run on port 80 (while also forwarding requests to Tomcat).
# Uses the following Puppet Apache module (or a compatible one)
# https://github.com/puppetlabs/puppetlabs-apache/
#
# WARNING: puppetlabs-apache must already be installed/available to Puppet
# for this to work!
#
# Optionally, you can also choose to install Apache via other means
# (manually or write your own puppet script). In this situation, this script
# may provide a good starting point.
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $package        => Apache package to install/use (e.g. 'apache2')
# - $owner          => OS account which should own Tomcat (i.e. who Tomcat should run as). Default=name of package (e.g. tomcat8)
# - $group          => OS group which should own Tomcat (default is same as $owner)
# - $service        => Name of the default Tomcat service (default is same as $package)
# - $catalina_home  => Full path to Catalina Home (default=/usr/share/$package), i.e. installation directory
# - $catalina_base  => Full path to Catalina Base (default=/var/lib/$package), i.e. instance directory
# - $app_base       => Directory where Tomcat instance should load webapps (default=$name)
# - $port           => Port this Tomcat instance runs on
# - $catalina_opts  => Options to pass to Tomcat (default='-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC')
# - $ensure         => Whether to install (ensure=present) or remove (ensure=absent) this Tomcat instance (default=present)
#
# Sample Usage:
# dspace::apache_site {
#    tomcat_ajp_port    => 8009,
# }
define dspace::apache_site ($hostname        = $name,
                            $tomcat_ajp_port = $dspace::tomcat_ajp_port,
                            $ensure          = present)
{

  case $ensure
  {
    # Present = Install/Setup Tomcat
    present: {

      # Install Apache. Turn off default vhost.
      class { 'apache':
        default_vhost => false,
      }

      # Create a virtual host for our site, running on port 80
      # and proxying ALL requests to Tomcat's AJP port.
      apache::vhost { "${hostname} non-ssl":
        servername => $hostname,
        port       => 80,
        proxy_pass => [
          {
            'path'         => '/',
            'url'          => "ajp://localhost:${tomcat_ajp_port}/",
            'reverse_urls' => "ajp://localhost:${tomcat_ajp_port}/"
          }
        ],
        manage_docroot => false,  # Don't create <Directory> or DocumentRoot
      }
    }

    # Absent = Uninstall Apache
    absent: {

      # Ensure virtual host is removed
      apache::vhost { "${hostname} non-ssl":
        ensure => absent,
      }

      ->

      # Uninstall Apache
      class { 'apache':
        package_ensure => purged,
      }

    }
    default: { fail "Unknown ${ensure} value for ensure" }
  }
}
