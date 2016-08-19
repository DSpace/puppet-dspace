# Definition: dspace::postgresql
#
# Installs a PostgreSQL database (prerequisite for DSpace) with the
# given parameters, using the following Puppet PostgreSQL module (or a compatible one)
# https://github.com/puppetlabs/puppetlabs-postgresql/
#
# WARNING: puppetlabs-postgresql must already be installed/available to Puppet
# for this to work!
#
# Optionally, you can also choose to install PostgreSQL via other means
# (manually or write your own puppet script)
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $version (REQUIRED) => Version of PostgreSQL to install (e.g. "9.4", etc)
# - $postgres_password  => Password for the 'postgres' user who owns Postgres (default='postgres')
# - $db_name            => Name of database to create for DSpace (default='dspace')
# - $db_user            => Name of database user to create for DSpace (default='dspace')
# - $db_password        => Password of DSpace database user (default='dspace')
#
# Sample Usage:
# dspace::postgresql {
#    version    => "9.4",
# }
define dspace::postgresql ($version,
                           $postgres_password = 'postgres',
                           $db_name = 'dspace',
                           $db_user = 'dspace',
                           $db_password = 'dspace')
{

    # Init PostgreSQL module
    # (We use https://github.com/puppetlabs/puppetlabs-postgresql/)
    # DSpace requires UTF-8 encoding in PostgreSQL
    # DSpace also requires version 9.4 or above. We'll use 9.4
    class { 'postgresql::globals':
      encoding => 'UTF-8',
      # Setup the official Postgresql apt repos (in sources).
      # Necessary to install a newer version of Postgres than what is in apt by default
      manage_package_repo => true,
      version  => $version,
    }

->

    # Setup/Configure PostgreSQL server
    class { 'postgresql::server':
      ip_mask_deny_postgres_user => '0.0.0.0/32',  # allows 'postgres' user to connect from any IP
      ip_mask_allow_all_users    => '0.0.0.0/0',   # allow other users to connect from any IP
      listen_addresses           => '*',           # accept connections from any IP/machine
      postgres_password          => $postgres_password,      # set password for "postgres"
    }

    # Ensure the PostgreSQL contrib package is installed
    # (includes various extensions, like pgcrypto which is required by DSpace)
    class { 'postgresql::server::contrib': }

    # Create a 'dspace' database & 'dspace' user account (which owns the database)
    postgresql::server::db { $db_name:
      user     => $db_user,
      password => $db_password
    }

    # Activate the 'pgcrypto' extension on our 'dspace' database
    # This is REQUIRED by DSpace 6 and above
    postgresql::server::extension { 'pgcrypto':
      database => $db_name,
    }

}
