# DO NOT MODIFY THIS FILE
module Bundler
 file = File.expand_path(__FILE__)
 dir = File.dirname(file)

  ENV["PATH"]     = "#{dir}/bin:#{ENV["PATH"]}"
  ENV["RUBYOPT"]  = "-r#{file} #{ENV["RUBYOPT"]}"

  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/builder-2.1.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/builder-2.1.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/activesupport-2.3.5/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/activesupport-2.3.5/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json-1.2.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json-1.2.0/ext/json/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json-1.2.0/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json-1.2.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json_pure-1.2.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/json_pure-1.2.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-mnemo-1.1.1/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-mnemo-1.1.1/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-scheduler-2.0.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-scheduler-2.0.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sexp_processor-3.0.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sexp_processor-3.0.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/SyslogLogger-1.4.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/SyslogLogger-1.4.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/trollop-1.15/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/trollop-1.15/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-lru-1.0.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-lru-1.0.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-verbs-0.10/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-verbs-0.10/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/god-0.8.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/god-0.8.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/god-0.8.0/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mysqlplus-0.1.1/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mysqlplus-0.1.1/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rcov-0.9.6/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rcov-0.9.6/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/eventmachine-0.12.10/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/eventmachine-0.12.10/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/daemon-kit-0.1.7.12/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/daemon-kit-0.1.7.12/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruby_parser-2.0.4/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruby_parser-2.0.4/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/amqp-0.6.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/amqp-0.6.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruby-hmac-0.3.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruby-hmac-0.3.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/crack-0.1.4/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/crack-0.1.4/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-treechecker-1.0.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-treechecker-1.0.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/hashie-0.1.5/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/hashie-0.1.5/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rubyforge-2.0.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rubyforge-2.0.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/haml-2.0.10/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/haml-2.0.10/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rake-0.8.7/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rake-0.8.7/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/hoe-2.4.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/hoe-2.4.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rdoc-2.3.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rdoc-2.3.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rubigen-1.5.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rubigen-1.5.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mislav-hanna-0.1.11/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mislav-hanna-0.1.11/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/oauth-0.3.6/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/oauth-0.3.6/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/httparty-0.4.5/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/httparty-0.4.5/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/twitter-0.7.9/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/twitter-0.7.9/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-dollar-1.0.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rufus-dollar-1.0.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/nokogiri-1.4.1/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/nokogiri-1.4.1/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/nokogiri-1.4.1/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mdalessio-dryopteris-0.1.2/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mdalessio-dryopteris-0.1.2/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mime-types-1.16/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/mime-types-1.16/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/pauldix-sax-machine-0.0.14/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/pauldix-sax-machine-0.0.14/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruote-0.9.21/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruote-0.9.21/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/simianarmy-ruote-amqp-0.9.21/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/simianarmy-ruote-amqp-0.9.21/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sequel-3.3.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sequel-3.3.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/SystemTimer-1.1.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/SystemTimer-1.1.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/moomerman-twitter_oauth-0.2.1/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/moomerman-twitter_oauth-0.2.1/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruote-external-workitem-0.1.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/ruote-external-workitem-0.1.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sqlite3-ruby-1.2.5/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sqlite3-ruby-1.2.5/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/sqlite3-ruby-1.2.5/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/highline-1.5.1/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/highline-1.5.1/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rgrove-larch-1.0.2.3/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/rgrove-larch-1.0.2.3/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/taf2-curb-0.5.4.0/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/taf2-curb-0.5.4.0/lib")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/taf2-curb-0.5.4.0/ext")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/pauldix-feedzirra-0.0.18/bin")
  $LOAD_PATH.unshift File.expand_path("#{dir}/gems/pauldix-feedzirra-0.0.18/lib")

  @gemfile = "#{dir}/../../Gemfile"

  require "rubygems"

  @bundled_specs = {}
  @bundled_specs["builder"] = eval(File.read("#{dir}/specifications/builder-2.1.2.gemspec"))
  @bundled_specs["builder"].loaded_from = "#{dir}/specifications/builder-2.1.2.gemspec"
  @bundled_specs["activesupport"] = eval(File.read("#{dir}/specifications/activesupport-2.3.5.gemspec"))
  @bundled_specs["activesupport"].loaded_from = "#{dir}/specifications/activesupport-2.3.5.gemspec"
  @bundled_specs["json"] = eval(File.read("#{dir}/specifications/json-1.2.0.gemspec"))
  @bundled_specs["json"].loaded_from = "#{dir}/specifications/json-1.2.0.gemspec"
  @bundled_specs["json_pure"] = eval(File.read("#{dir}/specifications/json_pure-1.2.0.gemspec"))
  @bundled_specs["json_pure"].loaded_from = "#{dir}/specifications/json_pure-1.2.0.gemspec"
  @bundled_specs["rufus-mnemo"] = eval(File.read("#{dir}/specifications/rufus-mnemo-1.1.1.gemspec"))
  @bundled_specs["rufus-mnemo"].loaded_from = "#{dir}/specifications/rufus-mnemo-1.1.1.gemspec"
  @bundled_specs["rufus-scheduler"] = eval(File.read("#{dir}/specifications/rufus-scheduler-2.0.3.gemspec"))
  @bundled_specs["rufus-scheduler"].loaded_from = "#{dir}/specifications/rufus-scheduler-2.0.3.gemspec"
  @bundled_specs["sexp_processor"] = eval(File.read("#{dir}/specifications/sexp_processor-3.0.3.gemspec"))
  @bundled_specs["sexp_processor"].loaded_from = "#{dir}/specifications/sexp_processor-3.0.3.gemspec"
  @bundled_specs["SyslogLogger"] = eval(File.read("#{dir}/specifications/SyslogLogger-1.4.0.gemspec"))
  @bundled_specs["SyslogLogger"].loaded_from = "#{dir}/specifications/SyslogLogger-1.4.0.gemspec"
  @bundled_specs["trollop"] = eval(File.read("#{dir}/specifications/trollop-1.15.gemspec"))
  @bundled_specs["trollop"].loaded_from = "#{dir}/specifications/trollop-1.15.gemspec"
  @bundled_specs["rufus-lru"] = eval(File.read("#{dir}/specifications/rufus-lru-1.0.2.gemspec"))
  @bundled_specs["rufus-lru"].loaded_from = "#{dir}/specifications/rufus-lru-1.0.2.gemspec"
  @bundled_specs["rufus-verbs"] = eval(File.read("#{dir}/specifications/rufus-verbs-0.10.gemspec"))
  @bundled_specs["rufus-verbs"].loaded_from = "#{dir}/specifications/rufus-verbs-0.10.gemspec"
  @bundled_specs["god"] = eval(File.read("#{dir}/specifications/god-0.8.0.gemspec"))
  @bundled_specs["god"].loaded_from = "#{dir}/specifications/god-0.8.0.gemspec"
  @bundled_specs["mysqlplus"] = eval(File.read("#{dir}/specifications/mysqlplus-0.1.1.gemspec"))
  @bundled_specs["mysqlplus"].loaded_from = "#{dir}/specifications/mysqlplus-0.1.1.gemspec"
  @bundled_specs["rcov"] = eval(File.read("#{dir}/specifications/rcov-0.9.6.gemspec"))
  @bundled_specs["rcov"].loaded_from = "#{dir}/specifications/rcov-0.9.6.gemspec"
  @bundled_specs["eventmachine"] = eval(File.read("#{dir}/specifications/eventmachine-0.12.10.gemspec"))
  @bundled_specs["eventmachine"].loaded_from = "#{dir}/specifications/eventmachine-0.12.10.gemspec"
  @bundled_specs["daemon-kit"] = eval(File.read("#{dir}/specifications/daemon-kit-0.1.7.12.gemspec"))
  @bundled_specs["daemon-kit"].loaded_from = "#{dir}/specifications/daemon-kit-0.1.7.12.gemspec"
  @bundled_specs["ruby_parser"] = eval(File.read("#{dir}/specifications/ruby_parser-2.0.4.gemspec"))
  @bundled_specs["ruby_parser"].loaded_from = "#{dir}/specifications/ruby_parser-2.0.4.gemspec"
  @bundled_specs["amqp"] = eval(File.read("#{dir}/specifications/amqp-0.6.0.gemspec"))
  @bundled_specs["amqp"].loaded_from = "#{dir}/specifications/amqp-0.6.0.gemspec"
  @bundled_specs["ruby-hmac"] = eval(File.read("#{dir}/specifications/ruby-hmac-0.3.2.gemspec"))
  @bundled_specs["ruby-hmac"].loaded_from = "#{dir}/specifications/ruby-hmac-0.3.2.gemspec"
  @bundled_specs["crack"] = eval(File.read("#{dir}/specifications/crack-0.1.4.gemspec"))
  @bundled_specs["crack"].loaded_from = "#{dir}/specifications/crack-0.1.4.gemspec"
  @bundled_specs["rufus-treechecker"] = eval(File.read("#{dir}/specifications/rufus-treechecker-1.0.3.gemspec"))
  @bundled_specs["rufus-treechecker"].loaded_from = "#{dir}/specifications/rufus-treechecker-1.0.3.gemspec"
  @bundled_specs["hashie"] = eval(File.read("#{dir}/specifications/hashie-0.1.5.gemspec"))
  @bundled_specs["hashie"].loaded_from = "#{dir}/specifications/hashie-0.1.5.gemspec"
  @bundled_specs["rubyforge"] = eval(File.read("#{dir}/specifications/rubyforge-2.0.3.gemspec"))
  @bundled_specs["rubyforge"].loaded_from = "#{dir}/specifications/rubyforge-2.0.3.gemspec"
  @bundled_specs["haml"] = eval(File.read("#{dir}/specifications/haml-2.0.10.gemspec"))
  @bundled_specs["haml"].loaded_from = "#{dir}/specifications/haml-2.0.10.gemspec"
  @bundled_specs["rake"] = eval(File.read("#{dir}/specifications/rake-0.8.7.gemspec"))
  @bundled_specs["rake"].loaded_from = "#{dir}/specifications/rake-0.8.7.gemspec"
  @bundled_specs["hoe"] = eval(File.read("#{dir}/specifications/hoe-2.4.0.gemspec"))
  @bundled_specs["hoe"].loaded_from = "#{dir}/specifications/hoe-2.4.0.gemspec"
  @bundled_specs["rdoc"] = eval(File.read("#{dir}/specifications/rdoc-2.3.0.gemspec"))
  @bundled_specs["rdoc"].loaded_from = "#{dir}/specifications/rdoc-2.3.0.gemspec"
  @bundled_specs["rubigen"] = eval(File.read("#{dir}/specifications/rubigen-1.5.2.gemspec"))
  @bundled_specs["rubigen"].loaded_from = "#{dir}/specifications/rubigen-1.5.2.gemspec"
  @bundled_specs["mislav-hanna"] = eval(File.read("#{dir}/specifications/mislav-hanna-0.1.11.gemspec"))
  @bundled_specs["mislav-hanna"].loaded_from = "#{dir}/specifications/mislav-hanna-0.1.11.gemspec"
  @bundled_specs["oauth"] = eval(File.read("#{dir}/specifications/oauth-0.3.6.gemspec"))
  @bundled_specs["oauth"].loaded_from = "#{dir}/specifications/oauth-0.3.6.gemspec"
  @bundled_specs["httparty"] = eval(File.read("#{dir}/specifications/httparty-0.4.5.gemspec"))
  @bundled_specs["httparty"].loaded_from = "#{dir}/specifications/httparty-0.4.5.gemspec"
  @bundled_specs["twitter"] = eval(File.read("#{dir}/specifications/twitter-0.7.9.gemspec"))
  @bundled_specs["twitter"].loaded_from = "#{dir}/specifications/twitter-0.7.9.gemspec"
  @bundled_specs["rufus-dollar"] = eval(File.read("#{dir}/specifications/rufus-dollar-1.0.2.gemspec"))
  @bundled_specs["rufus-dollar"].loaded_from = "#{dir}/specifications/rufus-dollar-1.0.2.gemspec"
  @bundled_specs["nokogiri"] = eval(File.read("#{dir}/specifications/nokogiri-1.4.1.gemspec"))
  @bundled_specs["nokogiri"].loaded_from = "#{dir}/specifications/nokogiri-1.4.1.gemspec"
  @bundled_specs["mdalessio-dryopteris"] = eval(File.read("#{dir}/specifications/mdalessio-dryopteris-0.1.2.gemspec"))
  @bundled_specs["mdalessio-dryopteris"].loaded_from = "#{dir}/specifications/mdalessio-dryopteris-0.1.2.gemspec"
  @bundled_specs["mime-types"] = eval(File.read("#{dir}/specifications/mime-types-1.16.gemspec"))
  @bundled_specs["mime-types"].loaded_from = "#{dir}/specifications/mime-types-1.16.gemspec"
  @bundled_specs["pauldix-sax-machine"] = eval(File.read("#{dir}/specifications/pauldix-sax-machine-0.0.14.gemspec"))
  @bundled_specs["pauldix-sax-machine"].loaded_from = "#{dir}/specifications/pauldix-sax-machine-0.0.14.gemspec"
  @bundled_specs["ruote"] = eval(File.read("#{dir}/specifications/ruote-0.9.21.gemspec"))
  @bundled_specs["ruote"].loaded_from = "#{dir}/specifications/ruote-0.9.21.gemspec"
  @bundled_specs["simianarmy-ruote-amqp"] = eval(File.read("#{dir}/specifications/simianarmy-ruote-amqp-0.9.21.gemspec"))
  @bundled_specs["simianarmy-ruote-amqp"].loaded_from = "#{dir}/specifications/simianarmy-ruote-amqp-0.9.21.gemspec"
  @bundled_specs["sequel"] = eval(File.read("#{dir}/specifications/sequel-3.3.0.gemspec"))
  @bundled_specs["sequel"].loaded_from = "#{dir}/specifications/sequel-3.3.0.gemspec"
  @bundled_specs["SystemTimer"] = eval(File.read("#{dir}/specifications/SystemTimer-1.1.3.gemspec"))
  @bundled_specs["SystemTimer"].loaded_from = "#{dir}/specifications/SystemTimer-1.1.3.gemspec"
  @bundled_specs["moomerman-twitter_oauth"] = eval(File.read("#{dir}/specifications/moomerman-twitter_oauth-0.2.1.gemspec"))
  @bundled_specs["moomerman-twitter_oauth"].loaded_from = "#{dir}/specifications/moomerman-twitter_oauth-0.2.1.gemspec"
  @bundled_specs["ruote-external-workitem"] = eval(File.read("#{dir}/specifications/ruote-external-workitem-0.1.0.gemspec"))
  @bundled_specs["ruote-external-workitem"].loaded_from = "#{dir}/specifications/ruote-external-workitem-0.1.0.gemspec"
  @bundled_specs["sqlite3-ruby"] = eval(File.read("#{dir}/specifications/sqlite3-ruby-1.2.5.gemspec"))
  @bundled_specs["sqlite3-ruby"].loaded_from = "#{dir}/specifications/sqlite3-ruby-1.2.5.gemspec"
  @bundled_specs["highline"] = eval(File.read("#{dir}/specifications/highline-1.5.1.gemspec"))
  @bundled_specs["highline"].loaded_from = "#{dir}/specifications/highline-1.5.1.gemspec"
  @bundled_specs["rgrove-larch"] = eval(File.read("#{dir}/specifications/rgrove-larch-1.0.2.3.gemspec"))
  @bundled_specs["rgrove-larch"].loaded_from = "#{dir}/specifications/rgrove-larch-1.0.2.3.gemspec"
  @bundled_specs["taf2-curb"] = eval(File.read("#{dir}/specifications/taf2-curb-0.5.4.0.gemspec"))
  @bundled_specs["taf2-curb"].loaded_from = "#{dir}/specifications/taf2-curb-0.5.4.0.gemspec"
  @bundled_specs["pauldix-feedzirra"] = eval(File.read("#{dir}/specifications/pauldix-feedzirra-0.0.18.gemspec"))
  @bundled_specs["pauldix-feedzirra"].loaded_from = "#{dir}/specifications/pauldix-feedzirra-0.0.18.gemspec"

  def self.add_specs_to_loaded_specs
    Gem.loaded_specs.merge! @bundled_specs
  end

  def self.add_specs_to_index
    @bundled_specs.each do |name, spec|
      Gem.source_index.add_spec spec
    end
  end

  add_specs_to_loaded_specs
  add_specs_to_index

  def self.require_env(env = nil)
    context = Class.new do
      def initialize(env) @env = env && env.to_s ; end
      def method_missing(*) ; yield if block_given? ; end
      def only(*env)
        old, @only = @only, _combine_only(env.flatten)
        yield
        @only = old
      end
      def except(*env)
        old, @except = @except, _combine_except(env.flatten)
        yield
        @except = old
      end
      def gem(name, *args)
        opt = args.last.is_a?(Hash) ? args.pop : {}
        only = _combine_only(opt[:only] || opt["only"])
        except = _combine_except(opt[:except] || opt["except"])
        files = opt[:require_as] || opt["require_as"] || name
        files = [files] unless files.respond_to?(:each)

        return unless !only || only.any? {|e| e == @env }
        return if except && except.any? {|e| e == @env }

        if files = opt[:require_as] || opt["require_as"]
          files = Array(files)
          files.each { |f| require f }
        else
          begin
            require name
          rescue LoadError
            # Do nothing
          end
        end
        yield if block_given?
        true
      end
      private
      def _combine_only(only)
        return @only unless only
        only = [only].flatten.compact.uniq.map { |o| o.to_s }
        only &= @only if @only
        only
      end
      def _combine_except(except)
        return @except unless except
        except = [except].flatten.compact.uniq.map { |o| o.to_s }
        except |= @except if @except
        except
      end
    end
    context.new(env && env.to_s).instance_eval(File.read(@gemfile), @gemfile, 1)
  end
end

module Gem
  @loaded_stacks = Hash.new { |h,k| h[k] = [] }

  def source_index.refresh!
    super
    Bundler.add_specs_to_index
  end
end
