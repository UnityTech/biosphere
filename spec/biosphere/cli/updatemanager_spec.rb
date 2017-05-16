require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::CLI::UpdateManager do

    it "has a constructor" do
        s = Biosphere::CLI::UpdateManager.new()

        #info = s.check_for_update("0.2.0")
        #expect(info).not_to be(nil)
    end

end
