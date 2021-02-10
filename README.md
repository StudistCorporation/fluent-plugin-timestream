# fluent-plugin-timestream
Fluentd output plugin for Amazon Timestream.


## Installation
You can install it as follows:

    $ fluent-gem install fluent-plugin-timestream

## Configuration
Please refer to the [sample config file](https://github.com/StudistCorporation/fluent-plugin-timestream/blob/main/fluent.conf.sample)

## Note
The plugin converts `null` values in the log to empty string.  
e.g. `{key_name: null}` => `{key_name: ""}`  
  
When write Timestream records, TimeUnit is always set `SECONDS`  
  
Configure multiple MeasureName is not supported.