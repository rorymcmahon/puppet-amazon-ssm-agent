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

  # Extract the package to the tmp dir and install it
  archive { "${tmp_dir}/amazon-ssm-agent.${pkg_format}":
    ensure  => present,
    extract => false,
    cleanup => false,
    source  => "https://amazon-ssm-${region}.s3.amazonaws.com/latest/${flavor}_${architecture}/amazon-ssm-agent.${pkg_format}",
    creates => "${tmp_dir}/amazon-ssm-agent.${pkg_format}",
  } -> package { 'amazon-ssm-agent':
    ensure   => latest,
    provider => $pkg_provider,
    source   => "${tmp_dir}/amazon-ssm-agent.${pkg_format}",
  }

  if $register {
    exec { 'register-ssm-agent':
      command     => "amazon-ssm-agent -register -activation-code ${activation_code} -activation-id ${activation_id} -region ${region}",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      subscribe   => Package['amazon-ssm-agent'],
    }
  }

  if $service_ensure {
    class { '::amazon_ssm_agent::proxy':
      proxy_url    => $proxy_url,
      srv_provider => $srv_provider,
      require      => Package['amazon-ssm-agent'],
    }

    service { 'amazon-ssm-agent':
      ensure   => $service_ensure,
      enable   => $service_enable,
      provider => $srv_provider,
    }

    Class['::amazon_ssm_agent::proxy'] -> Service['amazon-ssm-agent']
  }

  # Cleanup the agent package 
  file { "${tmp_dir}/amazon-ssm-agent.${pkg_format}":
    ensure  => absent,
    require => Package['amazon-ssm-agent'],
  }
}
