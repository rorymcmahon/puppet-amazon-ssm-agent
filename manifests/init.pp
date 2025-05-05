# Class: amazon_ssm_agent
# ===========================
#
# Download and install Amazon System Management Agent, amazon-ssm-agent.
#
# Parameters
# ----------
#
# @param activation_code
# Data Type: String
# The activation code for the SSM agent. This is used to register the instance with SSM.
# Default value: undef
#
# @param activation_id
# Data Type: String
# The activation ID for the SSM agent. This is used to register the instance with SSM.
# Default value: undef
# @param region
# Data Type: String
# The AWS region from where the package will be downloaded
# Default value: us-east-1
#
# @param proxy_url
# Data Type: String
# The proxy URL in <protocol>://<host>:<port> format, specify if the ssm agent needs to communicate via a proxy
# Default value: undef
#
# @param service_enable
# Data Type: Boolean
# Ensure state of the service. Can be 'running', 'stopped', true, or false
# Default value: 'running'
#
# @param service_ensure
# Data Type: String, Boolean
# Whether to enable the service.
# Default value: true
#
# @param tmp_dir
# Data Type: String
# The directory to download the package to. 
# Default value: '/tmp'
#
# @param register
# Data Type: Boolean
# Whether to register the instance with SSM.
#
#
# Examples
# --------
# @example
#    class { 'amazon_ssm_agent':
#      region    => 'ap-southeast-2',
#      proxy_url => 'http://someproxy:3128',
#    }
#
# Authors
# -------
#
# Andy Wang <andy.wang@shinesolutions.com>
# Rory McMahon <rory.mcmahon@vocus.com.au>
#
# Copyright
# ---------
#
# Copyright 2017-2019 Shine Solutions, forked by Vocus Group 
#
class amazon_ssm_agent (
  String $activation_code,
  String $activation_id,
  String $region              = 'us-east-1',
  Optional[String] $proxy_url = undef,
  Boolean $service_enable     = true,
  String $service_ensure      = 'running',
  String $tmp_dir            = '/tmp',
  Boolean $register           = false,
) {
  $pkg_provider = lookup('amazon_ssm_agent::pkg_provider', String, 'first')
  $pkg_format   = lookup('amazon_ssm_agent::pkg_format', String, 'first')
  $flavor       = lookup('amazon_ssm_agent::flavor', String, 'first')

  $srv_provider = lookup('amazon_ssm_agent::srv_provider', String, 'first')

  # Registration string
  $registration = "-register -activation-code ${activation_code} -activation-id ${activation_id} -region ${region}"

  case $facts['os']['architecture'] {
    'x86_64','amd64': {
      $architecture = 'amd64'
    }
    'i386': {
      $architecture = '386'
    }
    'aarch64','arm64': {
      $architecture = 'arm64'
    }
    default: {
      fail("Module not supported on ${facts['os']['architecture']} architecture")
    }
  }

  # Example source url format: 
  # https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/3.0.1479.0/linux_amd64/amazon-ssm-agent.rpm
  # https://s3.ap-southeast-2.amazonaws.com/amazon-ssm-ap-southeast-2/latest/linux_amd64/ssm-setup-cli
  # https://s3.ap-southeast-2.amazonaws.com/amazon-ssm-ap-southeast-2/latest/debian_amd64/ssm-setup-cli
  # https://s3.ap-southeast-2.amazonaws.com/amazon-ssm-ap-southeast-2/latest/windows_amd64/ssm-setup-cli.exe

  # Determine the package format based on the OS
  if $facts['os']['family'] == 'RedHat' and Integer($facts['os']['release']['major']) >= 7 {
    $filename = 'ssm-setup-cli'
    $download_url = "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_${architecture}/${filename}"
    $service_name = 'amazon-ssm-agent'
  } elsif $facts['os']['family'] == 'RedHat' and Integer($facts['os']['release']['major']) < 7 {
    $filename = 'amazon-ssm-agent.rpm'
    $download_url = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/3.0.1479.0/linux_${architecture}/${filename}"
    $service_name = 'amazon-ssm-agent'
  } elsif $facts['os']['family'] == 'Debian' {
    $filename = 'ssm-setup-cli'
    $download_url = "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/debian_${architecture}/${filename}"
    $service_name = 'snap.amazon-ssm-agent.amazon-ssm-agent.service'
  } elsif $facts['os']['family'] == 'windows' {
    $filename = 'ssm-setup-cli.exe'
    $download_url = "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/windows_${architecture}/${filename}"
    $service_name = 'AmazonSSMAgent'
  } else {
    fail("Module not supported on ${facts['os']['family']}")
  }

  # Check if SSM is installed using custom fact
  if $facts['ssm_agent']['installed'] {
    # Remove the installer from the temp dir
    file { "${tmp_dir}/${filename}":
      ensure => absent,
    }
  } else {
    # Download the install script or package 
    file { "${tmp_dir}/${filename}":
      ensure => file,
      source => $download_url,
      mode   => '0755',
    }
    # On legacy RHEL systems install the RPM package
    if $facts['os']['family'] == 'RedHat' and Integer($facts['os']['release']['major']) < 7 {
      package { 'amazon-ssm-agent':
        ensure  => installed,
        source  => "${tmp_dir}/${filename}",
        require => File["${tmp_dir}/${filename}"],
      }
    } else {
      # Install the agent using the install script
      exec { 'install-ssm-agent':
        command     => "${tmp_dir}/${filename} ${registration}",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        subscribe   => File["${tmp_dir}/${filename}"],
      }
    }
  }

  if $service_ensure {
    service { $service_name:
      ensure => $service_ensure,
      enable => $service_enable,
    }
  }
}
