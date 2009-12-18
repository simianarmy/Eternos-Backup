# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-verbs}
  s.version = "0.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2008-05-27}
  s.email = %q{john at openwfe dot org}
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["lib/rufus", "lib/rufus/verbs", "lib/rufus/verbs/conditional.rb", "lib/rufus/verbs/cookies.rb", "lib/rufus/verbs/digest.rb", "lib/rufus/verbs/endpoint.rb", "lib/rufus/verbs/verbose.rb", "lib/rufus/verbs/version.rb", "lib/rufus/verbs.rb", "test/auth0_test.rb", "test/auth1_test.rb", "test/block_test.rb", "test/bm.rb", "test/conditional_test.rb", "test/cookie0_test.rb", "test/cookie1_test.rb", "test/dryrun_test.rb", "test/escape_test.rb", "test/fopen_test.rb", "test/https_test.rb", "test/iconditional_test.rb", "test/items.rb", "test/proxy_test.rb", "test/redir_test.rb", "test/simple_test.rb", "test/test.htdigest", "test/test.rb", "test/testbase.rb", "test/timeout_test.rb", "test/uri_test.rb", "README.txt"]
  s.homepage = %q{http://rufus.rubyforge.org/rufus-verbs}
  s.require_paths = ["lib"]
  s.requirements = ["rufus-lru"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{GET, POST, PUT, DELETE, with something around}
  s.test_files = ["test/test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rufus-lru>, [">= 0"])
    else
      s.add_dependency(%q<rufus-lru>, [">= 0"])
    end
  else
    s.add_dependency(%q<rufus-lru>, [">= 0"])
  end
end
