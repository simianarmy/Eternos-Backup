# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{SyslogLogger}
  s.version = "1.4.0"

  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.authors = ["Eric Hodel"]
  s.cert_chain = nil
  s.date = %q{2007-05-08}
  s.description = %q{SyslogLogger is a Logger replacement that logs to syslog.  It is almost drop-in with a few caveats.}
  s.email = %q{drbrain@segment7.net}
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "lib/analyzer_tools/syslog_logger.rb", "lib/syslog_logger.rb", "test/test_syslog_logger.rb"]
  s.homepage = %q{http://seattlerb.rubyforge.org/SyslogLogger}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0")
  s.rubyforge_project = %q{seattlerb}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{SyslogLogger is a Logger replacement that logs to syslog.  It is almost drop-in with a few caveats.}
  s.test_files = ["test/test_syslog_logger.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 1

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<hoe>, [">= 1.2.0"])
    else
      s.add_dependency(%q<hoe>, [">= 1.2.0"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.2.0"])
  end
end
