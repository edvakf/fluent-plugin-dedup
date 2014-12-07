$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'test/unit'
require 'fluent/load'
require 'fluent/test'

require 'fluent/plugin/out_dedup'
