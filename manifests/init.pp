
# Class: dspace
#
# This class does the following:
# - installs pre-requisites for DSpace (Java, Maven, Ant, Tomcat)
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $java_version       => Version of OpenJDK to install (default '8')
# - $owner              => OS Owner of DSpace (account must exist or be created by dspace::owner)
# - $group              => OS Group of DSpace owner
# - $src_dir            => Location where DSpace source should be kept (defaults to the home directory of $owner at ~/dspace-src)
# - $install_dir        => Location where DSpace instance should be installed (defaults to $name)
# - $installer_dir_name => Name of directory where the Ant installer is built to (via Maven).
# - $git_repo           => Git repository to pull DSpace source from. Defaults to DSpace/DSpace in GitHub
# - $git_branch         => Git branch to build DSpace from. Defaults to "master".
# - $mvn_params         => Any build params passed to Maven.
# - $postgresql_version => Version of PostgreSQL to install (e.g. '9.5', etc)
# - $db_name            => Name of database to create for DSpace (default=$name)
# - $db_admin_passwd    => Password for the 'postgres' user who owns Postgres (default=undef, i.e. no password)
# - $db_owner           => Name of database user to create for DSpace (default='dspace')
# - $db_owner_passwd    => Password of DSpace database user (default='dspace')
# - $db_port            => PostgreSQL port (default=5432)
# - $db_locale          => Locale for PostgreSQL (default='en_US.UTF-8')
# - $tomcat_package     => Tomcat package to install/use (e.g. 'tomcat8', etc)
# - $tomcat_port        => Port this Tomcat instance runs on
# - $tomcat_ajp_port    => AJP port for Tomcat. Only useful to set if using Apache webserver + Tomcat (see apache_site.pp)
# - $catalina_opts      => Options to pass to Tomcat (default='-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC')
# - $admin_firstname    => First Name of the created default DSpace Administrator account.
# - $admin_lastname     => Last Name of the created default DSpace Administrator account.
# - $admin_email        => Email of the created default DSpace Administrator account.
# - $admin_passwd       => Initial Password of the created default DSpace Administrator account.
# - $admin_language     => Language of the created default DSpace Administrator account.
# - $handle_prefix      => Handle Prefix to use for this site (default = 123456789)
#
# Sample Usage:
# include dspace
#
class dspace(
  $java_version       = '8',
  $owner              = 'dspace',
  $group              = $owner,
  $src_dir            = "/home/${owner}/dspace-src",
  $install_dir        = "/home/${owner}/dspace",
  $installer_dir_name = 'dspace-installer',
  $git_repo           = 'https://github.com/DSpace/DSpace.git',
  $git_branch         = 'master',
  $mvn_params         = '',
  # PostgreSQL DB Settings (optional)
  $postgresql_version = '9.5',
  $db_name            = 'dspace',
  $db_admin           = 'postgres',
  $db_admin_passwd    = undef,
  $db_owner           = 'dspace',
  $db_owner_passwd    = undef,
  $db_port            = 5432,
  $db_locale          = 'en_US.UTF-8',
  # Tomcat Settings (optional)
  $tomcat_package     = 'tomcat8',
  $tomcat_port        = 8080,
  $tomcat_ajp_port    = undef,
  $catalina_home      = "/usr/share/${tomcat_package}",
  $catalina_base      = "/var/lib/${tomcat_package}",
  $catalina_opts      = '-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC',
  # DSpace Admin User Account settings (optional)
  $admin_firstname    = undef,
  $admin_lastname     = undef,
  $admin_email        = undef,
  $admin_passwd       = undef,
  $admin_language     = undef,
  $handle_prefix      = '123456789',
)
{
    # Default to requiring all packages be installed
    Package {
      ensure => installed,
    }

    # Install Maven & Ant which are required to build & deploy, respectively
    # For Maven, do NOT install "recommended" apt-get packages, as this will
    # install OpenJDK 6 and always set it as the default Java alternative
    package { 'maven':
      install_options => ['--no-install-recommends'],
      before          => Package['java'],
    }
    package { "ant":
      before => Package['java'],
    }

    # Install Git, needed for any DSpace development
    package { "git":
    }

    # Java installation directory
    $java_install_dir = "/usr/lib/jvm"

    # OpenJDK version/directory name (NOTE: $architecture is a "fact")
    $java_name = "java-${java_version}-openjdk-${architecture}"

    # Install Java, based on set $java_version
    package { "java":
      name => "openjdk-${java_version}-jdk",  # Install OpenJDK package (as Oracle JDK tends to require a more complex manual download & unzip)
    }

 ->

    # Set Java defaults to point at OpenJDK
    # NOTE: $architecture is a "fact" automatically set by Puppet's 'facter'.
    exec { "Update alternatives to OpenJDK Java ${java_version}":
      command => "update-java-alternatives --set ${java_name}",
      unless  => "test \$(readlink /etc/alternatives/java) = '${java_install_dir}/${java_name}/jre/bin/java'",
      path    => "/usr/bin:/usr/sbin:/bin",
    }

 ->

    # Create a "default-java" symlink (for easier JAVA_HOME setting). Overwrite if existing.
    exec { "Symlink OpenJDK to '${java_install_dir}/default-java'":
      cwd     => $java_install_dir,
      command => "ln -sfn ${java_name} default-java",
      unless  => "test \$(readlink default-java) = '${java_name}'",
      path    => "/usr/bin:/usr/sbin:/bin",
    }
}
