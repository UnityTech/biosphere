require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'
require 'tmpdir'


RSpec.describe Biosphere::CLI::RenameDeployment do

    class S3Mock
      def initialize(*args)

      end

      def retrieve(path)
        puts "Retrieved #{path}"
      end

      def set_lock()
        puts "lock set"
      end

      def release_lock()
        puts "lock released"
      end

      def save(file)
        puts "saved #{file}"
      end
      
      def delete_object(file)
        "deleted #{file}"
      end

      def kind_of?(o)
        o == S3
      end
    end

    class TerraformUtilsMock
        attr_reader :move_calls
        def initialize()
            @move_calls = 0
        end

        def move(state_file, resource_type, old_name, new_name)
            @move_calls = @move_calls + 1
            "moving"
        end
    end

    before(:each) do
        @tmpdir = Dir.mktmpdir
        @build_dir = "#{@tmpdir}/build"
        Dir.mkdir(@build_dir)
        @dummy_suite = Biosphere::Suite.new(Biosphere::State.new())
        @dummy_suite.state.filename = "#{@build_dir}/state.node"
        FileUtils.touch("#{@build_dir}/testdeployment.tfstate")
    end

    after(:each) do
      if @tmpdir && @tmpdir =~ /^\/tmp\/d[0-9]*/ && @tmpdir.length > 10
         FileUtils.rm_r(@tmpdir)
      end
    end

    it "can be run, generating the expected files" do
      Biosphere::Deployment.new(@dummy_suite, "testdeployment").resource "test_resource", "foo" do
            set :name, "test1"
      end

      expect(@dummy_suite.state.node[:deployments]["testdeployment"]).to_not eq(nil)

      tfmock = TerraformUtilsMock.new()
      Biosphere::CLI::RenameDeployment.renamedeployment(@dummy_suite, S3Mock.new(), @build_dir, "testdeployment", "newdeployment", terraform: tfmock)

      expect(tfmock.move_calls).to be(1)
      expect(@dummy_suite.deployments.length).to be(1)
      expect(@dummy_suite.state.node[:deployments]["testdeployment"]).to eq(nil)
      expect(@dummy_suite.state.node[:deployments]["newdeployment"]).to_not eq(nil)
      expect(File.exists?("#{@build_dir}/testdeployment.tfstate")).to be(false)
      expect(File.exists?("#{@build_dir}/newdeployment.tfstate")).to be(true)
    end
end
