# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{simianarmy-ruote-amqp}
  s.version = "0.9.21"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Kenneth Kalmer"]
  s.date = %q{2010-05-31}
  s.description = %q{ruote-amqp provides an AMQP participant/listener pair that allows you to 
distribute workitems out to AMQP consumers for processing.

To learn more about remote participants in ruote please see
http://openwfe.rubyforge.org/part.html}
  s.email = ["kenneth.kalmer@gmail.com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "PostInstall.txt", "TODO.txt"]
  s.files = ["History.txt", "Manifest.txt", "PostInstall.txt", "README.rdoc", "Rakefile", "TODO.txt", "lib/ruote-amqp.rb", "lib/ruote-amqp/listener.rb", "lib/ruote-amqp/participant.rb", "lib/spec/ruote.rb", "lib/spec/ruote_example_group.rb", "lib/spec/ruote_helpers.rb", "lib/spec/ruote_matchers.rb", "script/console", "script/destroy", "script/generate", "spec/listener_spec.rb", "spec/participant_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/rspec.rake"]
  s.homepage = %q{http://github.com/kennethkalmer/ruote-amqp}
  s.post_install_message = %q{PostInstall.txt}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{simianarmy-ruote-amqp}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{ruote-amqp provides an AMQP participant/listener pair that allows you to  distribute workitems out to AMQP consumers for processing}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ruote>, ["= 0.9.21"])
      s.add_runtime_dependency(%q<amqp>, ["= 0.6.7"])
      s.add_development_dependency(%q<hoe>, [">= 2.4.0"])
    else
      s.add_dependency(%q<ruote>, ["= 0.9.21"])
      s.add_dependency(%q<amqp>, ["= 0.6.7"])
      s.add_dependency(%q<hoe>, [">= 2.4.0"])
    end
  else
    s.add_dependency(%q<ruote>, ["= 0.9.21"])
    s.add_dependency(%q<amqp>, ["= 0.6.7"])
    s.add_dependency(%q<hoe>, [">= 2.4.0"])
  end
end
