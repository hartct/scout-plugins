require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../overview_with_alerts.rb', __FILE__)



class OverviewWithAlertsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("overview_with_alerts")
  end

  def teardown
  end

  def test_clean_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()

    # assertions
    assert res[:alerts].empty?
    assert res[:errors].empty?
    assert_equal 1,  res[:reports].size
  end

  def test_memory_alert
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()
    assert_equal 1, res[:alerts].size
    assert_equal "Memory Usage Alert", res[:alerts].first[:subject]

    @memory=res[:memory] # to be used in tests that run this as a precursor
  end

  def test_memory_alert_repeats
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*60*13) do # 13 hours in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res = @plugin.run()
      assert_equal 1, res[:alerts].size
      assert res[:alerts].first[:body].include?("Duration")

      # This nested block tests that a second violation after the first alert (but not yet time for another notification)
      second_run_memory=res[:memory]
      last_run=Time.now
      Timecop.travel(Time.now+60*1) do # another 1 minute in the future
        @plugin=OverviewWithAlerts.new(last_run,second_run_memory,@options)
        @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
        @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
        @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once

        res= @plugin.run()
        assert_equal 0, res[:alerts].size

        # This nested block tests that another violation after the notification period sends another alert
        third_run_memory=res[:memory]
        last_run=Time.now
        Timecop.travel(Time.now+60*60*13) do # another 13 hours in the future
          @plugin=OverviewWithAlerts.new(last_run,third_run_memory,@options)
          @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
          @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
          @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once

          res= @plugin.run()
          assert_equal 1, res[:alerts].size
        end
      end
    end
  end

  def test_memory_alert_does_not_repeat_too_soon
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 0, res[:alerts].size
    end
  end

  def test_memory_back_to_normal
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 1, res[:alerts].size
      assert_equal "Memory Usage OK", res[:alerts].first[:subject]
    end
  end

  def test_disk_alert
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()
    assert_equal 1, res[:alerts].size
    assert_equal "Disk Usage Alert", res[:alerts].first[:subject]

    @memory=res[:memory] # to be used in tests that run this as a precursor
  end

  def test_disk_alert_repeats
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*60*13) do # 13 hours in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res = @plugin.run()
      assert_equal 1, res[:alerts].size
      assert res[:alerts].first[:body].include?("Duration")

      # This nested block tests that a second violation after the first alert (but not yet time for another notification)
      second_run_memory=res[:memory]
      last_run=Time.now
      Timecop.travel(Time.now+60*1) do # another 1 minute in the future
        @plugin=OverviewWithAlerts.new(last_run,second_run_memory,@options)
        @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
        @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
        @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once

        res= @plugin.run()
        assert_equal 0, res[:alerts].size

        # This nested block tests that another violation after the notification period sends another alert
        third_run_memory=res[:memory]
        last_run=Time.now
        Timecop.travel(Time.now+60*60*13) do # another 13 hours in the future
          @plugin=OverviewWithAlerts.new(last_run,third_run_memory,@options)
          @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
          @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
          @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once

          res= @plugin.run()
          assert_equal 1, res[:alerts].size
        end
      end
    end
  end

  def test_disk_alert_does_not_repeat_too_soon
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*15) do # 15 minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 0, res[:alerts].size
    end
  end

  def test_disk_back_to_normal
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 1, res[:alerts].size
      assert_equal "Disk Usage OK", res[:alerts].first[:subject]
    end
  end

  def test_vps
    File.stubs(:exist?).with('/proc/user_beancounters').returns(true).once
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("sudo cat /proc/user_beancounters").returns(FIXTURES[:beancounters]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()
    assert_equal 512, res[:reports].first[:mem_total]
    assert_equal 47, res[:reports].first[:mem_used]
    assert_equal 0, res[:reports].first[:mem_swap_total]
    assert_equal 0, res[:reports].first[:mem_swap_used]
    assert_equal 0, res[:reports].first[:mem_swap_percent]        
    assert_equal 0, res[:alerts].size

  end

  def test_vps_host
    File.stubs(:exist?).with('/proc/user_beancounters').returns(true).once
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("sudo cat /proc/user_beancounters").returns(FIXTURES[:beancounters_host]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()

    assert_equal 1024, res[:reports].first[:mem_total]
    assert_equal 421, res[:reports].first[:mem_used]

    assert_equal 0, res[:alerts].size
  end

  FIXTURES=YAML.load(<<-EOS)
    :meminfo: |
      MemTotal:      1048796 kB
      MemFree:        220928 kB
      Buffers:        105780 kB
      Cached:         291456 kB
      SwapCached:      43864 kB
      Active:         422088 kB
      Inactive:       304300 kB
      SwapTotal:     2097144 kB
      SwapFree:      2029200 kB
      Dirty:             148 kB
      Writeback:           0 kB
      AnonPages:      328480 kB
      Mapped:          13732 kB
      Slab:            59796 kB
      SReclaimable:     9748 kB
      SUnreclaim:      50048 kB
      PageTables:       5244 kB
      NFS_Unstable:        0 kB
      Bounce:              0 kB
      CommitLimit:   2621540 kB
      Committed_AS:  1209676 kB
      VmallocTotal: 34359738367 kB
      VmallocUsed:      1220 kB
      VmallocChunk: 34359737147 kB
    :meminfo_alert: |
      MemTotal:       708796 kB
      MemFree:          2000 kB
      Buffers:             0 kB
      Cached:              0 kB
      SwapCached:      43864 kB
      Active:         422088 kB
      Inactive:       304300 kB
      SwapTotal:           0 kB
      SwapFree:            0 kB
      Dirty:             148 kB
      Writeback:           0 kB
      AnonPages:      328480 kB
      Mapped:          13732 kB
      Slab:            59796 kB
      SReclaimable:     9748 kB
      SUnreclaim:      50048 kB
      PageTables:       5244 kB
      NFS_Unstable:        0 kB
      Bounce:              0 kB
      CommitLimit:   2621540 kB
      Committed_AS:  1209676 kB
      VmallocTotal: 34359738367 kB
      VmallocUsed:      1220 kB
      VmallocChunk: 34359737147 kB
    :df: |
      Filesystem            Size  Used Avail Use% Mounted on
      /dev/sda1              38G   14G   22G  39% /
      varrun                513M   48K  513M   1% /var/run
      varlock               513M     0  513M   0% /var/lock
      udev                  513M   16K  513M   1% /dev
      devshm                513M     0  513M   0% /dev/shm
    :df_alert: |
      Filesystem            Size  Used Avail Use% Mounted on
      /dev/sda1              38G   34G    4G  90% /
      varrun                513M   48K  513M   1% /var/run
      varlock               513M     0  513M   0% /var/lock
      udev                  513M   16K  513M   1% /dev
      devshm                513M     0  513M   0% /dev/shm
    :uptime: |
      15:36  up 33 days,  3:29, 4 users, load averages: 1.77 0.90 0.64
    :beancounters: |
      Version: 2.5
             uid  resource                     held              maxheld              barrier                limit              failcnt
           9833:  kmemsize                  3318833              4634057             33554432             37748736                    0
                  lockedpages                     0                    0                   32                   32                    0
                  privvmpages                 12032                26321               262144               294912                    0
                  shmpages                      641                 1297                65536                65536                    0
                  dummy                           0                    0                    0                    0                    0
                  numproc                        16                   23                  512                  512                    0
                  physpages                    4626                15124               131072  9223372036854775807                    0
                  vmguarpages                     0                    0               262144  9223372036854775807                    0
                  oomguarpages                 4627                15125               131072  9223372036854775807                    0
                  numtcpsock                      4                    7                  512                  512                    0
                  numflock                        3                    5                  512                  512                    0
                  numpty                          1                    2                   32                   32                    0
                  numsiginfo                      0                    6                  256                  256                    0
                  tcpsndbuf                   69888              1266992              5242880              7864320                    0
                  tcprcvbuf                   65536               291584              5242880              7864320                    0
                  othersockbuf                 9280               284768              1048576              2097152                    0
                  dgramrcvbuf                     0                16928               131072               131072                    0
                  numothersock                   13                   23                  512                  512                    0
                  dcachesize                 282639               307992              1048576              1179648                    0
                  numfile                       618                  943                 5120                 5120                    0
                  dummy                           0                    0                    0                    0                    0
                  dummy                           0                    0                    0                    0                    0
                  dummy                           0                    0                    0                    0                    0
                  numiptent                      14                   14                  128                  128                    0
    :beancounters_host: |
      Version: 2.5
             uid  resource                     held              maxheld              barrier                limit              failcnt
              0:  kmemsize                 29696618             72254634  9223372036854775807  9223372036854775807                    0
                  lockedpages                  5847                 5855  9223372036854775807  9223372036854775807                    0
                  privvmpages                469383               633537  9223372036854775807  9223372036854775807                    0
                  shmpages                      842                 2778  9223372036854775807  9223372036854775807                    0
                  dummy                           0                    0  9223372036854775807  9223372036854775807                    0
                  numproc                       152                  290  9223372036854775807  9223372036854775807                    0
                  physpages                  155069               298835  9223372036854775807  9223372036854775807                    0
                  vmguarpages                     0                    0  9223372036854775807  9223372036854775807                    0
                  oomguarpages               155069               298835  9223372036854775807  9223372036854775807                    0
                  numtcpsock                     13                   98  9223372036854775807  9223372036854775807                    0
                  numflock                        4                   11  9223372036854775807  9223372036854775807                    0
                  numpty                          1                    4  9223372036854775807  9223372036854775807                    0
                  numsiginfo                      1                   27  9223372036854775807  9223372036854775807                    0
                  tcpsndbuf                  227552               764272  9223372036854775807  9223372036854775807                    0
                  tcprcvbuf                  212992               684584  9223372036854775807  9223372036854775807                    0
                  othersockbuf               305912               555576  9223372036854775807  9223372036854775807                    0
                  dgramrcvbuf                     0                18248  9223372036854775807  9223372036854775807                    0
                  numothersock                  237                  428  9223372036854775807  9223372036854775807                    0
                  dcachesize                      0                    0  9223372036854775807  9223372036854775807                    0
                  numfile                      5967                 8144  9223372036854775807  9223372036854775807                    0
                  dummy                           0                    0  9223372036854775807  9223372036854775807                    0
                  dummy                           0                    0  9223372036854775807  9223372036854775807                    0
                  dummy                           0                    0  9223372036854775807  9223372036854775807                    0
                  numiptent                      73                   73  9223372036854775807  9223372036854775807                    0
  EOS

end