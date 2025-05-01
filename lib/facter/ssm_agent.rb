# frozen_string_literal: true

require 'json'

Facter.add(:ssm_agent) do
  # https://puppet.com/docs/puppet/latest/fact_overview.html
  setcode do
    fact = { 'installed' => false, 'diagnostics' => [] }

    case Facter.value(:os)['family']
    when 'windows'
      ssm_path = 'C:\\Program Files\\Amazon\\SSM\\ssm-cli.exe'
      if File.exist?(ssm_path)
        fact['installed'] = true
        diagnostics = Facter::Core::Execution.execute("\"#{ssm_path}\" get-diagnostics", on_fail: nil)
        fact['diagnostics'] = JSON.parse(diagnostics)['DiagnosticsOutput'] if diagnostics
      end
    when 'Debian'
      ssm_path = if File.exist?('/snap/bin/ssm-cli')
                   '/snap/bin/ssm-cli'
                 elsif File.exist?('/usr/bin/ssm-cli')
                   '/usr/bin/ssm-cli'
                 end
      if ssm_path
        fact['installed'] = true
        diagnostics = Facter::Core::Execution.execute("#{ssm_path} get-diagnostics", on_fail: nil)
        fact['diagnostics'] = JSON.parse(diagnostics)['DiagnosticsOutput'] if diagnostics
      end
    when 'RedHat'
      ssm_path = '/usr/bin/ssm-cli'
      if File.exist?(ssm_path)
        fact['installed'] = true
        diagnostics = Facter::Core::Execution.execute("#{ssm_path} get-diagnostics", on_fail: nil)
        fact['diagnostics'] = JSON.parse(diagnostics)['DiagnosticsOutput'] if diagnostics
      end
    end

    fact
  end
end
