require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::Suite do

    it "has a constructor" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test1")
    end

    it "can go over a list of files in a single directory" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test1")
        s.load_all()
        s.evaluate_resources()

        expect(s.files["file1.rb"].export["resource"]["type"]["name"]).to eq({:foo => "file1"})
        expect(s.files["file2.rb"].export["resource"]["type"]["name"]).to eq({:foo => "file2"})
    end

    it "require_relative works with suite" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test2")
        s.load_all()
        s.evaluate_resources()

        expect(s.files["main_file.rb"].export["resource"]["type"]["name1"]).to eq({:foo => "I'm Garo"})
        expect(s.files["main_file.rb"].export["resource"]["type"]["name2"]).to eq({:property => "test"})
    end

    it "can find action from all files" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test1")
        s.load_all()

        expect(s.actions["one"][:name]).to eq("one")
        expect(s.actions["two"][:name]).to eq("two")
    end

    it "can plan all from all files" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test2")
        s.load_all()
        s.evaluate_plans()

        expect(s.node[:plan]).to eq(true)
    end    

    it "can write suite into a build directory" do
        s = Biosphere::Suite.new("spec/biosphere/suite_test1")
        s.load_all()
        s.evaluate_resources()

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

    it "can save node from file" do
        if File.exists?("spec/biosphere/suite_node_save/state.node")
            File.delete("spec/biosphere/suite_node_save/state.node")
        end

        s = Biosphere::Suite.new("spec/biosphere/suite_node_save")
        s.load_all()

        s.save_node("state.node")

        expect(File.exists?("spec/biosphere/suite_node_save/state.node")).to eq(true)
    end

    it "can load node from file automatically" do
        s = Biosphere::Suite.new("spec/biosphere/suite_node_load")
        expect(s.node[:foo]).to eq("bar")
    end

end
