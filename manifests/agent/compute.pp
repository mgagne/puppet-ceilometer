#
class ceilometer::agent::compute (
  $auth_url         = 'http://localhost:5000/v2.0',
  $auth_region      = 'RegionOne',
  $auth_user        = 'ceilometer',
  $auth_password    = 'password',
  $auth_tenant_name = 'services',
  $auth_tenant_id   = '',
  $enabled          = true,
) inherits ceilometer {

  include ceilometer::params

  Ceilometer_config<||> ~> Service['ceilometer-agent-compute']

  Package['ceilometer-agent-compute'] -> Service['ceilometer-agent-compute']
  package { 'ceilometer-agent-compute':
    ensure => installed,
    name   => $::ceilometer::params::agent_compute_package_name,
  }

  if $::ceilometer::params::libvirt_group {
    User['ceilometer'] {
      groups +> [$::ceilometer::params::libvirt_group]
    }
  }


  if $enabled {
    $service_ensure = 'running'
  } else {
    $service_ensure = 'stopped'
  }

  Package['ceilometer-common'] -> Service['ceilometer-agent-compute']
  service { 'ceilometer-agent-compute':
    ensure     => $service_ensure,
    name       => $::ceilometer::params::agent_compute_service_name,
    enable     => $enabled,
    hasstatus  => true,
    hasrestart => true,
  }

  ceilometer_config {
    'DEFAULT/os_auth_url'         : value => $auth_url;
    'DEFAULT/os_auth_region'      : value => $auth_region;
    'DEFAULT/os_username'         : value => $auth_user;
    'DEFAULT/os_password'         : value => $auth_password;
    'DEFAULT/os_tenant_name'      : value => $auth_tenant_name;
  }

  if ($auth_tenant_id != '') {
    ceilometer_config {
      'DEFAULT/os_tenant_id'        : value => $auth_tenant_id;
    }
  }

  nova_config {
    'DEFAULT/instance_usage_audit'        : value => 'True';
    'DEFAULT/instance_usage_audit_period' : value => 'hour';
  }

  Nova_config<| |> {
    before +> File_line[
      'nova-notification-driver-common',
      'nova-notification-driver-ceilometer'
    ],
  }

  file_line {
    'nova-notification-driver-common':
      line   => 'notification_driver=nova.openstack.common.notifier.rabbit_notifier',
      path   => '/etc/nova/nova.conf',
      notify => Service['nova-compute'];
    'nova-notification-driver-ceilometer':
      line   => 'notification_driver=ceilometer.compute.nova_notifier',
      path   => '/etc/nova/nova.conf',
      notify => Service['nova-compute'];
  }

}
