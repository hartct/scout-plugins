require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../apache_analyzer.rb', __FILE__)


class ApacheAnalyzerTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("overview_with_alerts")
    @last_request_time = "11/Apr/2010 #{17+Time.now.utc_offset/60/60}:22:04" # applies UTC offset
    @duration_format = '%h %l %u %t "%r" %>s %b %D'
    @utc_log = File.dirname(__FILE__)+"/utc.log"
  end
  
  def test_initial_run_with_utc
    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(nil,{},{:log => @utc_log, :format => @duration_format})
      res = plugin.run()
      assert_equal 68, res[:reports].first[:lines_scanned]
      assert_in_delta 67.96, res[:reports].first[:request_rate].to_f, 1
      assert_equal 0.36.to_s, res[:reports].first[:average_request_length]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  def test_run_with_unrecognized_line
    log = File.dirname(__FILE__)+"/unrecognized_line.log"
    time = Time.parse(@last_request_time) 
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(nil,{},{:log => log, :format => @duration_format})
      res = plugin.run()
      assert_equal 3, res[:reports].first[:lines_scanned]
      assert_equal 0.06.to_s, res[:reports].first[:average_request_length]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  def test_later_run_with_utc
    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    # pretend a run a couple of minutes earlier
    memory = {:last_request_time => Time.parse("Sun Apr 11 17:20:19 -0700 2010")}
    memory[:last_summary_time] = memory[:last_request_time]
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(time,memory,{:log => @utc_log, :format => @duration_format})
      res = plugin.run()
      assert_equal 21, res[:reports].first[:lines_scanned]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  # Test handling of a format edge-case. The format we suggest is enclosed in double quotes in 
  # Apache config. However, options passed down to Scout have single quotes. If the Apache config 
  # format (double-quoted) is used, parsing will not work. This handles that case. 
  def test_should_work_with_escaped_r
    format = '%h %l %u %t \"%r\" %>s %b %D'

    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(nil,{},{:log => @utc_log, :format => format})
      res = plugin.run()
      assert_equal 68, res[:reports].first[:lines_scanned]
      assert_in_delta 67.96, res[:reports].first[:request_rate].to_f, 0.10
      assert_equal 0.36, res[:reports].first[:average_request_length].to_f
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  def test_run_with_common_format
    format = 'common'

    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(nil,{},{:log => @utc_log, :format => format})
      res = plugin.run()
      assert_equal 68, res[:reports].first[:lines_scanned]
      assert_nil res[:reports].first[:average_request_length]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  def test_format_scanning
    format = '%h %l %u %t \"%r\" %>s %b %D'
    
    plugin=ApacheAnalyzer.new(nil,{},{:log => @utc_log, :format => format})
    assert_equal '%h %l %u %t "%r" %>s %b %D', plugin.scan_format
  end
  
end