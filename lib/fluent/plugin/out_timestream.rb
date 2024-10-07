# frozen_string_literal: true

require 'aws-sdk-core'
require 'aws-sdk-timestreamwrite'
require_relative 'timestream/version'

module Fluent
  module Plugin
    # rubocop: disable Metrics/ClassLength
    # Fluent plugin for Amazon Timestream
    class TimestreamOutput < Fluent::Plugin::Output

      VALID_TIME_UNIT =
        %w[
          SECONDS
          MILLISECONDS
          MICROSECONDS
          NANOSECONDS
        ].freeze

      # Raise when measure has empty value
      class EmptyValueError < StandardError
        def initialize(key_name = '')
          super("measure has empty value. key name: #{key_name}")
        end
      end

      # Raise when record has no dimensions
      class NoDimensionsError < StandardError
        def initialize
          super('record has no dimensions.')
        end
      end

      Fluent::Plugin.register_output('timestream', self)

      config_param :region, :string, default: nil

      config_param :aws_key_id, :string, secret: true, default: nil
      config_param :aws_sec_key, :string, secret: true, default: nil

      config_param :database, :string, default: nil
      config_param :table, :string, default: nil
      config_section :measure,
                     param_name: 'target_measures', required: false, multi: true do
        config_param :name, :string
        config_param :type, :string
      end
      config_param :time_unit, :string, default: 'SECONDS'
      config_param :time_key, default: nil

      config_param :endpoint, :string, default: nil
      config_param :ssl_verify_peer, :bool, default: true

      def configure(conf)
        super
        options = credential_options
        options[:region] = @region if @region
        options[:endpoint] = @endpoint if @endpoint
        options[:ssl_verify_peer] = @ssl_verify_peer
        @client = Aws::TimestreamWrite::Client.new(options)

        @database = ENV['AWS_TIMESTREAM_DATABASE'] if @database.nil?
        @table = ENV['AWS_TIMESTREAM_TABLE'] if @table.nil?
        validate_time_unit
      end

      def credential_options
        if @aws_key_id && @aws_sec_key
          {
            access_key_id: @aws_key_id,
            secret_access_key: @aws_sec_key
          }
        else
          {}
        end
      end

      def validate_time_unit
        return if VALID_TIME_UNIT.include?(@time_unit)
        raise Fluent::ConfigError, "Invalid time_unit: #{@time_unit}"
      end

      def formatted_to_msgpack_binary
        true
      end

      def format(_tag, time, record)
        [time, record].to_msgpack
      end

      def create_timestream_record(dimensions, time, measures)
        raise NoDimensionsError if dimensions.empty?

        {
          dimensions: dimensions,
          time: time.to_s,
          time_unit: @time_unit,
          **build_measure_payload(measures)
        }
      end

      def create_timestream_dimension(key, value)
        value = value.to_s

        # Timestream does not accept empty string.
        # Ignore this dimension.
        return nil if value.empty?

        {
          dimension_value_type: 'VARCHAR',
          name: key,
          value: value
        }
      end

      def create_timestream_measure(key, value)
        value = value.to_s

        # Timestream does not accept empty string.
        # By raising error, ignore entire record.
        raise EmptyValueError, key if value.empty?

        measure_config = @target_measures.find { |m| m[:name] == key }
        return nil unless measure_config

        {
          name: key,
          value: value,
          type: measure_config[:type]
        }
      end

      def create_timestream_dimensions_and_measures(record)
        record.each_with_object([[], []]) do |(key, value), (dimensions, measures)|
          if measure_field?(key)
            measure = create_timestream_measure(key, value)
            measures << measure if measure
          else
            dimension = create_timestream_dimension(key, value)
            dimensions << dimension if dimension
          end
        end
      end

      def measure_field?(key)
        @target_measures.any? { |m| m[:name] == key }
      end

      # rubocop:disable Metrics/MethodLength
      def create_timestream_records(chunk)
        timestream_records = []
        chunk.each do |time, record|
          time = record.delete(@time_key) unless @time_key.nil?
          dimensions, measures = create_timestream_dimensions_and_measures(record)
          timestream_records.push(create_timestream_record(dimensions, time, measures))
        rescue EmptyValueError, NoDimensionsError => e
          log.warn("ignored record due to (#{e})")
          log.debug("ignored record details: #{record}")
          next
        end

        timestream_records
      end
      # rubocop:enable Metrics/MethodLength

      def write(chunk)
        records = create_timestream_records(chunk)
        log.info("read #{records.length} records from chunk")
        write_records(records)
      end

      def write_records(records)
        return if records.empty?
        @client.write_records(
          database_name: @database,
          table_name: @table,
          records: records
        )
      rescue Aws::TimestreamWrite::Errors::RejectedRecordsException => e
        log.error(e.rejected_records)
      end

      def build_measure_payload(measures)
        if measures.size > 1
          multi_measure_payload(measures)
        else
          single_measure_payload(measures)
        end
      end

      def multi_measure_payload(measures)
        {
          measure_value_type: 'MULTI',
          measure_values: measures
        }
      end

      def single_measure_payload(measures)
        measure = measures.empty? ? dummy_measure : measures.first
        {
          measure_name: measure[:name],
          measure_value: measure[:value],
          measure_value_type: measure[:type]
        }
      end

      def dummy_measure
        { name: '-', value: '-', type: 'VARCHAR' }.freeze
      end

    end
    # rubocop: enable Metrics/ClassLength
  end
end
