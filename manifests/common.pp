# Class: bacula::common
#
# This class enforces common resources needed by all
# bacula components
#
# Actions:
#   - Enforce the bacula user and groups exist
#   - Enforce the /var/spool/bacula is a director and /var/lib/bacula points to it
#
# Sample Usage:
#
# class { 'bacula::common': }
class bacula::common(
    $manage_db,
    $manage_db_tables,
    $db_backend,
    $db_user,
    $db_database,
    $db_password,
    $db_port,
    $mysql_package,
    $postgresql_package,
    $sqlite_package,
    $working_directory,
    $pid_directory,
    $db_host,
  ) {

  $db_package = $db_backend ? {
    'mysql'  => $mysql_package,
    'sqlite' => $sqlite_package,
    'postgresql' => $postgresql_package,
  }

  if $db_package {
    package { $db_package:
      ensure => installed,
      notify => $manage_db_tables ? {
        true  => Exec['make_db_tables'],
        false => undef,
        undef => undef,
      }
    }
  }

  $db_parameters = $db_backend ? {
    'sqlite' => '',
    'mysql'  => "--host=${db_host} --user=${db_user} --password=${db_password} --port=${db_port} --database=${db_database}",
    'postgresql'  => "--host=${db_host} --username=${db_user} --port=${db_port} --dbname=${db_database}",
  }

  if $manage_db {
    case $db_backend {
      'mysql': {
        mysql::db { $db_database:
          user     => $db_user,
          password => $db_password,
          host     => $db_host,
          notify   => $manage_db_tables ? {
            true  => Exec['make_db_tables'],
            false => undef,
          },
          require  => defined(Class['mysql::server']) ? {
            true  => Class['mysql::server'],
            false => undef,
          },
        }
      }

      'postgresql': {
        Postgresql_psql {
          cwd => '/',
        }
        $pgsql_password = postgresql_password($db_user, $db_password)
        postgresql::server::db { $db_database:
          user     => $db_user,
          password => $pgsql_password,
          owner    => $db_user,
          encoding => 'SQL_ASCII',
          notify   => $manage_db_tables ? {
            true  => Exec['make_db_tables'],
            false => undef,
          },
          require  => defined(Class['postgresql::server']) ? {
            true  => Class['postgresql::server'],
            false => undef,
          },
        }
        Postgresql::Server::Role[$db_user] -> Postgresql::Server::Database[$db_database]
      }

      'sqlite': {
        sqlite::db { $db_database:
          ensure   => present,
          location => "/var/lib/bacula/${db_database}.db",
          owner    => 'bacula',
          group    => 'bacula',
          require  => File['/var/lib/bacula'],
        }
      }

      default: {
        fail "The bacula module does not support managing the ${db_backend} backend database"
      }
    }
  }

  user { 'bacula':
    ensure => present,
    gid    => 'bacula',
  }

  group { 'bacula':
    ensure => present,
  }

  file { $working_directory:
    ensure => directory,
    owner  => bacula,
    group  => bacula,
  }

  file { '/var/log/bacula':
    ensure  => directory,
    owner   => bacula,
    group   => bacula,
    recurse => true,
  }

  file { $pid_directory:
    ensure => directory,
    owner  => bacula,
    group  => bacula,
  }
}
