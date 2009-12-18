# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-dollar}
  s.version = "1.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2009-02-03}
  s.email = %q{jmettraux@gmail.com}
  s.extra_rdoc_files = ["README.txt", "CHANGELOG.txt", "LICENSE.txt"]
  s.files = ["lib/rufus", "lib/rufus/dollar.rb", "lib/rufus-dollar.rb", "test/dollar_test.rb", "test/nested_test.rb", "test/test.rb", "test/test_base.rb", "README.txt", "CHANGELOG.txt", "LICENSE.txt"]
  s.homepage = %q{http://rufus.rubyforge.org/rufus-dollar}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{${xxx} substitutions}
  s.test_files = ["test/test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
