# Definition: dspace::owner
#
# Create the OS user account which will own this DSpace installation
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $username (REQUIRED) => OS Username (e.g. "dspace"), defaults to passed in $name
# - $gid                 => OS User's primary group (default is same as $username)
# - $groups		 => Additional groups (by name) to add user to
# - $sudoer              => Whether this person gets sudoer access (true or false, default=false)
# - $authorized_keys_source => Location of file which provides content for SSH authorized_keys
#                              (defaults to files/ssh_authorized_keys in this module)
# - $ensure              => Whether to ensure account is added (present) or deleted (absent)
# - $maven_opts          => value for this user's MAVEN_OPTS environment variable
#
# Sample Usage:
# dspace::owner { 'dspace':
# }
define dspace::owner ($username = $name,
                      $gid = $username,
                      $groups = undef,
                      $sudoer = false,
                      $authorized_keys_source = "puppet:///modules/dspace/ssh_authorized_keys",
                      $maven_opts = '-Xmx512m',
                      $ensure = 'present')
{

  # Require that the 'puppetlabs/stdlib' module be initialized,
  # as we utilize 'file_line' from that module
  include stdlib

  case $ensure
  {

    # Present = Create User & Initialize
    present: {

      # Ensure the user's group exists (if not, create it)
      group { $gid:
        ensure => present,
      }

      # Create the user account on the system
      user { $username:
        home       => "/home/$username",
        managehome => true,  # actually create & initialize home directory if not there
        shell      => "/bin/bash",
        gid        => $gid,  # user's primary group
        groups     => $groups,
        require    => Group[$gid],
      }

      # Make sure they have a home with proper permissions.
      file { "/home/${username}":
        ensure  => directory,
        owner   => $username,
        group   => $gid,
        mode    => 0750,
        require => User[$username],
      }

      # Make sure the ~/.bashrc includes 'umask 002' line
      file_line { "Set default umask for ${username}":
        path    => "/home/${username}/.bashrc",
        line    => "umask 002",
        require => User[$username],
      }

      # Make sure they have a ~/.ssh for SSH related configs
      file { "/home/${username}/.ssh":
        ensure  => directory,
        owner   => $username,
        group   => $gid,
        mode    => 0700,
        require => File["/home/${username}"],
      }

      if $authorized_keys_source {
        # Now make sure that the ssh key authorized files is around
        # and is initialized with our custom contents
        file { "/home/${username}/.ssh/authorized_keys":
          ensure  => present,
          owner   => $username,
          group   => $gid,
          mode    => 0600,
          source  => $authorized_keys_source,
          require => File["/home/${username}/.ssh"],
        }
      }

      # If this person should be given sudo privileges
      if $sudoer {
        # Create a /etc/sudoers.d/ file for this account, so they can use 'sudo' without a password
        file { "Give ${username} full sudo access":
          path    => "/etc/sudoers.d/${username}",
          mode    => 0440,			# Required mode of all files in /etc/sudoers.d/
          content => "${username} ALL=(ALL) NOPASSWD:ALL",
          require => User[$username],
        }
      }

      # Override default ~/.profile for this account with our user template
      file { "/home/${username}/.profile":
        ensure  => file,
        owner   => $username,
        group   => $gid,
        content => template("dspace/user-profile.erb"),
        require => User[$username],
      }
    }

    # Absent = Delete the user account and home directory
    # WARNING: This may delete the DSpace instance if it resides in the user home directory
    absent: {
      # Ensure user acct is deleted
      user { $username:
        ensure => absent,
      }

      # Ensure user home directory is deleted
      file { "/home/${username}":
        ensure  => absent,
        recurse => true,
        force   => true,
      }

      # Ensure sudoer file is deleted (if exists)
      file { "/etc/sudoers.d/${username}":
        ensure => absent,
      }
    }
    default: { fail "Unknown ${ensure} value for ensure" }
  }
}
