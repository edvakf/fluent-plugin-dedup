require_relative '../../helper'

class DedupFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    key     unique_id
  ]

  def create_driver(conf=CONFIG, tag='test', use_v1=false)
    Fluent::Test::FilterTestDriver.new(Fluent::DedupFilter).configure(conf, use_v1)
  end

  test "`key` must be present" do
    assert_raise(Fluent::ConfigError) {
      d = create_driver('file abc')
    }
  end

  test "two sequential identical logs are emitted only once" do
    d = create_driver(CONFIG)
    result = d.run do
      d.emit({'unique_id' => '1'})
      d.emit({'unique_id' => '1'}) # dup
      d.emit({'unique_id' => '2'})
      d.emit({'unique_id' => '1'})
    end
    filtered = result.map{|time, record| record}

    assert_equal 3, filtered.length
    assert_equal '1', filtered[0]['unique_id']
    assert_equal '2', filtered[1]['unique_id']
    assert_equal '1', filtered[2]['unique_id']
  end

  test "different tags are not treated as identical" do
    d = create_driver(CONFIG)
    result = d.run do
      d.emit({'unique_id' => '1'}, Fluent::Engine.now, 'test1')
      d.emit({'unique_id' => '1'}, Fluent::Engine.now, 'test2') # not dup
    end
    filtered = result.map{|time, record| record}

    assert_equal 2, filtered.length
  end

  test "state is not saved on shutdown by default" do
    d1 = create_driver(CONFIG)
    result1 = d1.run do
      d1.emit({'unique_id' => '1'})
    end
    d2 = create_driver(CONFIG)
    result2 = d2.run do
      d2.emit({'unique_id' => '1'})
    end
    filtered1 = result1.map{|time, record| record}
    filtered2 = result2.map{|time, record| record}

    assert_equal 1, filtered1.length
    assert_equal 1, filtered2.length
  end

  sub_test_case '`file` parameter is present' do
    setup do
      @statefile = File.expand_path('../../../../states.json', __FILE__)
      File.unlink(@statefile) if File.file?(@statefile)
    end

    teardown do
      File.unlink(@statefile) if File.file?(@statefile)
    end

    test "state is saved on shutdown if `file` parameter is present" do
      config = %[
        key     unique_id
        file    #{@statefile}
      ]

      d1 = create_driver(config)
      result1 = d1.run do
        d1.emit({'unique_id' => '1'})
      end
      filtered1 = result1.map{|time, record| record}
      d2 = create_driver(config)
      result2 = d2.run do
        d2.emit({'unique_id' => '1'})
      end
      filtered2 = result2.map{|time, record| record}

      assert_equal 1, filtered1.length
      assert_equal 0, filtered2.length
    end
  end

  sub_test_case '`cache_per_tag` parameter is present' do
    test "a record identical to most recent N records is suppressed" do
      config = %[
        key           unique_id
        cache_per_tag 2
      ]

      d = create_driver(config)
      result = d.run do
        d.emit({'unique_id' => '1'})
        d.emit({'unique_id' => '1'}) # dup
        d.emit({'unique_id' => '2'})
        d.emit({'unique_id' => '1'}) # dup
      end
      filtered = result.map{|time, record| record}

      assert_equal 2, filtered.length
      assert_equal '1', filtered[0]['unique_id']
      assert_equal '2', filtered[1]['unique_id']
    end
  end
end
