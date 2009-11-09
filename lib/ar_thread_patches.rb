# $Id$

# ActiveRecord & MySQL monkey-patches to avoid deadlocks and other issues when using threads
# All from http://coderrr.wordpress.com/2009/01/08/activerecord-threading-issues-and-resolutions/

# For mysqlplus 
class Mysql
  alias_method :query, :c_async_query
end

# For catching 'server has gone away' & reconnecting
module ActiveRecord::ConnectionAdapters
  class MysqlAdapter
    alias_method :execute_without_retry, :execute
    def execute(*args)      
      execute_without_retry(*args)
    rescue ActiveRecord::StatementInvalid
      if $!.message =~ /server has gone away/i
        warn "Server timed out, retrying"
        reconnect!
        retry
      end

      raise
    end
  end
  
  # [PATCH] modified with_connection to release connection after block finishes if no previous connection existed
  # from http://s3.amazonaws.com/activereload-lighthouse/assets/0d6878b2888d2473e0a0e942652ca97392c71204/with_connection.diff?AWSAccessKeyId=1AJ9W2TX1B2Z7C2KYB82&Expires=1257792838&Signature=kC7CyJYRVR6ncaf1dTjkkbddu%2BQ%3D
  class ConnectionPool
    # Reserve a connection, and yield it to a block. Ensure the connection is
    # checked back in when finished.
    # If a connection already exists yield it to the block.  If no connection
    # exists checkout a connection, yield it to the block, and checkin the 
    # connection when finished.
    def with_connection
      fresh_connection = true unless @reserved_connections[current_connection_id]
      yield connection
    ensure
      release_connection if fresh_connection
    end
  end
end

# module 
# class << Thread
#   alias orig_new new
#   def new
#     orig_new do
#       begin
#         yield
#       ensure
#         ActiveRecord::Base.connection_pool.release_connection
#       end
#     end
#   end
# end
