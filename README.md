puppet-dspace (A basic Puppet DSpace installer)
=============

This module works to install DSpace on Ubuntu servers, and is used by the [vagrant-dspace](https://github.com/DSpace/vagrant-dspace) project and the [puppet-dspace-demo](https://github.com/DSpace-Labs/puppet-dspace-demo) module (used to create our http://demo.dspace.org site). However, your mileage may vary, and it has not been tested in Production scenarios. Pull requests are welcome!

Module description
------------------
This module lets you use Puppet to install [DSpace](http://www.dspace.org), including all of its base prerequisites.

This includes installing the following:
* Java (OpenJDK)
* Maven (necessary to build DSpace from source)
* Ant (necessary to install or deploy DSpace)
* Git (to download DSpace source from GitHub)

Optionally, this module may also be used to install:
* Tomcat (via the [puppetlabs-tomcat](https://github.com/puppetlabs/puppetlabs-tomcat) module)
* PostgreSQL database (via the [puppetlabs-postgresql](https://github.com/puppetlabs/puppetlabs-postgresql/) module)

Primarily, this module was built to support [vagrant-dspace](https://github.com/DSpace/vagrant-dspace) and http://demo.dspace.org. As such, at this time, it only concentrates on the DSpace installation process (and does not yet cover upgrades/updates).

Requirements
------------

* Currently, this module has only been tested on **Ubuntu 16.04 LTS**. It may work on earlier versions of Ubuntu or Debian, but is currently not guaranteed to work on any other OS.
* If you wish to use `dspace::tomcat_instance`, you *MUST* install [puppetlabs-tomcat](https://github.com/puppetlabs/puppetlabs-tomcat) alongside this module.
* If you wish to use `dspace::postgresql_db`, you *MUST* install [puppetlabs-postgresql](https://github.com/puppetlabs/puppetlabs-postgresql/) alongside this module.

Usage
------------

### Configure DSpace installation

For default settings, simply declare the `dspace` class:
```puppet
class { 'dspace': }
```

To customize DSpace installation settings, you can override any of the default parameters (see `init.pp` for a full list):

```puppet
class { 'dspace':
  # Base settings
  java_version       => '8',
  postgresql_version => '9.5',
  tomcat_package     => 'tomcat8',
  owner              => 'vagrant',  # OS user who "owns" DSpace
  # Database specific settings
  db_name            => 'dspace',   # Name of database to use
  db_owner           => 'dspace',   # DB owner account info
  db_owner_passwd    => 'dspace',
  db_admin_passwd    => 'postgres',
  # Tomcat specific settings
  tomcat_port        => 8080,
  catalina_opts      => '-Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m',
  # DSpace installation settings
  git_repo           => 'git@github.com:myacccount/DSpace.git',  # Git repo to use for DSpace source
  git_branch         => 'dspace-5_x',  #Git branch to use
  # DSpace Admin Account settings
  admin_firstname    => 'Jane',
  admin_lastname     => 'Doe',
  admin_email        => 'jane.doe@myu.edu',
  admin_passwd       => 'mypassword',
  admin_language     => 'en',
}
```

### Install PostgreSQL (Optional)

Optionally, you can choose to use this module to install a PostgreSQL database for DSpace to use. This REQUIRES that you've installed [puppetlabs-postgresql](https://github.com/puppetlabs/puppetlabs-postgresql) or a compatible Puppet module.

(_NOTE: DSpace requires either a PostgreSQL or Oracle database. So, if you do not use this module, you must install one by some other means._)

For default settings (or to inherit the PostgreSQL settings passed in to `dspace` class), simply create a new `dspace::postgresql_db` passing it the name of the database to create:
```puppet
dspace::postgresql_db { 'dspace' :
}
```

To customize the PostgreSQL database, either tweak the PostgreSQL settings passed to the `dspace` class, or tweak them in the `dspace::postgresql_db` class similar to this:

```puppet
dspace::postgresql_db { 'dspace' :
  version       => '9.5',
  admin_passwd  => 'postgres', # Password for 'postgres' admin acct
  owner         => 'dspace', # PostgreSQL user acct which owns this database
  owner_passwd  => 'dspace', # Password for owner acct
  port          => 5432,
  locale        => 'en_US.UTF-8',
}
```

### Install Tomcat (Optional)

Optionally, you can choose to use this module to install Tomcat. This REQUIRES that you've installed [puppetlabs-tomcat](https://github.com/puppetlabs/puppetlabs-tomcat) or a compatible Puppet module.

(_NOTE: DSpace requires Tomcat or a similar servlet container. So, if you do not use this module, you must install Tomcat (or similar) by some other means._)

For default settings (or to inherit the Tomcat settings passed in to `dspace` class), simply create a new instance pointing at your `appBase` of choice:
```puppet
dspace::tomcat_instance { "/home/${dspace::owner}/dspace/webapps" :
}
```

To customize the Tomcat installation, either tweak the Tomcat settings passed to the `dspace` class, or tweak them in the `dspace::tomcat_instance` class similar to this:

```puppet
dspace::tomcat_instance { "/home/${dspace::owner}/dspace/webapps" :
  package       => 'tomcat8',  # OS Tomcat package to install
  owner         => 'dspace',   # OS owner of Tomcat
  service       => 'tomcat8',  # Name of Tomcat service
  port          => '8080',
  catalina_home => '/usr/share/tomcat8',
  catalina_base => '/var/lib/tomcat8',
  catalina_opts => '-Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m',
}
```

### Create OS Owner (Optional)

Optionally, you can use `dspace::owner` to create a new operating system account that will own DSpace (and Tomcat). This can also be done by other means, obviously.

Here's an example of creating a new 'dspace' OS level account which will act as our DSpace owner:

```puppet
dspace::owner { 'dspace':
  gid    => 'dspace',  # Primary OS group name / ID
  groups => 'other groups', # Additional OS groups
  sudoer => true,  # Whether to add acct as a sudoer
}
```

### Install DSpace

For default settings (or to inherit the settings passed in to `dspace` class), simply create a new install pointing at your installation directory:

```puppet
dspace::install { "/home/${dspace::owner}/dspace" :
  require => DSpace::Postgresql_db[$dspace::db_name], # Must first have a database
  notify  => Service['tomcat'], # Tell Tomcat to reboot after install
}
```

To customize the DSpace installation, either tweak the settings passed to the `dspace` class, or tweak them in  the `dspace:install` class similar to this:

```puppet
dspace::install { "/home/${dspace::owner}/dspace" :
  owner           => 'dspace',  # OS owner of DSpace
  src_dir         => "/home/${dspace::owner}/dspace-src", # Full path to source code directory
  git_repo        => 'git@github.com:myacccount/DSpace.git',  # Git repo to use for DSpace source
  git_branch      => 'dspace-5_x',  #Git branch to use
  admin_firstname => 'Jane',
  admin_lastname  => 'Doe',
  admin_email     => 'jane.doe@myu.edu',
  admin_passwd    => 'mypassword',
  admin_language  => 'en',
  port            => 8080,   # Reference to Tomcat port DSpace will be available at
  db_name         => 'dspace', # Name of database to use for this install
  db_port         => 5432, # DB port to use
  db_user         => 'dspace', # DB account to use for database
  db_passwd       => 'dspace', # DB account password
}
```

### Putting it all together. Installing everything!

A good example of installing everything (PostgreSQL, Tomcat and DSpace) together can be found in the `vagrant-dspace` [`setup.pp` Puppet script](https://github.com/DSpace/vagrant-dspace/blob/master/setup.pp). This script initialized the Vagrant VM using this `puppet-dspace` module.

Another (similar) example can be found in the [`puppet-dspace-demo` module](https://github.com/DSpace-Labs/puppet-dspace-demo), which uses this `puppet-dspace` module to setup the http://demo.dspace.org demo site. In `puppet-dspace-demo`, the `manifests/site.pp` uses this module to install PostgreSQL, Tomcat, an OS owner account and DSpace.

Development
-------------
Pull requests are welcome! This is really just a labor of love, and we can use help in making it better.


License
------------

This work is licensed under the [DSpace BSD 3-Clause License](http://www.dspace.org/license/), which is just a standard [BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause).
