define bacula::config::client (
  $fileset  = 'Basic:noHome',
  $bacula_schedule = 'WeeklyCycle',
  $template = 'bacula/client_config.erb',
  $director_service = $bacula::config::director_service,
  ) {

  if ! is_domain_name($name) {
    fail "Name for client ${name} must be a fully qualified domain name"
  }

  $hostname   = $name

  file { "/etc/bacula/bacula-dir.d/${name}.conf":
    ensure  => file,
    content => template($template),
  }
}
