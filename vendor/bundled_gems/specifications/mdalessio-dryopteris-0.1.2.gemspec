# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{mdalessio-dryopteris}
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bryan Helmkamp", "Mike Dalessio"]
  s.date = %q{2009-02-10}
  s.description = %q{Dryopteris erythrosora is the Japanese Shield Fern. It also can be used to sanitize HTML to help prevent XSS attacks.}
  s.email = ["bryan@brynary.com", "mike.dalessio@gmail.com"]
  s.files = ["README.markdown", "VERSION.yml", "lib/dryopteris", "lib/dryopteris/rails_extension.rb", "lib/dryopteris/sanitize.rb", "lib/dryopteris/whitelist.rb", "lib/dryopteris.rb", "test/test_basic.rb", "test/test_strip_tags.rb", "test/helper.rb", "test/test_sanitizer.rb"]
  s.homepage = %q{http://github.com/brynary/dryopteris/tree/master}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{HTML sanitization using Nokogiri}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, ["> 0.0.0"])
    else
      s.add_dependency(%q<nokogiri>, ["> 0.0.0"])
    end
  else
    s.add_dependency(%q<nokogiri>, ["> 0.0.0"])
  end
end
