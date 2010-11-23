require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../iostat.rb', __FILE__)

class IostatTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
  def test_success
    @plugin=Iostat.new(nil,{},{})
    IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:diskstats_1].split(/\n/)).once
    @plugin.expects(:`).with("mount").returns(FIXTURES[:mount]).once

    res = @plugin.run()
    assert res[:memory].is_a?(Hash), "Plugin memory should be a hash"
    assert_equal 7, res[:memory].keys.size, "Plugin memory has the wrong number of keys"
    assert_equal 0, res[:reports].size, "Plugin shouldn't return any results first run"
    assert_equal 52087575, res[:memory]['_counter_rkbps'][:value]

    Timecop.travel(Time.now+5*60) do # 5 minute later
      new_plugin=Iostat.new(nil,res[:memory],{})
      IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:diskstats_2].split(/\n/)).once
      new_plugin.expects(:`).with("mount").returns(FIXTURES[:mount]).once
      res = new_plugin.run()
      assert_equal 7, res[:reports].size
    end
  end

  FIXTURES=YAML.load(<<-EOS)
    :mount: |
      /dev/xvda1 on / type ext3 (rw,errors=remount-ro)
      proc on /proc type proc (rw,noexec,nosuid,nodev)
      none on /sys type sysfs (rw,noexec,nosuid,nodev)
      none on /sys/fs/fuse/connections type fusectl (rw)
      none on /sys/kernel/debug type debugfs (rw)
      none on /sys/kernel/security type securityfs (rw)
      none on /dev type devtmpfs (rw,mode=0755)
      none on /dev/pts type devpts (rw,noexec,nosuid,gid=5,mode=0620)
      none on /dev/shm type tmpfs (rw,nosuid,nodev)
      none on /var/run type tmpfs (rw,nosuid,mode=0755)
      none on /var/lock type tmpfs (rw,noexec,nosuid,nodev)
      none on /lib/init/rw type tmpfs (rw,nosuid,mode=0755)
      none on /var/lib/ureadahead/debugfs type debugfs (rw,relatime)
    :diskstats_1: |
       202       0 xvda 2291392 15908 104175150 31433830 24833528 8910093 269954008 717602680 0 83774100 749022260
       202       1 xvda1 2241909 9075 103724634 30905340 24794783 8838778 269073520 714244880 0 83625720 745136060
       202       2 xvda2 2 0 4 40 0 0 0 0 0 40 40
       202       5 xvda5 49433 6833 450128 528000 38745 71315 880488 3357800 0 681180 3885710
       202      64 xvde 101 148 804 300 0 0 0 0 0 300 300
       202      65 xvde1 74 148 588 110 0 0 0 0 0 110 110
       202      80 xvdf 53 0 424 220 0 0 0 0 0 220 220
    :diskstats_2: |
       202       0 xvda 2291392 15908 104175150 31433830 24834163 8910233 269960208 717605720 0 83774580 749025300
       202       1 xvda1 2241909 9075 103724634 30905340 24795418 8838918 269079720 714247920 0 83626200 745139100
       202       2 xvda2 2 0 4 40 0 0 0 0 0 40 40
       202       5 xvda5 49433 6833 450128 528000 38745 71315 880488 3357800 0 681180 3885710
       202      64 xvde 101 148 804 300 0 0 0 0 0 300 300
       202      65 xvde1 74 148 588 110 0 0 0 0 0 110 110
       202      80 xvdf 53 0 424 220 0 0 0 0 0 220 220
  EOS
end
