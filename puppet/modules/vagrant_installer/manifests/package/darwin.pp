# == Class: vagrant_installer::package::darwin
#
# This creates a package for Vagrant for Mac OS X.
#
class vagrant_installer::package::darwin {
  $file_cache_dir       = hiera("file_cache_dir")
  $install_location     = "/Applications/Vagrant"
  $pkg_sign_keychain    = hiera("darwin_pkg_keychain")
  $pkg_sign_name        = hiera("darwin_pkg_sign")
  $pkg_staging_dir      = "${file_cache_dir}/pkg-staging"
  $pkg_dist_path        = "${pkg_staging_dir}/vagrant.dist"
  $pkg_resources_dir    = "${pkg_staging_dir}/resources"
  $pkg_scripts_dir      = "${pkg_staging_dir}/scripts"
  $pkgbuild_output_path = "${pkg_staging_dir}/core.pkg"
  $productbuild_output_path = "${pkg_staging_dir}/Vagrant.pkg"
  $staging_dir          = $vagrant_installer::params::staging_dir
  $vagrant_version      = $vagrant_installer::params::vagrant_version

  $pkgbuild_options = "--root ${staging_dir} --identifier com.vagrant.vagrant --version ${vagrant_version} --install-location ${install_location} --scripts ${pkg_scripts_dir} --sign '${pkg_sign_name}' --keychain '${pkg_sign_keychain}' --timestamp=none"

  $productbuild_options = "--distribution ${pkg_dist_path} --resources ${pkg_resources_dir} --package-path ${pkg_staging_dir} --sign '${pkg_sign_name}' --keychain '${pkg_sign_keychain}' --timestamp=none"

  util::recursive_directory { $pkg_staging_dir: }

  #------------------------------------------------------------------
  # Resources
  #------------------------------------------------------------------
  file { $pkg_resources_dir:
    ensure  => directory,
    mode    => "0755",
    require => Util::Recursive_directory[$pkg_staging_dir],
  }

  file { "${pkg_resources_dir}/background.png":
    source  => "puppet:///modules/vagrant_installer/mac/background.png",
    mode    => "0644",
    tag     => "pkg-resource",
    require => File[$pkg_resources_dir],
  }

  file { "${pkg_resources_dir}/welcome.html":
    source  => "puppet:///modules/vagrant_installer/mac/welcome.html",
    mode    => "0644",
    tag     => "pkg-resource",
    require => File[$pkg_resources_dir],
  }

  file { "${pkg_resources_dir}/license.html":
    source  => "puppet:///modules/vagrant_installer/mac/license.html",
    mode    => "0644",
    tag     => "pkg-resource",
    require => File[$pkg_resources_dir],
  }

  # Make sure all the resources are done before the installer package
  File <| tag == "pkg-resource" |> -> Exec["installer-pkg"]

  #------------------------------------------------------------------
  # Scripts
  #------------------------------------------------------------------
  file { $pkg_scripts_dir:
    ensure  => directory,
    mode    => "0755",
    require => Util::Recursive_directory[$pkg_staging_dir],
  }

  file { "${pkg_scripts_dir}/postinstall":
    ensure  => present,
    content => template("vagrant_installer/package/darwin_postinstall.erb"),
    owner   => "root",
    group   => "wheel",
    mode    => "0755",
    require => File[$pkg_scripts_dir],
    tag     => "pkg-script",
  }

  # Make sure all the scripts are done before the component package
  File <| tag == "pkg-script" |> -> Exec["component-pkg"]

  #------------------------------------------------------------------
  # Pkg
  #------------------------------------------------------------------
  # First, create the component package using pkgbuild. The component
  # package contains the raw file structure that is installed via the
  # installer package.
  exec { "component-pkg":
    command   => "pkgbuild ${pkgbuild_options} ${pkgbuild_output_path}",
    creates   => $pkgbuild_output_path,
    logoutput => true,
  }

  # Create the distribution definition, an XML file that describes
  # what the installer will look and feel like.
  file { $pkg_dist_path:
    content => template("vagrant_installer/package/darwin_dist.erb"),
    mode    => "0644",
    require => Util::Recursive_directory[$pkg_staging_dir],
  }

  exec { "installer-pkg":
    command   => "productbuild ${productbuild_options} ${productbuild_output_path}",
    creates   => $productbuild_output_path,
    logoutput => true,
    require   => [
      Exec["component-pkg"],
      File[$pkg_dist_path],
    ],
  }
}
