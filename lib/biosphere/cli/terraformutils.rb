require 'biosphere'
require 'colorize'

class Biosphere
    class CLI
        class TerraformUtils
            def initialize()
              
            end
            
            def move(tfstate_file, resource_type, old_name, new_name)
                if tfstate_file.nil? || resource_type.nil? || old_name.nil? || new_name.nil? 
                    puts "Can't run terraform mv without a tfstate_file, resource_type, old_resource_name and a new_resource_name"
                    puts "tfstate_file: #{tfstate_file}"
                    puts "resource_type: #{resource_type}"
                    puts "old_name: #{old_name}"
                    puts "new_name: #{new_name}"
                    exit(-1)
                end
              
                begin
                    PTY.spawn("terraform state mv -state=#{tfstate_file} #{resource_type}.#{old_name} #{resource_type}.#{new_name}") do |stdout, stdin, pid|
                        begin
                            stdout.each { |line| puts line }
                        rescue Errno::EIO
                        end
                    end
                rescue PTY::ChildExited
                    puts "The child process exited!"
                end
            end
        end
    end
end
