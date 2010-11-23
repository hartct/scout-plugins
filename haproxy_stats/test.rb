require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../haproxy_stats.rb', __FILE__)

require 'open-uri'
class HaProxyTest < Test::Unit::TestCase

  def teardown
    FakeWeb.clean_registry
  end

  def test_normal_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    uri='http://fake' # output comes from http://demo.1wt.eu/;csv
    FakeWeb.register_uri(:get, uri, :body => FIXTURES[:valid])
    @plugin=HaproxyStats.new(nil,{},{:uri=>uri})
    res = @plugin.run()
    assert_valid_report(res)
  end

  def test_invalid_csv
    uri='http://fake'
    FakeWeb.register_uri(:get, uri, :body => FIXTURES[:invalid])
    @plugin=HaproxyStats.new(nil,{},{:uri=>uri})

    res = @plugin.run()
    assert_equal 0, res[:reports].size
    assert_equal 1, res[:errors].size
    assert_equal "Error accessing stats page", res[:errors].first[:subject]
  end
  
  def test_blank_uri
    @plugin=HaproxyStats.new(nil,{},{:uri=>nil})

    res = @plugin.run()
    assert_equal 0, res[:reports].size
    assert_equal 1, res[:errors].size
    assert_equal "URI to HAProxy Stats Required", res[:errors].first[:subject]
  end
  
  def test_invalid_basic_auth
    uri_invalid_auth = "http://user:invalid@example.com/secret"
    FakeWeb.register_uri(:get, uri_invalid_auth, :body => "Unauthorized", :status => ["401", "Unauthorized"])

    @plugin=HaproxyStats.new(nil,{},{:uri=>uri_invalid_auth, :user => 'user', :password => 'invalid'})
    assert_raises OpenURI::HTTPError do
      res = @plugin.run()
    end
  end
  
  def test_valid_basic_auth
    uri_no_auth = "http://example.com/secret"
    uri = "http://user:pass@example.com/secret"
    FakeWeb.register_uri(:get, uri_no_auth, :body => "Unauthorized", :status => ["401", "Unauthorized"])
    FakeWeb.register_uri(:get, uri, :body => FIXTURES[:valid])
    
    @plugin=HaproxyStats.new(nil,{},{:uri=>uri_no_auth, :user => 'user', :password => 'pass'})
    res = @plugin.run()
    assert_valid_report(res)
  end
  
  ### helper methods
  
  def assert_valid_report(res)
    assert_equal [{"http-in frontend Current Sessions"=>"1"},
                  {"http-in frontend Requests / second"=>"1"},
                  {"www backend Current Sessions"=>"0"},
                  {"www backend Current Queue"=>"0"},
                  {"www backend Requests / second"=>"0"},
                  {"git backend Current Sessions"=>"0"},
                  {"git backend Current Queue"=>"0"},
                  {"git backend Requests / second"=>"0"},
                  {"demo backend Current Sessions"=>"1"},
                  {"demo backend Current Queue"=>"0"},
                  {"demo backend Requests / second"=>"1"}], res[:reports]
  end

  FIXTURES=YAML.load(<<-EOS)
    :valid: |
      # pxname,svname,qcur,qmax,scur,smax,slim,stot,bin,bout,dreq,dresp,ereq,econ,eresp,wretr,wredis,status,weight,act,bck,chkfail,chkdown,lastchg,downtime,qlimit,pid,iid,sid,throttle,lbtot,tracked,type,rate,rate_lim,rate_max,check_status,check_code,check_duration,hrsp_1xx,hrsp_2xx,hrsp_3xx,hrsp_4xx,hrsp_5xx,hrsp_other,hanafail,req_rate,req_rate_max,req_tot,cli_abrt,srv_abrt,
      http-in,FRONTEND,,,1,34,100,329625,104912702,9082767400,0,0,436,,,,,OPEN,,,,,,,,,1,1,0,,,,0,1,0,26,,,,0,320967,20890,9724,300,0,,1,32,351882,,,
      http-in,IPv4-direct,,,1,27,100,41837,21004375,739334057,0,0,423,,,,,OPEN,,,,,,,,,1,1,1,,,,3,,,,,,,,,,,,,,,,,,,
      http-in,IPv4-cached,,,0,32,100,286965,83724634,8336734700,0,0,3,,,,,OPEN,,,,,,,,,1,1,2,,,,3,,,,,,,,,,,,,,,,,,,
      http-in,IPv6-direct,,,0,4,100,823,183693,6698643,0,0,10,,,,,OPEN,,,,,,,,,1,1,3,,,,3,,,,,,,,,,,,,,,,,,,
      http-in,local,,,0,0,100,0,0,0,0,0,0,,,,,OPEN,,,,,,,,,1,1,4,,,,3,,,,,,,,,,,,,,,,,,,
      www,www,0,0,0,10,10,226818,88575426,8853553673,,0,,0,6,0,0,UP,1,1,0,0,0,1729584,0,,1,2,1,,226782,,2,0,,32,L7OK,200,3,0,198059,20422,8328,0,0,0,,,,4295,5,
      www,bck,0,0,0,0,10,0,0,0,,0,,0,0,0,0,UP,1,0,1,0,0,1729584,0,,1,2,2,,0,,2,0,,0,L7OK,200,2,0,0,0,0,0,0,0,,,,0,0,
      www,BACKEND,0,7,0,18,100,226837,88592903,8853557341,0,0,,4,6,0,0,UP,1,1,1,,0,1729584,0,,1,2,0,,226782,,1,0,,32,,,,0,198059,20422,8343,13,0,,,,,4296,5,
      git,www,0,0,0,2,2,4400,1368928,130726732,,0,,0,0,0,0,UP,1,1,0,0,0,1729584,0,,1,3,1,,3050,,2,0,,2,L7OK,200,3,0,3875,468,57,0,0,0,,,,545,0,
      git,bck,0,0,0,0,2,0,0,0,,0,,0,0,0,0,UP,1,0,1,0,0,1729584,0,,1,3,2,,0,,2,0,,0,L7OK,200,2,0,0,0,0,0,0,0,,,,0,0,
      git,BACKEND,0,30,0,32,2,4664,1784466,130782700,0,0,,264,0,0,0,UP,1,1,1,,0,1729584,0,,1,3,0,,3050,,1,0,,11,,,,0,3875,468,57,264,0,,,,,621,0,
      demo,BACKEND,0,0,1,7,0,5188,1885693,80518954,0,0,,0,0,0,0,UP,0,0,0,,0,1729584,0,,1,15,0,,0,,1,1,,5,,,,0,5187,0,0,0,0,,,,,787,0,
    :invalid: |
      "# pxname,"svname,qcur,qmax,scur,smax,slim,stot,bin,bout,dreq,dresp,ereq,econ,eresp,wretr,wredis,status,weight,act,bck,chkfail,chkdown,lastchg,downtime,qlimit,pid,iid,sid,throttle,lbtot,tracked,type,rate,rate_lim,rate_max,check_status,check_code,check_duration,hrsp_1xx,hrsp_2xx,hrsp_3xx,hrsp_4xx,hrsp_5xx,hrsp_other,hanafail,req_rate,req_rate_max,req_tot,cli_abrt,srv_abrt,
      http-in,
  EOS
end