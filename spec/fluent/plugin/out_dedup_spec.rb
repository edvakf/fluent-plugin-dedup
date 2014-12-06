require 'spec_helper'

describe Fluent::DedupOutput do
  let(:tag) {'test'}
  let(:driver) {Fluent::Test::OutputTestDriver.new(Fluent::DedupOutput, tag).configure(config)}
  let(:instance) {driver.instance}

  describe 'emit' do
    let(:config) {
      %[
      key     unique_id
      ]
    }

    context 'single tag' do
      let(:driver_emits) {
        d = driver
        d.run do
          d.emit({'unique_id' => '1'}, Time.now)
          d.emit({'unique_id' => '1'}, Time.now) # dup
          d.emit({'unique_id' => '2'}, Time.now)
          d.emit({'unique_id' => '1'}, Time.now)
        end
        d.emits
      }

      it 'should suppress subsequent logs identical to the first one' do
        expect(driver_emits.length).to eq(3)
        expect(driver_emits[0][2]['unique_id']).to eq('1')
        expect(driver_emits[0][0]).to eq('dedup.test')
        expect(driver_emits[1][2]['unique_id']).to eq('2')
        expect(driver_emits[2][2]['unique_id']).to eq('1')
      end

      it 'should set a tag prefix `dedup`' do
        expect(driver_emits[0][0]).to eq('dedup.test')
      end
    end

    context 'multiple tags' do
      let(:driver_emits) {
        d = driver
        d.run do
          d.emit({'unique_id' => '1'}, Time.now)
          d.tag = d.tag + d.tag
          d.emit({'unique_id' => '1'}, Time.now) # not dup
        end
        d.emits
      }

      it 'should treat different tags non-identical logs' do
        expect(driver_emits.length).to eq(2)
      end
    end
  end

  describe 'shutdown' do
    tmpfile = File.expand_path('../../../../states.json', __FILE__)
    before(:all) {File.unlink(tmpfile) if File.file?(tmpfile)}
    after(:all) {File.unlink(tmpfile)}

    let(:config) {
      %[
      key     unique_id
      file    #{tmpfile}
      ]
    }

    let(:driver_emits) {
      d = driver
      d.run do
        d.emit({'unique_id' => '1'}, Time.now)
        d.emit({'unique_id' => '2'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now) # dup
      end
      d.run do
        d.emit({'unique_id' => '1'}, Time.now) # dup
        d.emit({'unique_id' => '2'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now)
        d.emit({'unique_id' => '1'}, Time.now) # dup
      end
      d.emits
    }

    it 'saves current id to a file and loads' do
      expect(driver_emits.length).to eq(5)
      expect(driver_emits[0][2]['unique_id']).to eq('1')
      expect(driver_emits[1][2]['unique_id']).to eq('2')
      expect(driver_emits[2][2]['unique_id']).to eq('1')
      expect(driver_emits[3][2]['unique_id']).to eq('2')
      expect(driver_emits[4][2]['unique_id']).to eq('1')
    end
  end
end

