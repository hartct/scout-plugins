class ResqueStats < Scout::Plugin

  needs 'redis', 'resque'

  OPTIONS=<<-EOS
  redis:
    name: Resque.redis
    notes: "Redis connection string: 'hostname:port' or 'hostname:port:db'"
    default: localhost:6379
  namespace:
    name: Namespace
    notes: "Resque namespace: 'resque:production'"
    default:
  resque_scheduler:
    name: resque_scheduler enabled?
    notes: "Enabled monitoring of resque_scheduler queues?"
    default: false
  metric_interval:
    name: Counter interval
    notes: "Display counter metrics in specified interval, can be second, minute or hour"
    default: "second" 
  EOS

  def build_report
    Resque.redis = option(:redis)
    Resque.redis.namespace = option(:namespace) || :resque
    info = Resque.info
    report(
      :working => info[:working],
      :pending => info[:pending],
      :total_failed  => info[:failed],
      :queues  => info[:queues],
      :workers => info[:workers]
    )
    counter(:processed, info[:processed], :per => String.new(option(:metric_interval)).to_sym)
    counter(:failed, info[:failed], :per => String.new(option(:metric_interval)).to_sym)
		counter(:workers, info[:workers], :per => String.new(option(:metric_interval)).to_sym)
    Resque.queues.each do |queue|
      report("#{queue}" => Resque.size(queue))
    end
		
		if option(:resque_scheduler)
			counter(:delayed_jobs, Array(Resque.redis.keys("delayed:*")).length, :per => String.new(option(:metric_interval)).to_sym)
			report("delayed_jobs" => Array(Resque.redis.keys("delayed:*")).length)
		end

  end

end
