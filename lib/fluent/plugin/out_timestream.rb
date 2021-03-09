# frozen_string_literal: true

require 'aws-sdk-core'
require 'aws-sdk-timestreamwrite'
require_relative 'timestream/version'

module Fluent
  module Plugin
    # rubocop: disable Metrics/ClassLength
    # Fluent plugin for Amazon Timestream
    class TimestreamOutput < Fluent::Plugin::Output

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
                     param_name: 'target_measure', required: false, multi: false do
        config_param :name, :string
        config_param :type, :string
      end

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

      def formatted_to_msgpack_binary
        true
      end

      def format(_tag, time, record)
        [time, record].to_msgpack
      end

      def create_timestream_record(dimensions, time, measure)
        raise NoDimensionsError if dimensions.empty?
        measure = { name: '-', value: '-', type: 'VARCHAR' } if measure.empty?
        {
          dimensions: dimensions,
          time: time.to_s,
          time_unit: 'SECONDS',
          measure_name: measure[:name],
          measure_value: measure[:value],
          measure_value_type: measure[:type]
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

        {
          name: key,
          value: value,
          type: @target_measure[:type]
        }
      end

      def create_timestream_dimensions_and_measure(record)
        measure = {}
        dimensions = record.each_with_object([]) do |(k, v), result|
          if @target_measure && k == @target_measure[:name]
            measure = create_timestream_measure(k, v)
            next
          end
          dimension = create_timestream_dimension(k, v)
          result.push(dimension) unless dimension.nil?
        end
        return [dimensions, measure]
      end

      def create_timestream_records(chunk)
        timestream_records = []
        chunk.each do |time, record|
          dimensions, measure = create_timestream_dimensions_and_measure(record)
          timestream_records.push(create_timestream_record(dimensions, time, measure))
        rescue EmptyValueError, NoDimensionsError => e
          log.warn("ignored record due to (#{e})")
          log.debug("ignored record details: #{record}")
          next
        end

        timestream_records
      end

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
      rescue StandardError => e
        log.error(e.message)
      end

    end
    # rubocop: enable Metrics/ClassLength
  end
end
