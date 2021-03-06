require 'helper'
require 'timecop'

class DedupOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    key     unique_id
  ]

  def create_driver(conf=CONFIG, tag='test', use_v1=false)
    Fluent::Test::OutputTestDriver.new(Fluent::DedupOutput, tag).configure(conf, use_v1)
  end

  test "`key` must be present" do
    assert_raise(Fluent::ConfigError) {
      d = create_driver('file abc')
    }
  end

  test "two sequential identical logs are emitted only once" do
    d = create_driver(CONFIG)
    d.run do
      d.emit({'unique_id' => '1'}, Time.now)
      d.emit({'unique_id' => '1'}, Time.now) # dup
      d.emit({'unique_id' => '2'}, Time.now)
      d.emit({'unique_id' => '1'}, Time.now)
    end

    assert_equal 3, d.emits.length
    assert_equal '1', d.emits[0][2]['unique_id']
    assert_equal '2', d.emits[1][2]['unique_id']
    assert_equal '1', d.emits[2][2]['unique_id']
    assert_equal 'dedup.test', d.emits[0][0], 'sets a tag prefix `dedup`'
  end

  test "different tags are not treated as identical" do
    d = create_driver(CONFIG)
    d.run do
      d.emit({'unique_id' => '1'}, Time.now)
      d.tag = d.tag + d.tag # set a different tag from the first
      d.emit({'unique_id' => '1'}, Time.now) # not dup
    end

    assert_equal 2, d.emits.length
  end

  test "state is not saved on shutdown by default" do
    d1 = create_driver(CONFIG)
    d1.run do
      d1.emit({'unique_id' => '1'}, Time.now)
    end
    d2 = create_driver(CONFIG)
    d2.run do
      d2.emit({'unique_id' => '1'}, Time.now)
    end

    assert_equal 1, d1.emits.length
    assert_equal 1, d2.emits.length
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
      d1.run do
        d1.emit({'unique_id' => '1'}, Time.now)
      end
      d2 = create_driver(config)
      d2.run do
        d2.emit({'unique_id' => '1'}, Time.now)
      end

      assert_equal 1, d1.emits.length
      assert_equal 0, d2.emits.length
    end
  end

  sub_test_case '`cache_per_tag` parameter is present' do
    test "a record identical to most recent N records is suppressed" do
      config = %[
        key           unique_id
        cache_per_tag 2
      ]

      d = create_driver(config)
      d.run do
        d.emit({'unique_id' => '1'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now) # dup
        d.emit({'unique_id' => '2'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now) # dup
      end

      assert_equal 2, d.emits.length
      assert_equal '1', d.emits[0][2]['unique_id']
      assert_equal '2', d.emits[1][2]['unique_id']
    end
  end

  sub_test_case '`cache_ttl` parameter is present' do
    setup do
      Timecop.freeze(Time.now)
    end

    teardown do
      Timecop.return
    end

    test "a record identical to most recent N records is suppressed with TTL option" do
      config = %[
        key           unique_id
        cache_per_tag 2
        cache_ttl     60
      ]

      d = create_driver(config)
      d.run do
        d.emit({'unique_id' => '1'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now) # dup
        Timecop.freeze(Time.now + 59)
        d.emit({'unique_id' => '1'}, Time.now) # dup
        Timecop.freeze(Time.now + 1) # expires cache
        d.emit({'unique_id' => '1'}, Time.now)
        Timecop.freeze(Time.now + 1)
        d.emit({'unique_id' => '1'}, Time.now) # dup
      end

      assert_equal 2, d.emits.length
      assert_equal '1', d.emits[0][2]['unique_id']
      assert_equal '1', d.emits[1][2]['unique_id']
    end
  end
end
