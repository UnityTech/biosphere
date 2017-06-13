require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'
require 'fakefs'

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

RSpec.describe Biosphere::CLI::Commit do

    before(:each) do
        @build_dir = "spec/biosphere/suite_test1/build"
        @dummy_suite = Biosphere::Suite.new(Biosphere::State.new())
        @dummy_suite.state.filename = "#{@build_dir}/state.node"
    end

    it "be run" do
        FakeFS do
            FileUtils.mkdir_p("#{@build_dir}/testdeployment")
            puts FileUtils.pwd()
            d = Biosphere::Deployment.new(@dummy_suite, "testdeployment")
            Biosphere::CLI::Action::action(@dummy_suite, S3.new(), @build_dir, "certs")
            Biosphere::CLI::Build.build(@dummy_suite, S3.new(), @build_dir, force: true)
            c = Biosphere::CLI::Commit.commit(@dummy_suite, S3.new(), @build_dir, "testdeployment", force: true)
            expect(c).to eq(nil)
        end
    end
end
