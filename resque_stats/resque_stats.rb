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
      :working_count => info[:working],
      :pending_count => info[:pending],
      :total_failed_count  => info[:failed],
      :queue_count => info[:queues],
      :worker_count => info[:workers]
    )
    counter(:processed_rate, info[:processed], :per => String.new(option(:metric_interval)).to_sym)
    counter(:failed_rate, info[:failed], :per => String.new(option(:metric_interval)).to_sym)
		counter(:workers_rate, info[:workers], :per => String.new(option(:metric_interval)).to_sym)
    Resque.queues.each do |queue|
      report("#{queue}_count" => Resque.size(queue))
    end
		
		if option(:resque_scheduler)
			counter(:delayed_jobs_rate, Array(Resque.redis.keys("delayed:*")).length, :per => String.new(option(:metric_interval)).to_sym)
			report(:delayed_job_count => Array(Resque.redis.keys("delayed:*")).length)
		end

  end

end
