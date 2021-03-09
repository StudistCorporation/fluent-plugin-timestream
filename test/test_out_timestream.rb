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

  test 'single record(STRING)' do
    d = create_driver
    time = event_time('2021-01-01 11:11:11 UTC')
    log = { 'key' => 'value' }
    d.run(default_tag: 'test') do
      d.feed(time, log)
    end

    records = @server.request_records
    assert_equal 1, records.length
    dimensions = create_expected_dimensions(log)
    verify_requested_record(records[0], time, dimensions)
  end

  test 'single record(INTEGER)' do
    d = create_driver
    time = event_time('2021-01-01 11:11:11 UTC')
    log = { 'key' => 1000 }
    d.run(default_tag: 'test') do
      d.feed(time, log)
    end

    records = @server.request_records
    assert_equal 1, records.length
    dimensions = create_expected_dimensions(log)
    verify_requested_record(records[0], time, dimensions)
  end

  test 'single record(empty string)' do
    d = create_driver
    time = event_time('2021-01-01 01:00:00 UTC')
    log = { 'key1' => '', 'key2' => 'val' }

    d.run(default_tag: 'test') do
      d.feed(time, log)
    end

    records = @server.request_records
    assert_equal 1, records.length

    dimensions = create_expected_dimensions({ 'key2' => 'val' })

    verify_requested_record(records[0], time, dimensions)
  end

  test 'single record(nil)' do
    d = create_driver
    time = event_time('2021-01-01 01:00:00 UTC')
    log = { 'key1' => nil, 'key2' => 'val' }

    d.run(default_tag: 'test') do
      d.feed(time, log)
    end

    records = @server.request_records
    assert_equal 1, records.length

    dimensions = create_expected_dimensions({ 'key2' => 'val' })

    verify_requested_record(records[0], time, dimensions)
  end

  test 'multiple records' do
    d = create_driver
    time1 = event_time('2021-01-01 01:00:00 UTC')
    time2 = event_time('2021-01-02 02:00:00 UTC')
    time3 = event_time('2021-01-03 03:00:00 UTC')

    log = create_log(key_base: KEY, value_base: VALUE, dimension_num: 3)

    d.run(default_tag: 'test') do
      d.feed(time1, log)
      d.feed(time2, log)
      d.feed(time3, log)
    end

    records = @server.request_records
    assert_equal 3, records.length

    dimensions = create_expected_dimensions(log)
    verify_requested_record(records[0], time1, dimensions)
    verify_requested_record(records[1], time2, dimensions)
    verify_requested_record(records[2], time3, dimensions)
  end

  test 'multiple records(not sorted by time)' do
    d = create_driver
    time1 = event_time('2021-01-01 01:00:00 UTC')
    time2 = event_time('2021-01-03 03:00:00 UTC')
    time3 = event_time('2021-01-02 02:00:00 UTC')

    log = create_log(key_base: KEY, value_base: VALUE, dimension_num: 3)

    d.run(default_tag: 'test') do
      d.feed(time1, log)
      d.feed(time2, log)
      d.feed(time3, log)
    end

    records = @server.request_records
    assert_equal 3, records.length

    dimensions = create_expected_dimensions(log)
    verify_requested_record(records[0], time1, dimensions)
    verify_requested_record(records[1], time2, dimensions)
    verify_requested_record(records[2], time3, dimensions)
  end

  test 'multiple records(ignore no dimensions record)' do
    d = create_driver
    time1 = event_time('2021-01-01 01:00:00 UTC')
    time2 = event_time('2021-01-03 03:00:00 UTC')

    log1 = { 'key1' => '' }
    log2 = { 'key1' => 'value' }

    d.run(default_tag: 'test') do
      d.feed(time1, log1)
      d.feed(time2, log2)
    end

    records = @server.request_records
    assert_equal 1, records.length

    dimensions = create_expected_dimensions(log2)
    verify_requested_record(records[0], time2, dimensions)
  end

  test 'with measure(STRING)' do
    measure_name = 'measure'
    measure_value_type = 'VARCHAR'
    measure_value = 'measure_value'
    test_with_measure(measure_name, measure_value_type, measure_value)
  end

  test 'with measure(INTEGER)' do
    measure_name = 'measure'
    measure_value_type = 'INTEGER'
    measure_value = 1000
    test_with_measure(measure_name, measure_value_type, measure_value)
  end

  test 'with measure(VARCHAR - nil)' do
    measure_name = 'measure'
    measure_value_type = 'VARCHAR'
    measure_value = nil
    test_with_measure_empty_value(measure_name, measure_value_type, measure_value)
  end

  test 'with measure(VARCHAR - empty)' do
    measure_name = 'measure'
    measure_value_type = 'VARCHAR'
    measure_value = ''
    test_with_measure_empty_value(measure_name, measure_value_type, measure_value)
  end

  test 'with measure(INTEGER - nil)' do
    measure_name = 'measure'
    measure_value_type = 'INTEGER'
    measure_value = nil
    test_with_measure_empty_value(measure_name, measure_value_type, measure_value)
  end

  private

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def test_with_measure_empty_value(measure_name, measure_value_type, measure_value)
      d = create_driver(default_config +
        "<measure>
          name #{measure_name}
          type #{measure_value_type}
        </measure>")

      time1 = event_time('2021-01-01 11:11:11 UTC')
      time2 = event_time('2021-01-02 11:11:11 UTC')
      log1 = create_log(key_base: KEY, value_base: VALUE, dimension_num: 2)
      log1[measure_name] = measure_value
      log2 = create_log(key_base: KEY, value_base: VALUE, dimension_num: 2)

      d.run(default_tag: 'test') do
        # log1 will be ignored because it has empty measure value
        d.feed(time1, log1)
        d.feed(time2, log2)
      end

      records = @server.request_records
      assert_equal 1, records.length

      dimensions = create_expected_dimensions(log2)
      verify_requested_record(records[0], time2, dimensions)
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def test_with_measure(measure_name, measure_value_type, measure_value)
      d = create_driver(default_config +
        "<measure>
          name #{measure_name}
          type #{measure_value_type}
        </measure>")

      time = event_time('2021-01-01 11:11:11 UTC')
      log = create_log(key_base: KEY, value_base: VALUE, dimension_num: 2)
      log[measure_name] = measure_value

      d.run(default_tag: 'test') do
        d.feed(time, log)
      end

      records = @server.request_records
      assert_equal 1, records.length

      log.delete(measure_name)
      dimensions = create_expected_dimensions(log)
      verify_requested_record(records[0], time, dimensions,
                              measure_name: measure_name,
                              measure_value: measure_value.to_s,
                              measure_value_type: measure_value_type)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

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

      assert_equal dimensions, record['Dimensions']
    end
    # rubocop: enable Metrics/ParameterLists

    def create_log(key_base:, value_base:, dimension_num: 1)
      (0...dimension_num).each_with_object({}) do |i, log|
        log["#{key_base}#{i}"] = "#{value_base}#{i}"
      end
    end

    def create_expected_dimensions(hash)
      hash.map do |k, v|
        {
          'DimensionValueType' => 'VARCHAR',
          'Name' => k,
          'Value' => v.to_s
        }
      end
    end

    def default_config
      %(
        aws_key_id XXXXX
        aws_sec_key XXXXX
        region dummy
        database dummyDB
        table dummyTable
        endpoint https://localhost:#{@server.port}
        ssl_verify_peer false
      )
    end

    def create_driver(conf = default_config)
      Fluent::Test::Driver::Output.new(Fluent::Plugin::TimestreamOutput).configure(conf)
    end
end
# rubocop: enable Metrics/ClassLength
