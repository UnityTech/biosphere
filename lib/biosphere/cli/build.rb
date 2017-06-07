require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class Build
            def self.build(suite, s3, build_dir, localmode: false, force: false)
                
                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "Build needs a proper suite as the first argument"
                end
                
                if !s3.kind_of?(S3)
                    raise ArgumentError, "Build requires an s3 client as the second argument"
                end
                
                localmode = suite.biosphere_settings[:local] || localmode

                suite.evaluate_resources()

                if !File.directory?(build_dir)
                    STDERR.puts "Directory #{build_dir} is not a directory or it doesn't exists."
                    exit(-1)
                end

                count = 0
                suite.write_json_to(build_dir) do |file_name, destination, str, deployment|
                    puts "Wrote #{str.length} bytes from #{file_name} to #{destination} (#{deployment.export["resource"].length} resources)"
                    count = count + 1
                end

                puts "Wrote #{count} files under #{build_dir}"
                suite.state.node[:biosphere][:last_build_time] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

                suite.state.save()
                s3.save("#{build_dir}/state.node") unless localmode

            end
        end
    end
end
