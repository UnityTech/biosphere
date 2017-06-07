require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class Destroy
            def self.destroy(suite, s3, build_dir, deployment, localmode: false, force: false)
                
                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "Destroy needs a proper suite as the first argument"
                end
                
                if !s3.kind_of?(S3)
                    raise ArgumentError, "Destroy requires an s3 client as the second argument"
                end
                
                localmode = suite.biosphere_settings[:local] || localmode
                if localmode
                    STDERR.puts "destroy not supported in local mode (set in Settings :biosphere[:local] = true"
                    exit(-1)
                end

                if !deployment
                    puts "Please specify deployment name as the second parameter."
                    puts "Available deployments:"
                    suite.deployments.each do |name, suite_deployment|
                        puts "\t#{name}"
                    end
                    exit(-1)
                end

                s3.set_lock()
                s3.retrieve("#{build_dir}/#{deployment}.tfstate")
                answer = Biosphere::CLI::Utils::ask_question("\nYou are about to destroy deployment #{deployment}? (Answering yes will nuke it from the orbit)", ["y", "n"], force: force)
                if answer == "n"
                    puts "\nAborted!"
                elsif answer == "y"
                    puts "\nDestroying deployment #{deployment} (this may take several minutes)"
                    tf_apply = %x( terraform destroy -force -state=#{build_dir}/#{deployment}.tfstate #{build_dir})
                    puts "\n" + tf_apply
                    s3.save("#{build_dir}/#{deployment}.tfstate")
                    s3.save("#{build_dir}/state.node")
                end

                s3.release_lock()
            end
        end
    end
end
