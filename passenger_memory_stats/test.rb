require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../passenger_memory_stats.rb', __FILE__)


class PassengerMemoryStatsTest < Test::Unit::TestCase

    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
  def test_normal
    PassengerMemoryStats.any_instance.expects(:`).with("passenger-memory-stats 2>&1").returns(FIXTURES[:valid]).once
    `echo''>/dev/null` # total hack: the plugin checks $? (child process exit status) -- this sets $?
    @plugin=PassengerMemoryStats.new(nil,{},{})
    res = @plugin.run()
    assert_valid_report(res)
  end

  private
  def assert_valid_report(res)
    assert_equal [{"apache_private_total" => "7.6 MB",
                   "apache_processes" => "4",
                   "passenger_processes" => "6",
                   "passenger_vmsize_total" => "636.3 MB",
                   "nginx_vmsize_total" => "0.0 MB",
                   "nginx_processes" => "0",
                   "passenger_private_total" => "214.8 MB",
                   "nginx_private_total" => "0.0 MB",
                   "apache_vmsize_total" => "1083.3 MB"}], res[:reports]
  end


  FIXTURES=YAML.load(<<-EOS)
    :valid: |
      ---------- Apache processes ----------
      PID    PPID   VMSize    Private  Name
      --------------------------------------
      12715  23095  129.9 MB  0.6 MB   /usr/sbin/apache2 -k start
      12731  23095  411.8 MB  3.3 MB   /usr/sbin/apache2 -k start
      12759  23095  411.7 MB  3.2 MB   /usr/sbin/apache2 -k start
      23095  1      129.9 MB  0.5 MB   /usr/sbin/apache2 -k start
      ### Processes: 4
      ### Total private dirty RSS: 7.61 MB


      -------- Nginx processes --------

      ### Processes: 0
      ### Total private dirty RSS: 0.00 MB


      ----- Passenger processes -----
      PID    VMSize    Private  Name
      -------------------------------
      778    128.3 MB  54.1 MB  Rails: /var/www/apps/tempo/current
      6085   125.7 MB  50.0 MB  Passenger ApplicationSpawner: /var/www/apps/wifi/current
      6315   123.5 MB  45.4 MB  Passenger ApplicationSpawner: /var/www/apps/shapewiki/current
      12726  89.8 MB   1.5 MB   /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/ext/apache2/ApplicationPoolServerExecutable 0 /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/bin/passenger-spawn-server  /usr/local/bin/passenger_ruby  /tmp/passenger.23095
      12727  39.2 MB   11.6 MB  Passenger spawn server
      21162  129.8 MB  52.2 MB  Rails: /var/www/apps/wifi/current
      ### Processes: 6
      ### Total private dirty RSS: 214.95 MB
  EOS
end