#
# Provides an overview of basic server health:
#
# * Memory
# * Disk Usage
# * CPU load
#
#
# Options Supported: disk_command, num_processors (leave blank to auto-detect)
#
class OverviewWithAlerts < Scout::Plugin

  OPTIONS=<<-EOS
    disk_command:
      name: df Command
      notes: The command used to display free disk space
      default: "df -h"
    disk_filesystem:
      name: Filesystem
      notes: The filesystem to check usage, if none specified, uses the first listed
      default:
    num_processors:
      name: Number of Processors
      notes: For calculating CPU load. If left blank, autodetects through /proc/cpuinfo
      default: 1
    disk_used_threshold:
      name: Disk Used Threshold
      notes: Alert me when disk used % exceeds this
      default: 85
    memory_used_threshold:
      name: Memory Used Threshold
      notes: "Alert me when memory used + swap used exceeds this"
      default: 95
    minutes_between_notifications:
      notes: Alert emails will be sent out every X minutes while a threshold is exceeded
      default: 720
  EOS

  # memory contants
  UNITS = { "b" => 1,
            "k" => 1024,
            "m" => 1024 * 1024,
            "g" => 1024 * 1024 * 1024 }

  # Disk usage constants -- the Disk Freespace RegEx
  DF_RE = /\A\s*(\S.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*\z/


  def build_report
    reports=Hash.new
    reports.merge!(do_disk_usage())
    reports.merge!(do_cpu_load())
    reports.merge!(do_memory())

    report(reports)
  end



  private

  # ----------------------------------------------------
  # Memory
  def do_memory
    memory_used_threshold=option(:memory_used_threshold).to_i
    minutes_between_notifications=option(:minutes_between_notifications).to_i

    # determine whether to use /proc/meminfo or /proc/user_beancounters
    if File.exist?('/proc/user_beancounters')
      lines=shell('sudo cat /proc/user_beancounters').split(/\n/)
      lines=lines.slice(2,lines.size-1) # discard the first two lines -- they are version and column headings, respectively

      if lines.grep(/^\s*0:/).any? # if a line contains uid=0, this is a VPS host -- use /proc/meminfo instead
        report_data = use_proc_meminfo()
      else
        report_data = {}
        privvmpages    = lines.grep(/privvmpages/).first.split(/\s+/)
        oomguarpages   = lines.grep(/oomguarpages/).first.split(/\s+/)

        # values are in pages. Multiply by 4 to get kb, divide 1024 to get MB
        report_data[:mem_total] = oomguarpages[4].to_i * 4 / 1024
        report_data[:mem_used]  = privvmpages[2].to_i * 4 / 1024
        report_data[:mem_used_percent] = (report_data[:mem_used].to_f / report_data[:mem_total].to_f) * 100.0
        report_data[:mem_swap_total] = 0
        report_data[:mem_swap_used] = 0
        report_data[:mem_swap_percent] = 0
        #report_data[:mem_max_burst] = privvmpages[4].to_i * 4 / 1024
      end
    else
      report_data = use_proc_meminfo()
    end


    # Send memory alert if needed
    mem_exceeded = report_data[:mem_used_percent] >= memory_used_threshold
    if mem_exceeded

      remember(:mem_exceeded_at => Time.now) if !memory(:mem_exceeded_at)

      minutes_since_mem_exceeded = memory(:mem_exceeded_at) ? ((Time.now - memory(:mem_exceeded_at)).to_i / 60) : 0
      minutes_since_mem_notification = ((Time.now - memory(:mem_notification_sent_at)).to_i / 60) if memory(:mem_notification_sent_at)

      if !memory(:mem_notification_sent_at) or (minutes_since_mem_notification >= minutes_between_notifications)
        body="Memory usage has exceeded #{memory_used_threshold}%. Memory: #{report_data[:mem_used]}KB."
        subject="Memory Usage Alert"
        if minutes_since_mem_exceeded > 1 # adjustments if this is a continuation email
          body<< "Duration: #{minutes_since_mem_exceeded} minutes."
          subject = "Memory Usage Alert CONT"
        end
        alert(subject, body)
        remember(:mem_notification_sent_at => Time.now)
      else
        remember(:mem_notification_sent_at => memory(:mem_notification_sent_at)) if memory(:mem_notification_sent_at)
      end

      remember(:mem_exceeded_at => memory(:mem_exceeded_at)) if memory(:mem_exceeded_at)      
    else
      if memory(:mem_exceeded_at)
        alert("Memory Usage OK", "Memory usage is below #{memory_used_threshold}%")
      end
    end

    return report_data
  end


  def use_proc_meminfo
    report_data={}
    mem_info = {}
    shell("cat /proc/meminfo").each_line do |line|
      _, key, value = *line.match(/^(\w+):\s+(\d+)\s/)
      mem_info[key] = value.to_i
    end

    mem_total = mem_info['MemTotal'] / 1024
    mem_free = (mem_info['MemFree'] + mem_info['Buffers'] + mem_info['Cached']) / 1024
    mem_used = mem_total - mem_free

    swap_total = mem_info['SwapTotal'] / 1024
    swap_free = mem_info['SwapFree'] / 1024
    swap_used = swap_total - swap_free

    mem_percent_used = (mem_used + swap_used).to_f/(swap_total + mem_total).to_f*100.0

    report_data[:mem_total] = mem_total
    report_data[:mem_used] = mem_used
    report_data[:mem_used_percent] = mem_percent_used

    report_data[:mem_swap_total] = swap_total
    report_data[:mem_swap_used] = swap_used
    report_data[:mem_swap_percent] = (swap_used / swap_total.to_f * 100).to_i if  swap_total != 0 # not always set!

    return report_data
  end

  #---------------------------------------------------------
  # Disk Usage

  def do_disk_usage
    ENV['lang'] = 'C' # forcing English for parsing
    disk_used_threshold=option(:disk_used_threshold).to_i
    minutes_between_notifications=option(:minutes_between_notifications).to_i
    df_command   = option(:disk_command) || "df -h"
    df_output    = shell(df_command)

    df_lines = []
    parse_file_systems(df_output) { |row| df_lines << row }

    # if the user specified a filesystem use that
    df_line = nil
    if option(:disk_filesystem)
      df_lines.each do |line|
        if line.has_value?(option(:disk_filesystem))
          df_line = line
        end
      end
    end

    # else just use the first line
    df_line ||= df_lines.first

    # remove 'filesystem' and 'mounted on' if present - these don't change.
    df_line.reject! { |name,value| ['filesystem','mounted on'].include?(name.downcase.gsub(/\n/,'')) }

    # capacity on osx = Use% on Linux ... convert anything that isn't size, used, or avail to capacity ... a big assumption?
    assumed_capacity = df_line.find { |name,value| !['size','used','avail'].include?(name.downcase.gsub(/\n/,''))}
    df_line.delete(assumed_capacity.first)
    df_line['capacity'] = percent_used = assumed_capacity.last

    # will be passed at the end to report to Scout
    report_data = Hash.new

    df_line.each do |name, value|
      report_data["disk_#{name.downcase.strip}".to_sym] = clean_value(value)
    end

    if percent_used.to_f > option(:disk_used_threshold).to_f
      remember(:disk_exceeded_at => Time.now) if !memory(:disk_exceeded_at)

      minutes_since_disk_exceeded = memory(:disk_exceeded_at) ? ((Time.now - memory(:disk_exceeded_at)).to_i / 60) : 0
      minutes_since_disk_notification = ((Time.now - memory(:disk_notification_sent_at)).to_i / 60) if memory(:disk_notification_sent_at)

      if !memory(:disk_notification_sent_at) or (minutes_since_disk_notification >= minutes_between_notifications)
        body="Disk usage has exceeded #{disk_used_threshold}%, currently at #{percent_used} "
        body<< "Duration: #{minutes_since_disk_exceeded} minutes." if minutes_since_disk_exceeded > 1
        subject="Disk Usage Alert"
        if minutes_since_disk_exceeded > 1 # adjustments if this is a continuation email
          body<< "Duration: #{minutes_since_disk_exceeded} minutes."
          subject = "Disk Usage Alert CONT"
        end
        alert(subject, body)
        remember(:disk_notification_sent_at => Time.now)
      else
        remember(:disk_notification_sent_at => memory(:disk_notification_sent_at)) if memory(:disk_notification_sent_at)
      end
      remember(:disk_exceeded_at => memory(:disk_exceeded_at)) if memory(:disk_exceeded_at)
      
    else
      if memory(:disk_exceeded_at)
        alert("Disk Usage OK", "Disk usage below #{disk_used_threshold}%, currently at #{percent_used}")
      end
    end

    return report_data
  end


  # Parses the file systems lines according to the Regular Expression
  # DF_RE.
  #
  # normal line ex:
  # /dev/disk0s2   233Gi   55Gi  177Gi    24%    /

  # multi-line ex:
  # /dev/mapper/VolGroup00-LogVol00
  #                        29G   25G  2.5G  92% /
  #
  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers      =   nil

    row = ""
    io.each_line do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6)
      else
        row << line
        if row =~  DF_RE
          fields = $~.captures
          line_handler[headers ? Hash[*headers.zip(fields).flatten] : fields]
          row = ""
        end
      end
    end
  end

  # Ensures disk space metrics are in GB. Metrics that don't contain 'G,M,or K' are just
  # turned into integers.
  def clean_value(value)
    if value =~ /G/i
      value.to_f
    elsif value =~ /M/i
      (value.to_f/1024.to_f).round
    elsif value =~ /K/i
      (value.to_f/1024.to_f/1024.to_f).round
    else
      value.to_f
    end
  end


  #-----------------------------------------------------
  # CPU Load
  def do_cpu_load
    result={}
    begin
      if shell("uptime") =~ /load average(s*): ([\d.]+)(,*) ([\d.]+)(,*) ([\d.]+)\Z/
        result = {:cpu_last_minute          => $2.to_f/get_num_processors,
                  :cpu_last_five_minutes    => $4.to_f/get_num_processors,
                  :cpu_last_fifteen_minutes => $6.to_f/get_num_processors}
      else
        raise "Couldn't use `uptime` as expected."
      end
    rescue Exception
      error "Error determining load", $!.message
    end

    return result
  end

  def get_num_processors
    # first, check if the options provided is > 0. So leave the options blank to auto-detect
    processors = option('num_processors').to_i
    return processors if processors > 0

    # otherwise, pull it from memory
    processors = memory(:processors)

    # if we didn't get it from memory, try to auto-detect through /proc/cpuinfo
    unless processors && processors > 0
      if shell("cat /proc/cpuinfo | grep 'model name' | wc -l") =~ /(\d+)/
        processors = $1.to_i
      else
        raise "Couldn't use /proc/cpuinfo as expected."
      end
      raise "Couldn't use /proc/cpuinfo as expected." unless processors > 0
    end
    remember(:processors, processors)
    return processors
  end

  # Use this instead of backticks. It's made a separate method so it can be stubbed
  def shell(cmd)
    `#{cmd}`
  end

end

