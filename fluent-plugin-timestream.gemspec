# frozen_string_literal: true

require_relative 'lib/fluent/plugin/timestream/version'

Gem::Specification.new do |spec|
  spec.name          = 'fluent-plugin-timestream'
  spec.version       = Fluent::Plugin::Timestream::VERSION
  spec.authors       = ['Studist Corporation']

  spec.summary       = 'Fluentd output plugin which writes Amazon Timestream record.'
  spec.license       = 'MIT'

  spec.metadata['source_code_uri'] = 'https://github.com/StudistCorporation/fluent-plugin-timestream'
  spec.metadata['changelog_uri'] = 'https://github.com/StudistCorporation/fluent-plugin-timestream/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = ">= 2.6.3"
  spec.add_dependency "aws-sdk-timestreamwrite", ">=1.2.0"
  spec.add_dependency "fluentd", ">= 1.11.0"

  spec.add_development_dependency "net-empty_port", ">= 0.0.2"
  spec.add_development_dependency "test-unit", ">= 3.3.9"
  spec.add_development_dependency "webrick", ">= 1.4.2"
end
