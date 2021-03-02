# fluent-plugin-timestream
[![Status](https://circleci.com/gh/StudistCorporation/fluent-plugin-timestream.svg?style=shield)](https://circleci.com/gh/StudistCorporation/fluent-plugin-timestream)

Fluentd output plugin for Amazon Timestream.


## Installation
You can install it as follows:

    $ fluent-gem install fluent-plugin-timestream

## Configuration
Please refer to the [sample config file](https://github.com/StudistCorporation/fluent-plugin-timestream/blob/main/fluent.conf.sample)

## Note
The plugin ignores `null` and empty string values in the log.  
e.g. `{key1: null, key2: "value", key3: ""}` => `{key2: "value"}`  
  
When writing Timestream records, `TimeUnit` is always set to `SECONDS`  
  
Configuring multiple `MeasureName`s is not supported.
