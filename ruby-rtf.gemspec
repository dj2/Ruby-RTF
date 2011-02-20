$: << "./lib"
require 'ruby-rtf/version'

Gem::Specification.new do |s|
  s.name = 'ruby-rtf'

  s.version = RubyRTF::VERSION

  s.authors = 'dan sinclair'
  s.email = 'dj2@everburning.com'

  s.homepage = 'http://github.com/dj2/ruby-rtf'
  s.summary = 'Library for working with RTF files'
  s.description = s.summary

  s.add_development_dependency 'ZenTest'
  s.add_development_dependency 'rspec', '>2.0'
  s.add_development_dependency 'metric_fu'

  s.add_development_dependency 'yard'
  s.add_development_dependency 'bluecloth'

  s.bindir = 'bin'
  s.executables << 'rtf_parse'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- spec/*`.split("\n")

  s.require_paths = ['lib']
end