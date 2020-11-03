# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "huginn_acumen_product_agent"
  spec.version       = "1.6.1"
  spec.authors       = ["Jacob Spizziri"]
  spec.email         = ["jacob.spizziri@gmail.com"]

  spec.summary       = %q{Huginn agent for sane ACUMEN product data.}
  spec.description   = %q{The Huginn ACUMEN Product Agent takes in an array of ACUMEN product ID's, queries the relevant ACUMEN tables, and emits a set of events with a sane data interface for each those events.}

  spec.homepage      = "https://github.com/5-Stones/huginn_acumen_product_agent"

  spec.license       = "MIT"


  spec.files         = Dir['LICENSE.txt', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = Dir['spec/**/*.rb'].reject { |f| f[%r{^spec/huginn}] }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "huginn_agent"
end
