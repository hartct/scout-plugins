class MemcachedStats < Scout::Plugin
  needs 'memcache', 'yaml'

  OPTIONS = <<-EOS
  host:
    name: Host
    notes: The host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port memcached is running on
    default: 11211
  EOS

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    connection = MemCache.new "#{option(:host)}:#{option(:port)}"
    begin
      stats = connection.stats["#{option(:host)}:#{option(:port)}"]
    rescue Errno::ECONNREFUSED, MemCache::MemCacheError => e
      return error( "Could not connect to Memcached.",
                    "Make certain you've specified the correct host and port" )
    end

    report(:uptime_in_hours   => stats['uptime'].to_f / 60 / 60)
    report(:used_memory_in_mb => stats['bytes'].to_i / MEGABYTE)
    report(:limit_in_mb       => stats['limit_maxbytes'].to_i / MEGABYTE)

    hits_per_sec    = counter(:hits_per_sec,    stats['get_hits'].to_i,   :per => :second)
    misses_per_sec  = counter(:misses_per_sec,  stats['get_misses'].to_i, :per => :second)

    if hits_per_sec && misses_per_sec
      gets_per_sec    = hits_per_sec + misses_per_sec
      report(:gets_per_sec  => gets_per_sec)
      if gets_per_sec > 0
        report(:hit_ratio     => (hits_per_sec   / gets_per_sec))
        report(:miss_ratio    => (misses_per_sec / gets_per_sec))
      end
    end

    counter(:evictions_per_sec,     stats['evictions'].to_i,     :per => :second)
    counter(:sets_per_sec,          stats['cmd_set'].to_i,       :per => :second)

    counter(:kilobytes_read_per_sec,    (stats['bytes_read'].to_i / KILOBYTE),    :per => :second)
    counter(:kilobytes_written_per_sec, (stats['bytes_written'].to_i / KILOBYTE), :per => :second)

    # General Stats
    %w(curr_items total_items curr_connections threads).each do |key|
      report(key => stats[key])
    end
  end

  # Overwrite counter to return the calculated result
  def counter(name, value, options = {}, &block)
    current_time = Time.now

    if data = memory("_counter_#{name}")
      last_time, last_value = data[:time], data[:value]
      elapsed_seconds       = current_time - last_time

      # We won't log it if the value has wrapped or enough time hasn't
      # elapsed
      if value >= last_value && elapsed_seconds >= 1
        if block
          result = block.call(last_value, value)
        else
          result = value - last_value
        end

        case options[:per]
        when :second, 'second'
          result = result / elapsed_seconds.to_f
        when :minute, 'minute'
          result = result / elapsed_seconds.to_f * 60.0
        else
          raise "Unknown option for ':per': #{options[:per].inspect}"
        end

        if options[:round]
          # Backward compatibility
          options[:round] = 1 if options[:round] == true

          result = (result * (10 ** options[:round])).round / (10 ** options[:round]).to_f
        end

        report(name => result)
      end
    end

    remember("_counter_#{name}" => { :time => current_time, :value => value })
    result
  end
end
