# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{amqp}
  s.version = "0.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aman Gupta"]
  s.date = %q{2009-01-09}
  s.description = %q{AMQP client implementation in Ruby/EventMachine}
  s.email = %q{amqp@tmm1.net}
  s.extra_rdoc_files = ["README"]
  s.files = ["README", "examples/amqp/simple.rb", "examples/mq/clock.rb", "examples/mq/hashtable.rb", "examples/mq/logger.rb", "examples/mq/pingpong.rb", "examples/mq/primes-simple.rb", "examples/mq/primes.rb", "examples/mq/simple-ack.rb", "examples/mq/simple-get.rb", "examples/mq/simple.rb", "examples/mq/stocks.rb", "lib/amqp/buffer.rb", "lib/amqp/client.rb", "lib/amqp/frame.rb", "lib/amqp/protocol.rb", "lib/amqp/spec.rb", "lib/amqp.rb", "lib/ext/blankslate.rb", "lib/ext/em.rb", "lib/ext/emfork.rb", "lib/mq/exchange.rb", "lib/mq/header.rb", "lib/mq/logger.rb", "lib/mq/queue.rb", "lib/mq/rpc.rb", "lib/mq.rb", "protocol/amqp-0.8.json", "protocol/codegen.rb", "protocol/doc.txt", "protocol/amqp-0.8.xml"]
  s.homepage = %q{http://amqp.rubyforge.org/}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{AMQP client implementation in Ruby/EventMachine}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<eventmachine>, [">= 0.12.2"])
    else
      s.add_dependency(%q<eventmachine>, [">= 0.12.2"])
    end
  else
    s.add_dependency(%q<eventmachine>, [">= 0.12.2"])
  end
end
