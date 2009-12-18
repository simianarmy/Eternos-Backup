# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{mysqlplus}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Muhammad A. Ali"]
  s.date = %q{2009-03-22}
  s.description = %q{Enhanced Ruby MySQL driver}
  s.email = %q{oldmoe@gmail.com}
  s.extensions = ["ext/extconf.rb"]
  s.extra_rdoc_files = ["README"]
  s.files = ["README", "Rakefile", "TODO_LIST", "ext/error_const.h", "ext/extconf.rb", "ext/mysql.c", "lib/mysqlplus.rb", "mysqlplus.gemspec", "test/c_threaded_test.rb", "test/evented_test.rb", "test/native_threaded_test.rb", "test/test_all_hashes.rb", "test/test_failure.rb", "test/test_helper.rb", "test/test_many_requests.rb", "test/test_parsing_while_response_is_being_read.rb", "test/test_threaded_sequel.rb"]
  s.homepage = %q{http://github.com/oldmoe/mysqlplus}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Enhanced Ruby MySQL driver}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
