# fluent-plugin-dedup

A fluentd plugin to suppress emission of subsequent logs identical to the first one.

## Example Usage

It's useful when the output of a command executed by `in_exec` only returns the "latest" state of something and you want to send logs only when there is a change.

    <source>
      type exec
      command latest_state_of_something.rb
      format json
      keys unique_id,foo,bar
      tag some.thing
      run_interval 1s
    </source>

    <match some.thing>
      type dedup
      key  unique_id # required
      file /tmp/dedup_state.json # optional. If set, saves the state to the file.
    </match>

    <match dedup.some.thing>
      type stdout
    </match>

All logs that are processed by this plugin will have tag prefix `dedup`.

If the optional `file` parameter is set, it dumps the state during shutdown and loads on start, so that it can still dedup after reload.

## Installation

    gem install fluent-plugin-dedup

## Contributing

1. Fork it ( https://github.com/[my-github-username]/fluent-plugin-dedup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
