begin
  
rescue LoadError
  $stderr.puts "Missing amqp gem. Please run 'gem install amqp'."
  exit 1
end
