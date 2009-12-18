# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rufus-scheduler}
  s.version = "2.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2009-11-04}
  s.description = %q{
    job scheduler for Ruby (at, cron, in and every jobs).

    By default uses a Ruby thread, if EventMachine is present, it will rely on it.
  }
  s.email = %q{jmettraux@gmail.com}
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG.txt", "CREDITS.txt", "LICENSE.txt"]
  s.files = ["lib/rufus/otime.rb", "lib/rufus/sc/cronline.rb", "lib/rufus/sc/jobqueues.rb", "lib/rufus/sc/jobs.rb", "lib/rufus/sc/rtime.rb", "lib/rufus/sc/scheduler.rb", "lib/rufus/scheduler.rb", "lib/rufus-scheduler.rb", "CHANGELOG.txt", "CREDITS.txt", "LICENSE.txt", "TODO.txt", "README.rdoc", "spec/spec.rb"]
  s.homepage = %q{http://github.com/jmettraux/rufus-scheduler}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rufus}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{job scheduler for Ruby (at, cron, in and every jobs)}
  s.test_files = ["spec/spec.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
