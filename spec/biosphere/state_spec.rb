require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::State do

    it "has a constructor" do
        s = Biosphere::State.new()
        s.node[:foo] = "bar"
        expect(s.node()[:foo]).to eq("bar")
        
    end


    it "can save state to file" do
        if File.exists?("spec/biosphere/state_save/state.node")
            File.delete("spec/biosphere/state_save/state.node")
        end

        s = Biosphere::State.new
        s.node[:foo] = "bar"
        s.save("spec/biosphere/state_save/state.node")

        expect(File.exists?("spec/biosphere/state_save/state.node")).to eq(true)
    end

    it "can load state from file automatically" do
        s = Biosphere::State.new("spec/biosphere/state_save/state.node")
        expect(s.node[:foo]).to eq("bar")
    end
    
end
