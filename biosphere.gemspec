$:.unshift(File.dirname(__FILE__) + '/lib')

require 'biosphere/version'

Gem::Specification.new do |s|
  s.name    = 'biosphere'
  s.files = Dir['lib/**/*'] + Dir['{bin,spec,examples}/*', 'README*']
  s.version = Biosphere::Version
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.platform    = Gem::Platform::RUBY
  s.summary = "Tool to provision VPC with Terraform with a Ruby DSL"
  s.description = "Terraform's HCL lacks quite many programming features like iterators, true variables, advanced string manipulation, functions etc.

  This Ruby tool provides an easy-to-use DSL to define Terraform compatible .json files which can then be used with Terraform side-by-side with HCL files.
  "

  s.author = "Juho Mäkinen"
  s.email = "juho@unity3d.com"
  s.homepage    = "http://github.com/UnityTech/biosphere"
  s.licenses = ["MIT"]
  s.require_path = 'lib'
  s.executables << "biosphere"
  s.add_development_dependency('rspec', '3.4.0')
  s.add_dependency('ipaddress', '0.8.3')
  s.add_dependency('awesome_print', '1.7.0')
end
