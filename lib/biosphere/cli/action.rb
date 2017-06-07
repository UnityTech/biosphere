require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class Action
            def self.action(suite, s3, build_dir, action, localmode: false, force: false)
                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "Action needs a proper suite as the first argument"
                end
                
                if !s3.kind_of?(S3)
                    raise ArgumentError, "Action requires an s3 client as the second argument"
                end
                
                localmode = suite.biosphere_settings[:local] || localmode

                context = Biosphere::ActionContext.new()
                context.build_directory = build_dir

                if !action || action == "--help" || action == "-h" || action == "help"
                    puts "Syntax: biosphere action <command>"
                    puts "Available actions:"
                    suite.actions.each do |key, value|
                        puts "\t#{key}"
                    end
                    exit(-1)
                end

                if suite.call_action(ARGV[1], context)
                else
                    STDERR.puts "Could not find action #{ARGV[1]}"
                end
                suite.state.save()
                s3.save("#{build_dir}/state.node") unless localmode
            end
        end
    end
end
