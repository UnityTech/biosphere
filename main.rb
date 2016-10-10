
require 'terraformation'

setup = Terraformation::Suite.new('example.rb')



a.from_file("terrafied/example.rb")
puts a.to_json