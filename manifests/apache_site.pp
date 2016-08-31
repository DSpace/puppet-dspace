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
# - $hostname        => Hostname for this Apache site
# - $tomcat_ajp_port => Tomcat AJP port to forward requests to
# - $ssl             => Whether to enable SSL for this site
# - $ssl_cert        => Optional SSL cert path if SSL enabled
# - $ssl_chain       => Optional SSL chain path if SSL enabled
# - $ssl_key         => Optional SSL key path if SSL enabled
# - $ensure          => Whether to install (ensure=present) or remove (ensure=absent) this Apache site (default=present)
#
# Sample Usage:
# dspace::apache_site { 'dspace.myu.edu':
#    tomcat_ajp_port    => 8009,
# }
define dspace::apache_site ($hostname        = $name,
                            $tomcat_ajp_port = $dspace::tomcat_ajp_port,
                            $ssl             = false,
                            $ssl_cert        = undef,
                            $ssl_chain       = undef,
                            $ssl_key         = undef,
                            $ensure          = present)
{

  case $ensure
  {
    # Present = Install/Setup Apache
    present: {

      # Install Apache. Turn off default vhost (we want DSpace to be default)
      class { 'apache':
        default_vhost => false,
      }

      # Install mod_proxy and mod_proxy_ajp
      # These modules are needed to proxy all requests to Tomcat
      class { 'apache::mod::proxy': }
      class { 'apache::mod::proxy_ajp': }

      # Create a virtual host for our site, running on port 80
      # and proxying ALL requests to Tomcat's AJP port.
      apache::vhost { $hostname:
        servername => $hostname,
        port       => 80,
        proxy_pass => [
          {
            'path'         => '/',
            'url'          => "ajp://localhost:${tomcat_ajp_port}/",
            'reverse_urls' => "ajp://localhost:${tomcat_ajp_port}/"
          }
        ],
        docroot        => undef,
        manage_docroot => false,  # Don't create <Directory> or DocumentRoot
      }


      # Check if SSL is enabled
      if $ssl {

        # Enable mod_ssl
        class { 'apache::mod::ssl': }

        # Create a corresponding SSL (HTTPS) virtual host on port 443
        # and also proxy ALL requests to Tomcat's AJP port.
        apache::vhost { "ssl-${hostname}":
          servername => $hostname,
          port       => 443,
          ssl        => true,
          # If $ssl_cert, etc are unspecified, use defaults from 'apache' module itself
          ssl_cert   => $ssl_cert ? { undef => $apache::default_ssl_cert, default => $ssl_cert },
          ssl_key    => $ssl_key ? { undef => $apache::default_ssl_key, default => $ssl_key },
          ssl_chain  => $ssl_chain ? { undef => $apache::default_ssl_chain, default => $ssl_chain },
          proxy_pass => [
            {
              'path'         => '/',
              'url'          => "ajp://localhost:${tomcat_ajp_port}/",
              'reverse_urls' => "ajp://localhost:${tomcat_ajp_port}/"
            }
          ],
          docroot        => undef,
          manage_docroot => false,  # Don't create <Directory> or DocumentRoot
        }
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
