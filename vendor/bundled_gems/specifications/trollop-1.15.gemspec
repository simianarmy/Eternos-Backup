# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{trollop}
  s.version = "1.15"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["William Morgan"]
  s.date = %q{2009-09-29}
  s.description = %q{Documentation quickstart: See Trollop::options (for some reason rdoc isn't
linking that; it's in the top right of the screen if you're browsing online)
and then Trollop::Parser#opt. Also see the examples at
http://trollop.rubyforge.org/.

== DESCRIPTION

== REQUIREMENTS

* A burning desire to write less code.

== INSTALL

* gem install trollop

== LICENSE

Copyright (c) 2008--2009 William Morgan. Trollop is distributed under the same
terms as Ruby.


}
  s.email = %q{wmorgan-trollop@masanjin.net}
  s.extra_rdoc_files = ["FAQ.txt", "History.txt", "Manifest.txt", "README.txt"]
  s.files = ["FAQ.txt", "History.txt", "Manifest.txt", "README.txt", "Rakefile", "lib/trollop.rb", "test/test_trollop.rb"]
  s.homepage = %q{http://trollop.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{trollop}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Trollop is a commandline option parser for Ruby that just gets out of your way. One line of code per option is all you need to write. For that, you get a nice automatically-generated help page, robust option parsing, command subcompletion, and sensible defaults for everything you don't specify.}
  s.test_files = ["test/test_trollop.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
