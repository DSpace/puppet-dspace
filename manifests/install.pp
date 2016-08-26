# Definition: dspace::install
#
# Each time this is called, the following happens:
#  - DSpace source is pulled down from GitHub
#  - DSpace Maven build process is run (if it has not yet been run)
#  - DSpace Ant installation process is run (if it has not yet been run)
#
# Tested on:
# - Ubuntu 16.04
#
# Parameters:
# - $owner              => OS User who should own DSpace instance
# - $group              => Group who should own DSpace instance.
# - $src_dir            => Location where DSpace source should be kept
# - $install_dir        => Location where DSpace instance should be installed (defaults to $name)
# - $git_repo           => Git repository to pull DSpace source from. Defaults to DSpace/DSpace in GitHub
# - $git_branch         => Git branch to build DSpace from. Defaults to "master".
# - $mvn_params         => Any build params passed to Maven. Defaults to "-Denv=custom" which tells Maven to use the custom.properties file.
# - $ant_installer_dir  => Name of directory where the Ant installer is built to (via Maven).
# - $admin_firstname    => First Name of the created default DSpace Administrator account.
# - $admin_lastname     => Last Name of the created default DSpace Administrator account.
# - $admin_email        => Email of the created default DSpace Administrator account.
# - $admin_passwd       => Initial Password of the created default DSpace Administrator account.
# - $admin_language     => Language of the created default DSpace Administrator account.
# - $ensure => Whether to ensure DSpace instance is created ('present', default value) or deleted ('absent')
#
# Sample Usage:
# dspace::install { '/dspace':
#    owner      => "dspace",
#    git_branch => "master",
# }
#
define dspace::install ($owner             = $dspace::owner,
                        $group             = $dspace::group,
                        $src_dir           = $dspace::src_dir,
                        $install_dir       = $name,
                        $git_repo          = $dspace::git_repo,
                        $git_branch        = $dspace::git_branch,
                        $mvn_params        = $dspace::mvn_params,
                        $ant_installer_dir = $dspace::installer_dir_name,
                        $admin_firstname   = $dspace::admin_firstname,
                        $admin_lastname    = $dspace::admin_lastname,
                        $admin_email       = $dspace::admin_email,
                        $admin_passwd      = $dspace::admin_passwd,
                        $admin_language    = $dspace::admin_language,
                        $ensure            = present)
{
    # Full path to Ant Installer (based on passed in $src_dir)
    $ant_installer_path = "${src_dir}/dspace/target/${ant_installer_dir}"


    # ensure that the install_dir exists, and has proper permissions
    file { "${install_dir}":
        ensure => "directory",
        owner  => $owner,
        group  => $group,
        mode   => 0700,
    }

->

    ### BEGIN clone of DSpace from GitHub to ~/dspace-src (this is a bit of a strange way to ckeck out, we do it this
    ### way to support cases where src_dir already exists)

    # if the src_dir folder does not yet exist, create it
    file { "${src_dir}":
        ensure => directory,
        owner  => $owner,
        group  => $group,
        mode   => 0700,
    }

->

    exec { "Cloning DSpace source code into ${src_dir}":
        command   => "git init && git remote add origin ${git_repo} && git fetch --all && git checkout master && chown -R ${owner}:${group} ${src_dir}",
        creates   => "${src_dir}/.git",
        cwd       => $src_dir, # run command from this directory
        logoutput => true,
        tries     => 2,    # try 2 times
        timeout   => 600,  # set a 10 min timeout. GitHub is sometimes slow. If it's too slow, might as well get everything else done
     }


    ### END clone of DSpace

->

    # Checkout the specified branch
    exec { "Checkout branch ${git_branch}" :
       command => "git checkout ${git_branch}",
       cwd     => $src_dir, # run command from this directory
       user    => $owner,
       # Only perform this checkout if the branch EXISTS and it is NOT currently checked out (if checked out it will have '*' next to it in the branch listing)
       onlyif  => "git branch -a | grep -w '${git_branch}' && git branch | grep '^\\*' | grep -v '^\\* ${git_branch}\$'",
    }

->

   # Create a 'custom.properties' file which will be used by older versions of DSpace to build the DSpace installer
   # (INSTEAD OF the default 'build.properties' file that DSpace normally uses)
   # kept for backwards compatibility, no longer needed for DSpace 6+
   file { "${src_dir}/custom.properties":
     ensure  => file,
     owner   => $owner,
     group   => $group,
     mode    => 0644,
     backup  => ".puppet-bak",  # If replaced, backup old settings to .puppet-bak
     content => template("dspace/custom.properties.erb"),
   }

->

# Create a 'local.cfg' file which will be used by newer versions of DSpace (6+) to build the DSpace installer
   file { "${src_dir}/local.cfg":
     ensure  => file,
     owner   => $owner,
     group   => $group,
     mode    => 0644,
     backup  => ".puppet-bak",  # If replaced, backup old settings to .puppet-bak
     content => template("dspace/local.cfg.erb"),
   }

->

   # Build DSpace installer.
   # (NOTE: by default, $mvn_params='-Denv=custom', which tells Maven to use the custom.properties file created above)
   exec { "Build DSpace installer in ${src_dir}":
     command   => "mvn package ${mvn_params}",
     cwd       => "${src_dir}", # Run command from this directory
     user      => $owner,
     creates   => $ant_installer_path, # Only run if Ant installer directory doesn't already exist
     timeout   => 0, # Disable timeout. This build takes a while!
     logoutput => true,    # Send stdout to puppet log file (if any)
   }

->

   # Install DSpace (via Ant)
   exec { "Install DSpace to ${install_dir}":
     command   => "ant fresh_install",
     cwd       => $ant_installer_path,    # Run command from this directory
     user      => $owner,
     creates   => "${install_dir}/webapps/xmlui",    # Only run if XMLUI webapp doesn't yet exist (NOTE: we check for a webapp's existence since this is the *last step* of the install process)
     logoutput => true,    # Send stdout to puppet log file (if any)
   }

   # Create initial administrator (if specified)
   if $admin_email and $admin_passwd and $admin_firstname and $admin_lastname and $admin_language
   {
     exec { "Create DSpace Administrator":
       command   => "${install_dir}/bin/dspace create-administrator -e ${admin_email} -f ${admin_firstname} -l ${admin_lastname} -p ${admin_passwd} -c ${admin_language}",
       cwd       => $install_dir,
       user      => $owner,
       logoutput => true,
       require   => Exec["Install DSpace to ${install_dir}"],
     }
   }

}
