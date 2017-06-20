require 'biosphere'
require 'colorize'

class Biosphere
    class CLI
        class TerraformUtils
            def initialize()
              
            end

            def get_plan(state_file, build_dir, deployment)
              if state_file.nil? || build_dir.nil? || deployment.nil?
                  puts "Can't run get_plan without a state_file, build_dir and a deployment"
                  puts "state_file: #{state_file}"
                  puts "build_dir: #{build_dir}"
                  puts "deployment: #{deployment}"
                  exit(-1)
              end

              %x( terraform plan -state=#{state_file} #{build_dir}/#{deployment}  )
            end

            def get_graph(build_dir, deployment)
                if build_dir.nil? || deployment.nil?
                    puts "Can't run get_graph without a state_file and a deployment"
                    puts "build_dir: #{build_dir}"
                    puts "deployment: #{deployment}"
                    exit(-1)
                end

                %x( terraform graph #{build_dir}/#{deployment} )
            end
            
            def write_plan(targets, state_file, build_dir, deployment)
                if targets.nil? || state_file.nil? || build_dir.nil? || deployment.nil?
                    puts "Can't run write_plan without targets, a state_file, build_dir and a deployment"
                    puts "targest: #{targest}"
                    puts "state_file: #{state_file}"
                    puts "build_dir: #{build_dir}"
                    puts "deployment: #{deployment}"
                    exit(-1)
                end

                %x( terraform plan #{targets} -state=#{state_file} -out #{build_dir}/plan #{build_dir}/#{deployment}  )
            end
            
            def apply(state_file, build_dir)
                if state_file.nil? || build_dir.nil?
                    puts "Can't run apply without a state_file and a build_dir"
                    puts "state_file: #{state_file}"
                    puts "build_dir: #{build_dir}"
                    exit(-1)
                end
                
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
            end
            
            def refresh(state_file, build_dir, deployment)
                if state_file.nil? || build_dir.nil? || deployment.nil?
                    puts "Can't run refresh without a state_file, build_dir and a deployment"
                    puts "state_file: #{state_file}"
                    puts "build_dir: #{build_dir}"
                    puts "deployment: #{deployment}"
                    exit(-1)
                end
                
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
                
                command_output
            end
        end
    end
end
