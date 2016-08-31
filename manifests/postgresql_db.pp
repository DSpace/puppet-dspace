# Definition: dspace::postgresql_db
#
# Installs a PostgreSQL database (prerequisite for DSpace) with the
# given parameters, using the following Puppet PostgreSQL module (or a compatible one)
# https://github.com/puppetlabs/puppetlabs-postgresql/
#
# WARNING: puppetlabs-postgresql must already be installed/available to Puppet
# for this to work!
#
# Optionally, you can also choose to install PostgreSQL via other means
# (manually or write your own puppet script). In this situation, this script
# may provide a good starting point.
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $version       => Version of PostgreSQL to install (e.g. '9.4', '9.5', etc)
# - $admin_passwd  => Password for the 'postgres' user who owns Postgres (default=undef, i.e. no password)
# - $db_name       => Name of database to create for DSpace (default=$name)
# - $owner         => Name of database user to create for DSpace (default='dspace')
# - $owner_passwd  => Password of DSpace database user (default='dspace')
# - $port          => PostgreSQL port (default=5432)
# - $locale        => Locale for PostgreSQL (default='en_US.UTF-8')
# - $manage_package_repo => Setup the official Postgresql apt repos (in sources). (default=false)
#                           Set to true to install a different version of Postgres than what is in apt.
#
# Sample Usage:
# dspace::postgresql_db { 'dspace':
#    version => '9.4',
# }
define dspace::postgresql_db ($version      = $dspace::postgresql_version,
                              $admin_passwd = $dspace::db_admin_passwd,
                              $db_name      = $name,
                              $owner        = $dspace::db_owner,
                              $owner_passwd = $dspace::db_owner_passwd,
                              $port         = $dspace::db_port,
                              $locale       = $dspace::db_locale,
                              $manage_package_repo = false)
{

    # Init PostgreSQL module
    # (We use https://github.com/puppetlabs/puppetlabs-postgresql/)
    # DSpace requires UTF-8 encoding in PostgreSQL
    # DSpace also requires version 9.4 or above.
    class { 'postgresql::globals':
      encoding => 'UTF-8',
      locale   => $locale,
      # Setup the official Postgresql apt repos (in sources).
      # Necessary to install a different version of Postgres than what is in apt by default
      manage_package_repo => $manage_package_repo,
      version  => $version,
    }

    ->

    # Setup/Configure PostgreSQL server
    class { 'postgresql::server':
      ip_mask_deny_postgres_user => '0.0.0.0/32',  # allows 'postgres' user to connect from any IP
      ip_mask_allow_all_users    => '0.0.0.0/0',   # allow other users to connect from any IP
      listen_addresses           => '*',           # accept connections from any IP/machine
      postgres_password          => $admin_passwd, # set password for "postgres"
      port                       => $port,
      service_reload             => "service postgresql restart",
      service_restart_on_change  => true,
    }

    # Ensure the PostgreSQL contrib package is installed
    # (includes various extensions, like pgcrypto which is required by DSpace)
    class { 'postgresql::server::contrib': }

    # Turn on logging_collector, enables logs in /var/lib/postgresql/[version]/main/pg_log/
    postgresql::server::config_entry { 'logging_collector':
      value  => 'on',
    }

    # Create a database & user account (which owns the database)
    postgresql::server::db { $db_name:
      user     => $owner,
      password => postgresql_password($owner, $owner_passwd),
      owner    => $owner,
    }

    # Activate the 'pgcrypto' extension on our 'dspace' database
    # This is REQUIRED by DSpace 6 and above
    postgresql::server::extension { 'pgcrypto':
      database => $db_name,
      ensure   => 'present',
    }

}
