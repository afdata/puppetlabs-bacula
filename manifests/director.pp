# Class: bacula::director
#
# This class manages the bacula director component
#
# Parameters:
#   $server:
#     The FQDN of the bacula director
#   $password:
#     The password of the director
#   $db_backend:
#     The DB backend to store the catalogs in. (Currently only support sqlite)
#   $storage_server:
#     The FQDN of the storage daemon server
#   $director_package:
#     The name of the package that installs the director (Optional)
#   $mysql_package:
#     The name of the package that installs the mysql support for the director
#   $sqlite_package:
#     The name of the package that installs the sqlite support for the director
#   $postgresql_package:
#     The name of the package that installs the postgresql support for the director
#   $template:
#     The ERB template to us to generate the bacula-dir.conf file
#     - Default: 'bacula/bacula-dir.conf.erb'
#   $use_console:
#     Whether to manage the Console resource in the director
#   $director_service:
#     Name of the bacula director service start-stop skript
#   $console_password:
#     If $use_console is true, then use this value for the password
#   $pid_directory:
#    this is the directory where the
#   $custom_config
#    for the custom bacula directory config
#
# Sample Usage:
#
# class { 'bacula::director':
#   server           => 'bacula.domain.com',
#   password         => 'XXXXXXXXX',
#   db_backend       => 'sqlite',
#   storage_server   => 'bacula.domain.com',
#   mail_to          => 'bacula-admin@domain.com',
#   use_console      => true,
#   console_password => 'XXXXXX',
# }
class bacula::director(
    $server,
    $password,
    $db_backend,
    $db_user,
    $db_password,
    $db_host,
    $db_database,
    $db_port,
    $storage_server,
    $director_package,
    $mysql_package,
    $postgresql_package,
    $sqlite_package,
    $mail_to,
    $mail_from,
    $use_console,
    $console_password,
    $storage_password,
    $director_service,
    $pid_directory,
    $working_directory,
    $manage_db_tables,
    $starttime,
    $custom_config,
    $clients = {},
    $template = 'bacula/bacula-dir.conf.erb',
  ) {

  $storage_name = $storage_server
  $director_name = $server

  # Only support mysql or sqlite.
  # The given backend is validated in the bacula::config::validate class
  # before this code is reached.
  $db_package = $db_backend ? {
    'mysql'  => $mysql_package,
    'sqlite' => $sqlite_package,
    'postgresql' => $postgresql_package,
  }

  if $director_package {
    package { $director_package:
      ensure => installed,
      before => File['/etc/bacula/bacula-dir.conf', '/etc/bacula/bacula-dir.d']
    }
  }

  if $db_package and ! defined(Package[$db_package]) {
    package { $db_package:
      ensure => installed,
    }
  }

  # Create the configuration for the Director and make sure the directory for
  # the per-Client configuration is created before we run the realization for
  # the exported files below
  file { '/etc/bacula/bacula-dir.conf':
    ensure  => file,
    owner   => 'bacula',
    group   => 'bacula',
    content => template($template),
    notify  => Service[$director_service],
  }

  file { '/etc/bacula/bacula-dir.d':
    ensure  => directory,
    owner   => 'bacula',
    group   => 'bacula',
    purge   => true,
    recurse => true,
    before  => Service[$director_service],
  }

  file { '/etc/bacula/bacula-dir.d/empty.conf':
    ensure => file,
    before => Service[$director_service],
  }

  if $custom_config {
    file { '/etc/bacula/bacula-dir-custom.d':
      ensure => directory,
      owner  => 'bacula',
      group  => 'bacula',
      purge  => true,
      before => Service[$director_service],
    }
  }

  if $manage_db_tables {
    exec { 'make_db_tables':
      command     => "make_bacula_tables ${db_backend}",
      path        => '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/lib64/bacula:/usr/lib/bacula:/usr/libexec/bacula',
      refreshonly => true,
      environment => [ "db_name=${db_database}", "db_password=${db_password}", "db_user=${db_user}" ],
      require     => Package['bacula-director'],
      notify      => Service["bacula:${director_service}"],
    } ~>

    exec { 'grant_bacula_privileges':
      command     => "grant_bacula_privileges ${db_backend}",
      path        => '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/lib64/bacula:/usr/lib/bacula:/usr/libexec/bacula',
      refreshonly => true,
      environment => [ "db_name=${db_database}", "db_password=${db_password}", "db_user=${db_user}" ],
      notify      => Service["bacula:${director_service}"],
    }

  }

  # Register the Service so we can manage it through Puppet
  service { "bacula:${director_service}":
    ensure     => running,
    name       => $director_service,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => $db_package ? {
      ''      => undef,
      default => Package[$db_package],
    }
  }
}
