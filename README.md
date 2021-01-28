# fluent-plugin-timestream

Fluentd output plugin for Amazon Timestream.


## Installation
You can install it as follows:

    $ fluent-gem install fluent-plugin-timestream

## Configuration

```
<source>
  @type tail
  format ltsv
  path /path/to/sample.log
  pos_file /tmp/sample.pos
  tag "sample.log"
</source>

<match sample.log>
  @type timestream

  database "sampleDB"
  table "sampleTable"
  region "us-east-1"

  # <aws_credentials>
  #   access_key_id "XXXXXXXXX"
  #   secret_access_key "XXXXXXXXXX"
  # </aws_credentials>

  # Specify which key should be 'measure'.
  # If not, plugin sends dummy measure and writes all keys and values as dimensions.
  # Dummy measure is as follows:
  #   MeasureName: '-'
  #   MeasureValue: '-'
  #   MeasureValueType: 'VARCHAR'
  #<measure>
  #  name "measureNameXXX"
  #  type "VARCHAR"
  #</measure>

  # 'chunk_limit_records' must be configured less or equal to 100.
  # If not, plugin may fails to write record.
  # For now, Plugin sends records in buffer all at once.
  # However Amazon Timestream currently accepts less or equal to 100 records.

  <buffer>
    chunk_limit_records 100
  </buffer>

</match>
```