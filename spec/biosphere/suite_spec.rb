require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::Suite do

    it "has a constructor" do
        s = Biosphere::Suite.new(Biosphere::State.new)
    end

    it "can go over a list of files in a single directory" do
        s = Biosphere::Suite.new(Biosphere::State.new)
        s.load_all("spec/biosphere/suite_test1")
        s.evaluate_resources()

        expect(s.deployments["test1"].export["resource"]["type"]["name"]).to eq({:foo => "file1"})
        expect(s.deployments["test2"].export["resource"]["type"]["name"]).to eq({:foo => "file2"})
    end

    it "require_relative works with suite" do
        s = Biosphere::Suite.new(Biosphere::State.new)
        s.load_all("spec/biosphere/suite_test2")
        s.evaluate_resources()

        expect(s.deployments["TestDeployment"].export["resource"]["type"]["name1"]).to eq({:foo => "I'm Garo"})
        expect(s.deployments["TestDeployment"].export["resource"]["type"]["name2"]).to eq({:property => "test"})
    end

    it "can find action from all files" do
        s = Biosphere::Suite.new(Biosphere::State.new)
        s.load_all("spec/biosphere/suite_test1")

        expect(s.actions["one"][:name]).to eq("one")
        expect(s.actions["two"][:name]).to eq("two")
    end

    it "can write suite into a build directory" do
        s = Biosphere::Suite.new(Biosphere::State.new)
        s.load_all("spec/biosphere/suite_test1")
        s.evaluate_resources()

        if File.directory?("build")
            FileUtils.remove_dir("build")
        end
        s.write_json_to("build")
        expect(JSON.parse(IO.read("build/test1.json.tf"))["resource"]["type"]["name"]).to eq({"foo" => "file1"})
        expect(JSON.parse(IO.read("build/test2.json.tf"))["resource"]["type"]["name"]).to eq({"foo" => "file2"})

        if File.directory?("build")
            FileUtils.remove_dir("build")
        end
    end

    describe "deployments" do

        it "can load a deployment from files" do
            s = Biosphere::Suite.new(Biosphere::State.new)
            s.load_all("spec/biosphere/deployment_test/")

            deployment = s.deployments["subdeployment"]
            expect(deployment.node[:my]).to eq("sub-deployment")
        end

        it "it will evalue resources" do
            s = Biosphere::Suite.new(Biosphere::State.new)
            s.load_all("spec/biosphere/deployment_test/")
            s.evaluate_resources()
        end

    end
end
