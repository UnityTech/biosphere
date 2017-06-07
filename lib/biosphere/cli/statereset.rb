require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class StateReset
            def self.statereset(suite, s3, build_dir, localmode: false, force: false)
                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "StateReset needs a proper suite as the first argument"
                end
                
                if !s3.kind_of?(S3)
                    raise ArgumentError, "StateReset requires an s3 client as the second argument"
                end
                
                localmode = suite.biosphere_settings[:local] || localmode
                
                answer = Biosphere::CLI::Utils::ask_question("\nAre you sure you want to do a full state reset for #{build_dir}", ["y", "n"], force: force)
                if answer == "n"
                    puts "\nOk, will not proceed with state reset"
                elsif answer == "y"
                    state = Biosphere::State.new
                    state.filename = "#{build_dir}/state.node"
                    state.save()
                    s3.save("#{build_dir}/state.node") unless localmode
                    suite.deployments.each do |name, deployment|
                        s3.delete_object("#{name}.tfstate")
                    end
                end
            end
        end
    end
end
