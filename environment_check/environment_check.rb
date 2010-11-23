# Used for trouble-shooting environment issues. Often, different paths in 
class EnvironmentCheck < Scout::Plugin
  def build_report
    last_run = memory(:last_run)
    # run tuner if it's never run before, or if it's been X days since last tuner run
    if last_run == nil || (last_run.is_a?(Time) && Time.now-86400 >= last_run) # runs once a day max
      s=["This alert is generated daily. To stop getting this alert, remove or disable the EnvironmentCheck plugin.",
      "Ruby Version: #{RUBY_VERSION} #{RUBY_PLATFORM} #{RUBY_RELEASE_DATE}",
      "$PATH: \n#{ENV['PATH'].gsub(":","\n")}",
      "Gem Path: #{Gem.path}"].join("\n\n")
      alert("Environment Check", s)

      remember(:last_run, Time.now)
    else
      remember(:last_run, memory(:last_run))
    end
  end
end