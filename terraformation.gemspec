$:.unshift(File.dirname(__FILE__) + '/lib')

require 'terraformation/version'

Gem::Specification.new do |s|
  s.name    = 'terraformation'
  s.files = Dir['lib/**/*'] + Dir['{bin,spec,examples}/*', 'README*']
  s.version = Terraformation::Version
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.platform    = Gem::Platform::RUBY
  s.summary = "Tool to write terraform files with a Ruby DSL"
  s.description = "Terraform's HCL lacks quite many programming features like iterators, true variables, advanced string manipulation, functions etc.

  This Ruby tool provides an easy-to-use DSL to define Terraform compatible .json files which can then be used with Terraform side-by-side with HCL files.
  "

  s.author = "Juho Mäkinen"
  s.email = "juho@unity3d.com"
  s.homepage    = "http://github.com/garo/ocular"
  s.licenses = ["MIT"]
  s.require_path = 'lib'
  s.executables << "terraformation"
  s.add_development_dependency('rspec', '3.4.0')
