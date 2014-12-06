require 'json'

class Fluent::DedupOutput < Fluent::Output
  Fluent::Plugin.register_output('dedup', self)

  config_param :key, :string, :default => nil
  config_param :file, :string, :default => nil

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  def configure(conf)
    super
    unless conf.include?('key')
      raise Fluent::ConfigError, "config parameter `key` is required"
    end
    @key = conf['key']
    @file = conf['file']
    @states = {}
  end

  def start
    super

    if not @file.nil? and File.file?(@file)
      @states = JSON.parse(File.open(@file).read) rescue {}
    end
  end

  def shutdown
    super

    save_states
  end

  def emit(tag, es, chain)
    es.each do |time, record|
      next if dup?(tag, record)
      update_states(tag, record)
      Fluent::Engine.emit("dedup.#{tag}", time, record)
    end

    chain.next
  end

  private
  def save_states
    unless @file.nil?
      File.open(@file, 'wb') do |f|
        f.print(@states.to_json)
      end
    end
  end

  def dup?(tag, record)
    unless record.include?(@key)
      log.warn "record does not have key `#{@key}`, record: #{record.to_json}"
    end
    @states[tag] == record[@key]
  end

  def update_states(tag, record)
    @states[tag] = record[@key]
  end
end
