# frozen_string_literal: true

require_relative 'helper'
require_relative 'server'
require 'fluent/plugin/out_timestream'

# rubocop: disable Metrics/ClassLength
class TimestreamOutputTest < Test::Unit::TestCase
  KEY = 'key'
  VALUE = 'value'

  setup do
    Fluent::Test.setup
    @server = TestServer.new
    @server.start
  end

  test 'get database name and table name from ENV' do
    ENV['AWS_TIMESTREAM_DATABASE'] = 'TEST_DB'
    ENV['AWS_TIMESTREAM_TABLE'] = 'TEST_TABLE'
    d = create_driver('region "test"')
    assert_equal 'TEST_DB', d.instance.database
    assert_equal 'TEST_TABLE', d.instance.table
    ENV.delete('AWS_TIMESTREAM_DATABASE')
    ENV.delete('AWS_TIMESTREAM_TABLE')
  end

  test 'single record' do
    d = create_driver
    time = event_time('2021-01-01 11:11:11 UTC')
    d.run(default_tag: 'test') do
      d.feed(time, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
    end

    records = @server.request_records
    assert_equal 1, records.length
    dimensions = create_dimensions(key_base: KEY, value_base: VALUE, dimension_num: 3)
    verify_requested_record(records[0], time, dimensions)
  end

  test 'multiple records' do
    d = create_driver
    time1 = event_time('2021-01-01 01:00:00 UTC')
    time2 = event_time('2021-01-02 02:00:00 UTC')
    time3 = event_time('2021-01-03 03:00:00 UTC')

    d.run(default_tag: 'test') do
      d.feed(time1, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
      d.feed(time2, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
      d.feed(time3, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
    end

    records = @server.request_records
    assert_equal 3, records.length

    dimensions = create_dimensions(key_base: KEY, value_base: VALUE, dimension_num: 3)
    verify_requested_record(records[0], time1, dimensions)
    verify_requested_record(records[1], time2, dimensions)
    verify_requested_record(records[2], time3, dimensions)
  end

  test 'multi records(not sorted by time)' do
    d = create_driver
    time1 = event_time('2021-01-01 01:00:00 UTC')
    time2 = event_time('2021-01-03 03:00:00 UTC')
    time3 = event_time('2021-01-02 02:00:00 UTC')

    d.run(default_tag: 'test') do
      d.feed(time1, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
      d.feed(time2, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
      d.feed(time3, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
    end

    records = @server.request_records
    assert_equal 3, records.length

    dimensions = create_dimensions(key_base: KEY, value_base: VALUE, dimension_num: 3)
    verify_requested_record(records[0], time1, dimensions)
    verify_requested_record(records[1], time2, dimensions)
    verify_requested_record(records[2], time3, dimensions)
  end

  test 'with measure' do
    measure_name = 'key2'
    d = create_driver(default_config +
      "<measure>
        name #{measure_name}
        type VARCHAR
      </measure>")
    time = event_time('2021-01-01 11:11:11 UTC')
    d.run(default_tag: 'test') do
      d.feed(time, create_log(key_base: KEY, value_base: VALUE, dimension_num: 3))
    end

    records = @server.request_records
    assert_equal 1, records.length

    dimensions = create_dimensions(key_base: KEY, value_base: VALUE, dimension_num: 2)
    verify_requested_record(records[0], time, dimensions,
                            measure_name: measure_name, measure_value: 'value2')
  end

  test 'with measure(INTEGER)' do
    measure_name = 'measure'
    measure_value_type = 'INTEGER'
    measure_value = '1000'

    d = create_driver(default_config +
      "<measure>
        name #{measure_name}
        type #{measure_value_type}
      </measure>")

    time = event_time('2021-01-01 11:11:11 UTC')

    d.run(default_tag: 'test') do
      log = create_log(key_base: KEY, value_base: VALUE, dimension_num: 2)
      log[measure_name] = measure_value
      d.feed(time, log)
    end

    records = @server.request_records
    assert_equal 1, records.length

    dimensions = create_dimensions(key_base: KEY, value_base: VALUE, dimension_num: 2)
    verify_requested_record(records[0], time, dimensions,
                            measure_name: measure_name,
                            measure_value: measure_value,
                            measure_value_type: measure_value_type)
  end

  private

    # rubocop: disable Metrics/ParameterLists
    def verify_requested_record(
      record,
      time,
      dimensions,
      time_unit: 'SECONDS',
      measure_name: '-',
      measure_value: '-',
      measure_value_type: 'VARCHAR'
    )
      assert_equal time.to_s, record['Time']
      assert_equal time_unit, record['TimeUnit']
      assert_equal measure_name, record['MeasureName']
      assert_equal measure_value, record['MeasureValue']
      assert_equal measure_value_type, record['MeasureValueType']

      assert_equal record['Dimensions'], dimensions
    end
    # rubocop: enable Metrics/ParameterLists

    def create_log(key_base:, value_base:, dimension_num: 1)
      (0...dimension_num).each_with_object({}) do |i, log|
        log["#{key_base}#{i}"] = "#{value_base}#{i}"
      end
    end

    def create_dimensions(key_base:, value_base:, dimension_num: 1)
      (0...dimension_num).map do |i|
        {
          'DimensionValueType' => 'VARCHAR',
          'Name' => "#{key_base}#{i}",
          'Value' => "#{value_base}#{i}"
        }
      end
    end

    def default_config
      %(
        region dummy
        database dummyDB
        table dummyTable
        endpoint https://localhost:#{@server.port}
        ssl_verify_peer false
        chunk_limit records 1
      )
    end

    def create_driver(conf = default_config)
      Fluent::Test::Driver::Output.new(Fluent::Plugin::TimestreamOutput).configure(conf)
    end
end
# rubocop: enable Metrics/ClassLength
