# fluent-plugin-dedup

A fluentd plugin to suppress emission of subsequent logs identical to the first one.

[![Build Status](https://travis-ci.org/edvakf/fluent-plugin-dedup.svg?branch=master)](https://travis-ci.org/edvakf/fluent-plugin-dedup)

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
      cache_per_tag 10 # optional. If set, recent logs up to this number is cached.
      cache_ttl 600 # optional. If set, cache entries is expired in this TTL.
    </match>

    <match dedup.some.thing>
      type stdout
    </match>

All logs that are processed by this plugin will have tag prefix `dedup`.

If the optional `file` parameter is set, it dumps the state during shutdown and loads on start, so that it can still dedup after reload.

If the optional `cache_per_tag` is set, it caches N recently appeared logs (only caches `unique_id` in this example) and compared to new logs.

If the optional `cache_ttl` is set, it evicts cache entries in a specific amount of time.

## Testing

    bundle install
    bundle exec rake test

## Installation

    gem install fluent-plugin-dedup

## Contributing

1. Fork it ( https://github.com/[my-github-username]/fluent-plugin-dedup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
