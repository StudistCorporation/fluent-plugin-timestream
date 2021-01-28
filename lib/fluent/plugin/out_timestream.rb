# frozen_string_literal: true

require 'aws-sdk-core'
require 'aws-sdk-timestreamwrite'
require_relative 'timestream/version'

module Fluent
  module Plugin
    # Fluent plugin for Amazon Timestream
    class TimestreamOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output('timestream', self)

      config_param :region, :string

      config_section :aws_credentials,
                     param_name: 'aws_credentials', required: false, multi: false do
        config_param :access_key_id, :string, secret: true
        config_param :secret_access_key, :string, secret: true
      end

      config_param :database, :string
      config_param :table, :string
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
        options[:region] = @region
        options[:endpoint] = @endpoint if @endpoint
        options[:ssl_verify_peer] = @ssl_verify_peer
        @client = Aws::TimestreamWrite::Client.new(options)
      end

      def credential_options
        if @aws_credentials
          {
            access_key_id: @aws_credentials[:access_key_id],
            secret_access_key: @aws_credentials[:secret_access_key]
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

      def create_timstream_dimension(key, value)
        {
          dimension_value_type: 'VARCHAR',
          name: key,
          value: value
        }
      end

      def create_timestream_dimensions_and_measure(record)
        dimensions = []
        measure = {}
        record.each do |k, v|
          if @target_measure && k == @target_measure[:name]
            measure = { name: k, value: v, type: @target_measure[:type] }
            next
          end
          dimensions.push(create_timstream_dimension(k, v))
        end
        return [dimensions, measure]
      end

      def create_timestream_records(chunk)
        timestream_records = []
        chunk.each do |time, record|
          dimensions, measure = create_timestream_dimensions_and_measure(record)
          timestream_records.push(create_timestream_record(dimensions, time, measure))
        end

        log.info("write #{timestream_records.length} records")
        timestream_records
      end

      def write(chunk)
        @client.write_records(
          database_name: @database,
          table_name: @table,
          records: create_timestream_records(chunk)
        )
      rescue Aws::TimestreamWrite::Errors::RejectedRecordsException => e
        log.error(e.rejected_records)
      rescue StandardError => e
        log.error(e.message)
      end
    end
  end
end
