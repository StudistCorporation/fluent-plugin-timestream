# fluent-plugin-timestream
[![Status](https://circleci.com/gh/StudistCorporation/fluent-plugin-timestream.svg?style=shield)](https://circleci.com/gh/StudistCorporation/fluent-plugin-timestream)

Fluentd output plugin for Amazon Timestream.


## Installation
You can install it as follows:

    $ fluent-gem install fluent-plugin-timestream

## Configuration
Please refer to the [sample config file](https://github.com/StudistCorporation/fluent-plugin-timestream/blob/main/fluent.conf.sample)

## Note
The plugin ignores dimension when it has `null` or empty string value.  
e.g. `{dimension1: null, dimension2: "value", dimension3: ""}` => `{dimension2: "value"}`  
  
The Plugin ignores record when it has no dimensions.
e.g. `{dimension1: null, dimension2: "", measure: "value"}` => ignores this record  
  
The Plugin ignores record when measure specified in the config has `null` or empty value.  
e.g. `{dimension1: "value", measure: ""}` => ignores this record
  
When writing Timestream records, `TimeUnit` is always set to `SECONDS`  
  
Configuring multiple `MeasureName`s is not supported.
