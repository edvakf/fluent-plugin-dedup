require 'json'
require 'lru_redux'

class Fluent::DedupFilter < Fluent::Filter
  Fluent::Plugin.register_output('filter', self)

  config_param :key, :string, :default => nil
  config_param :file, :string, :default => nil
  config_param :cache_per_tag, :size, :default => 1

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  def configure(conf)
    super
    unless conf.include?('key')
      raise Fluent::ConfigError, "config parameter `key` is required"
    end
    @states = {}
  end

  def start
    super

    restore_states
  end

  def shutdown
    super

    save_states
  end

  def filter_stream(tag, es)
    new_es = Fluent::MultiEventStream.new
    es.each do |time, record|
      next if dup?(tag, record)
      new_es.add(time, record)
    end
    new_es
  end

  private
  def restore_states
    if not @file.nil? and File.file?(@file)
      dump = JSON.parse(File.open(@file).read) rescue {}
      dump.each do |tag, ids|
        lru = new_lru
        ids.each {|id| lru[id] = true}
        @states[tag] = lru
      end
    end
  end

  def save_states
    unless @file.nil?
      File.open(@file, 'wb') do |f|
        dump = {}
        @states.each do |tag, lru|
          dump[tag] = lru.to_a.map(&:first)
        end
        f.print(dump.to_json)
      end
    end
  end

  def dup?(tag, record)
    is_dup = false
    if record.include?(@key)
      @states[tag] = new_lru unless @states.include?(tag)
      if @states[tag].fetch(record[@key])
        is_dup = true
      else
        @states[tag][record[@key]] = true
      end
    else
      log.warn "record does not have key `#{@key}`, record: #{record.to_json}"
    end
    is_dup
  end

  def new_lru
    LruRedux::ThreadSafeCache.new(@cache_per_tag)
  end
end if defined?(Fluent::Filter) # Avoid 'uninitialized constant Fluent::Filter' at Fluentd v0.10
