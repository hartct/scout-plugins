class CucumberCi < Scout::Plugin

  needs 'json'
  needs 'md5'

  OPTIONS=<<-EOS
  command:
    name: command
    notes: The command to run that generates cucumber-json output
    default: cucumber -p production
  directory:
    name: directory
    notes: The directory in which to run the above command
    default: /srv/YOURAPP/current
  json_path:
    name: JSON path
    notes: The path the cucumber-json output, relative to the above directory the command is run in 
    default: tmp/cuke.json
  EOS

  def build_report
    old_dir = Dir.pwd
    Dir.chdir(option(:directory)) do
      command = `#{option(:command)} 2>&1`
      remember(:cucumber_output, command)
      raw_json = open(File.join(option(:directory),option(:json_path))).read
      hash = JSON.parse(raw_json)
      report hash['status_counts']
      failing_features = (hash['failing_features'].join("\n") rescue '')
      send_alert_for_unique_content(failing_features)
      send_summary_daily('cucumber', hash['features'].join("\n"))
    end
  end

private

  def send_alert_for_unique_content(content, subject = false)
     return if content == ''
     content_md5 = MD5.new(content).to_s
     unless content_md5 == memory(:content_md5)
       if subject
         alert(subject, content)
       else
         alert(content)
       end 
     end
   ensure
     remember(:content_md5, content_md5)
  end

  def send_summary_daily(command, text)
    run_hour    = 23
    run_minutes = 45
    now = Time.now
    if last_summary = memory(:last_summary_time)
      if now.hour > run_hour       or
        ( now.hour == run_hour     and
          now.min  >= run_minutes ) and
         %w[year mon day].any? { |t| last_summary.send(t) != now.send(t) }
        remember(:last_summary_time, now)
      else
        remember(:last_summary_time, last_summary)
        return
      end
    else # summary hasn't been run yet ... set last summary time to 1 day ago
      last_summary = now - (60 * 60 * 24)
      # remember(:last_summary_time, last_summary)
      # on initial run, save the last summary time as now. otherwise if an error occurs, the 
      # plugin will attempt to create a summary on each run.
      remember(:last_summary_time, now) 
    end
    # make sure we get a full run
    if now - last_summary < 60 * 60 * 22
      last_summary = now - (60 * 60 * 24)
    end
    
    summary(:command => command, :output  => text)
  end

end