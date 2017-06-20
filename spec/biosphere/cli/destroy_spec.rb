require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'
require 'tmpdir'


RSpec.describe Biosphere::CLI::Destroy do
  
    class S3
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
    end

    class Biosphere
        class CLI
            class TerraformUtils
              
                def initialize()

                end

                def get_plan(state_file, build_dir, deployment)
                    ""
                end

                def get_graph(build_dir, deployment)
                    ""
                end
                
                def write_plan(targets, state_file, build_dir, deployment)
                    FileUtils.touch("#{build_dir}/plan")
                    ""
                end
                
                def apply(state_file, build_dir)
                    FileUtils.touch("#{build_dir}/")
                    ""
                end
                
                def refresh(state_file, build_dir, deployment)
                    File.open(state_file, 'w') { |file| file.write('{ "modules": [{ "outputs": {} }] }') }
                    ""
                end
            end
        end 
    end

    before(:each) do
        @tmpdir = Dir.mktmpdir
        @build_dir = "#{@tmpdir}/build"
        Dir.mkdir(@build_dir)
        @dummy_suite = Biosphere::Suite.new(Biosphere::State.new())
        @dummy_suite.state.filename = "#{@build_dir}/state.node"
    end

    after(:each) do
      if @tmpdir && @tmpdir =~ /^\/tmp\/d[0-9]*/ && @tmpdir.length > 10
         FileUtils.rm_r(@tmpdir)
      end
    end

    it "can be run, generating the expected files" do
      Biosphere::Deployment.new(@dummy_suite, "testdeployment")
      Biosphere::CLI::Build.build(@dummy_suite, S3.new(), @build_dir, force: true)
      Biosphere::CLI::Destroy.destroy(@dummy_suite, S3.new(), @build_dir, "testdeployment", terraform: Biosphere::CLI::TerraformUtils.new(), force: true)
      
      expect(File.exist?(@dummy_suite.state.filename) && File.size(@dummy_suite.state.filename) > 5).to be true
      expect(Dir.exists?("#{@build_dir}/testdeployment")).to be true
      expect(File.exist?("#{@build_dir}/testdeployment/testdeployment.json.tf") && File.size("#{@build_dir}/testdeployment/testdeployment.json.tf") > 5).to be true
    end
end
