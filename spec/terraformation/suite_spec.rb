require 'terraformation'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Terraformation::Suite do

    it "has a constructor" do
        s = Terraformation::Suite.new("spec/terraformation/suite_test1")
    end

    it "can go over a list of files in a single directory" do
        s = Terraformation::Suite.new("spec/terraformation/suite_test1")
        s.load_all()

        expect(s.files["file1.rb"].export["resource"]["type"]["name"]).to eq({:foo => "file1"})
        expect(s.files["file2.rb"].export["resource"]["type"]["name"]).to eq({:foo => "file2"})
    end

    it "require_relative works with suite" do
        s = Terraformation::Suite.new("spec/terraformation/suite_test2")
        s.load_all()

        expect(s.files["main_file.rb"].export["resource"]["type"]["name1"]).to eq({:foo => "I'm Garo"})
        expect(s.files["main_file.rb"].export["resource"]["type"]["name2"]).to eq({:property => "test"})
    end    

    it "can write suite into a build directory" do
        s = Terraformation::Suite.new("spec/terraformation/suite_test1")
        s.load_all()

        if File.directory?("build")
            FileUtils.remove_dir("build")
        end
        s.write_json_to("build")
        expect(JSON.parse(IO.read("build/file1.json.tf"))["resource"]["type"]["name"]).to eq({"foo" => "file1"})
        expect(JSON.parse(IO.read("build/file2.json.tf"))["resource"]["type"]["name"]).to eq({"foo" => "file2"})

        if File.directory?("build")
            FileUtils.remove_dir("build")
        end        
    end

end
