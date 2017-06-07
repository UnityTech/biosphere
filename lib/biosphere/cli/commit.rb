require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class Commit
            def self.commit(suite, s3, build_dir, localmode: false, force: false)
                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "Committing needs a proper suite as the first argument"
                end
                
                if !s3.kind_of?(S3)
                    raise ArgumentError, "Committing requires an s3 client as the second argument"
                end
                
                localmode = suite.biosphere_settings[:local] || localmode
                if localmode
                    STDERR.puts "commit not supported in local mode (set in Settings :biosphere[:local] = true"
                    exit(-1)
                end

                if !ARGV[1]
                    puts "Please specify deployment name as the second parameter."
                    puts "Available deployments:"
                    suite.deployments.each do |name, deployment|
                        puts "\t#{name}"
                    end
                    exit(-1)
                end
                deployment = ARGV[1]
                if !suite.deployments[deployment]
                    puts "Deployment #{deployment} not found!"
                    puts "Available deployments:"
                    suite.deployments.each do |name, suite_deployment|
                        puts "\t#{name}"
                    end
                    exit(-1)
                end

                s3.set_lock()
                state_file = "#{build_dir}/#{deployment}.tfstate"
                s3.retrieve(state_file)
                begin
                    tf_plan_str = %x( terraform plan -state=#{state_file} #{build_dir}/#{deployment}  )
                rescue Errno::ENOENT
                    STDERR.puts "Could not find terraform. Install with with \"brew install terraform\"".colorize(:red)
                    s3.release_lock()
                end

                tf_graph_str = %x( terraform graph #{build_dir}/#{deployment} )

                tfplanning = Biosphere::CLI::TerraformPlanning.new()
                plan = tfplanning.generate_plan(suite.deployments[deployment], tf_plan_str, tf_graph_str)
                if !plan
                    STDERR.puts "Error parsing tf plan output" 
                    s3.release_lock()
                    exit
                end

                targets = plan.get_resources.collect { |x| "-target=#{x}" }.join(" ")
                puts "Targets: #{targets}"

                tf_plan_str = %x( terraform plan #{targets} -state=#{state_file} -out #{build_dir}/plan #{build_dir}/#{deployment}  )

                # Print the raw terraform output
                puts "== TERRAFORM PLAN START ==".colorize(:green)
                puts "\n" + tf_plan_str
                puts "==  TERRAFORM PLAN END  ==".colorize(:green)
                puts "\n"
                # Print our pretty short plan
                puts "Target group listing:"
                plan.print

                answer = Biosphere::CLI::Utils::ask_question("\nDoes the plan look reasonable? (Answering yes will apply the changes)", ["y", "n"], force: force)
                if answer == "n"
                    puts "\nOk, will not proceed with commit"
                elsif answer == "y"
                    puts "\nApplying the changes (this may take several minutes)"
                    begin
                        PTY.spawn("terraform apply -state-out=#{state_file} #{build_dir}/plan") do |stdout, stdin, pid|
                            begin
                              stdout.each { |line| puts line }
                            rescue Errno::EIO
                            end
                        end
                    rescue PTY::ChildExited
                        puts "The child process exited!"
                    end

                    # Refresh outputs to make sure they are available in the state file
                    command_output = ""
                    begin
                        puts "Refreshing terraform outputs"
                        PTY.spawn("terraform refresh -state=#{state_file} #{build_dir}/#{deployment}") do |stdout, stdin, pid|
                            begin
                                stdout.each { |line| command_output << line }
                            rescue Errno::EIO
                            end
                        end
                    rescue PTY::ChildExited
                        puts "Error executing terraform refresh.:\n"
                        puts command_output
                    end

                    puts "Loading outputs for #{deployment} from #{state_file}"
                    suite.deployments[deployment].load_outputs(state_file)
                    suite.state.node[:biosphere][:last_commit_time] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
                    suite.state.save()
                    s3.save(state_file)
                    s3.save("#{build_dir}/state.node")
                    #File.delete("#{build_dir}/plan")
                end

                s3.release_lock()
            end
        end
    end
end
