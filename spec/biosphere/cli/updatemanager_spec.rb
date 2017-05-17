require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::CLI::UpdateManager do

    it "has a constructor" do

        info = Biosphere::CLI::UpdateManager::check_for_update("0.2.0")
        expect(info).not_to be(nil)
        expect(info[:up_to_date]).to eq(false)
        expect(info[:current]).to eq("0.2.0")
    end

end
