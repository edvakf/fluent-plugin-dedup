# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-dedup"
  spec.version       = "0.3.0"
  spec.authors       = ["edvakf"]
  spec.email         = ["taka.atsushi@gmail.com"]
  spec.summary       = %q{fluentd plugin for removing duplicate logs}
  spec.description   = %q{fluent-plugin-dedup is a fluentd plugin to suppress emission of subsequent logs identical to the first one.}
  spec.homepage      = "https://github.com/edvakf/fluent-plugin-dedup"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "timecop"

  spec.add_runtime_dependency "fluentd"
  spec.add_runtime_dependency "lru_redux"
end
