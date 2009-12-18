# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-mnemo}
  s.version = "1.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2009-11-30}
  s.description = %q{Turning (large) integers into japanese sounding words and vice versa}
  s.email = %q{jmettraux@gmail.com}
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["lib/rufus/mnemo.rb", "lib/rufus-mnemo.rb", "test/test.rb", "README.txt"]
  s.homepage = %q{http://rufus.rubyforge.org/rufus-mnemo}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rufus}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Turning (large) integers into japanese sounding words and vice versa}
  s.test_files = ["test/test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
