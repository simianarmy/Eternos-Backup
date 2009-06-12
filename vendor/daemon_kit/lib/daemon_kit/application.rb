require 'timeout'

module DaemonKit

  # Class responsible for making the daemons run and keep them running.
  class Application

    class << self

      # Run the specified file as a daemon process.
      def exec( file )
        raise DaemonNotFound.new( file ) unless File.exist?( file )

        DaemonKit.configuration.daemon_name ||= File.basename( file )

        command, configs, args = Arguments.parse( ARGV )

        case command
        when :run
          parse_arguments( args )
          run( file )
        when :start
          parse_arguments( args )
          start( file )
        when :stop
          stop
        end
      end

      # Run the daemon in the foreground without daemonizing
      def run( file )
        self.chroot
        self.clean_fd
        self.redirect_io( true )

        DaemonKit.configuration.log_stdout = true

        require file
      end

      # Run our file properly
      def start( file )
        self.daemonize
        self.chroot
        self.clean_fd
        self.redirect_io

        require file
      end

      def stop
        @pid_file = PidFile.new( DaemonKit.configuration.pid_file )

        unless @pid_file.running?
          @pid_file.cleanup
          puts "Nothing to stop"
          exit
        end

        target_pid = @pid_file.pid

        puts "Sending TERM to #{target_pid}"
        Process.kill( 'TERM', target_pid )

        if seconds = DaemonKit.configuration.force_kill_wait
          begin
            Timeout::timeout( seconds ) do
              loop do
                puts "Waiting #{seconds} seconds for #{target_pid} before sending KILL"

                break unless @pid_file.running?

                seconds -= 1
                sleep 1
              end
            end
          rescue Timeout::Error
            Process.kill( 'KILL', target_pid )
          end
        end

        @pid_file.cleanup
      end

      # Call this from inside a daemonized process to complete the
      # initialization process
      def running!
        Initializer.continue!

        yield DaemonKit.configuration if block_given?
      end

      # Exit the daemon
      # TODO: Make configurable callback chain
      # TODO: Hook into at_exit()
      def exit!( code = 0 )
      end

      protected

      def parse_arguments( args )
        DaemonKit.arguments = Arguments.new
        DaemonKit.arguments.parse( args )
      end

      # Daemonize the process
      def daemonize
        @pid_file = PidFile.new( DaemonKit.configuration.pid_file )
        @pid_file.ensure_stopped!

        if RUBY_VERSION < "1.9"
          exit if fork
          Process.setsid
          exit if fork
        else
          Process.daemon( true, true )
        end

        @pid_file.write!

        # TODO: Convert into shutdown hook
        at_exit { @pid_file.cleanup }
      end

      # Release the old working directory and insure a sensible umask
      # TODO: Make chroot directory configurable
      def chroot
        Dir.chdir '/'
        File.umask 0000
      end

      # Make sure all file descriptors are closed (with the exception
      # of STDIN, STDOUT & STDERR)
      def clean_fd
        ObjectSpace.each_object(IO) do |io|
          unless [STDIN, STDOUT, STDERR].include?(io)
            begin
              unless io.closed?
                io.close
              end
            rescue ::Exception
            end
          end
        end
      end

      # Redirect our IO
      # TODO: make this configurable
      def redirect_io( simulate = false )
        begin
          STDIN.reopen '/dev/null'
        rescue ::Exception
        end

        unless simulate
          STDOUT.reopen '/dev/null', 'a'
          STDERR.reopen '/dev/null', 'a'
        end
      end
    end

  end
end
