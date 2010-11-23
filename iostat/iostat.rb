class Iostat < Scout::Plugin

  OPTIONS=<<-EOS
  device:
    name: Device
    notes: The device to check, eg 'sda1'. If not specified, uses the device mounted at '/'
  EOS

  def build_report
    # determine the device, either from the passed option or by parsing `mount`
    device = option('device') || `mount`.split("\n").grep(/ \/ /)[0].split[0]
    stats = iostat(device)
    error("Device not found: #{device} -- check your plugin settings.",
          "FYI, mount returns:\n#{`mount`}") and return if !stats

    counter(:rps,   stats['rio'],        :per => :second)
    counter(:wps,   stats['wio'],        :per => :second)
    counter(:rkbps, stats['rsect'] / 2,  :per => :second)
    counter(:wkbps, stats['wsect'] / 2,  :per => :second)
    counter(:util,  stats['use'] / 10.0, :per => :second)
    # Not 100% sure that average queue length is present on all distros.
    if stats['aveq']
      counter(:aveq,  stats['aveq'], :per => :second)
    end

    if old = memory("#{device}_stats")
      ios = (stats['rio'] - old['rio']) + (stats['wio']  - old['wio'])

      if ios > 0
        await = ((stats['ruse'] - old['ruse']) + (stats['wuse'] - old['wuse'])) / ios.to_f

        report(:await => await)
      end
    end

    remember("#{device}_stats" => stats)
  end
  
  private
  COLUMNS = %w(major minor name rio rmerge rsect ruse wio wmerge wsect wuse running use aveq)

  def iostat(dev)
    IO.readlines('/proc/diskstats').each do |line|
      entry = Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]
      return entry if dev.include?(entry['name'])
    end

    nil
  end
end
