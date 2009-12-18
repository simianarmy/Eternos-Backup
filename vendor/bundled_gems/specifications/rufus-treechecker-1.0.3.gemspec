# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-treechecker}
  s.version = "1.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2008-10-28}
  s.email = %q{john at openwfe dot org}
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["lib/rufus", "lib/rufus/treechecker.rb", "lib/rufus-treechecker.rb", "test/bm.rb", "test/ft_0_basic.rb", "test/ft_1_old_treechecker.rb", "test/ft_2_clone.rb", "test/test.rb", "test/testmixin.rb", "README.txt"]
  s.homepage = %q{http://rufus.rubyforge.org/rufus-treechecker}
  s.require_paths = ["lib"]
  s.requirements = ["ruby_parser"]
  s.rubyforge_project = %q{rufus}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{checking ruby code before eval()}
  s.test_files = ["test/test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ruby_parser>, [">= 0"])
    else
      s.add_dependency(%q<ruby_parser>, [">= 0"])
    end
  else
    s.add_dependency(%q<ruby_parser>, [">= 0"])
  end
end
