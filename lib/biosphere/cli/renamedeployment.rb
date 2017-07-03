require 'biosphere'
require 'pp'
require "awesome_print"
require 'colorize'
require 'biosphere/s3.rb'
require 'pty'

class Biosphere
    class CLI
        class RenameDeployment
            def self.renamedeployment(suite, s3, build_dir, deployment, new_name, terraform: Biosphere::CLI::TerraformUtils.new(), localmode: false, force: false)

                if !suite.kind_of?(::Biosphere::Suite)
                    raise ArgumentError, "RenameDeployment needs a proper suite as the first argument"
                end

                if !s3.kind_of?(S3)
                    raise ArgumentError, "RenameDeployment requires an s3 client as the second argument"
                end

                localmode = suite.biosphere_settings[:local] || localmode

                if !deployment
                    puts "Please specify deployment name as the second parameter."
                    puts "Available deployments:"
                    suite.deployments.each do |name, deployment|
                        puts "\t#{name}"
                    end
                    exit(-1)
                end

                if !new_name
                    puts "Please specify the new name as the third parameter."
                    exit(-1)
                end

                if !suite.deployments[deployment]
                    puts "Deployment #{deployment} doesn't exist in the current suite".colorize(:red)
                    exit(-1)
                elsif suite.deployments[new_name]
                    puts "The current suite already contains a deployment called #{new_name}".colorize(:red)
                    exit(-1)
                end

                puts "Renaming #{deployment} to #{new_name}"

                suite.deployments[deployment].all_resources.each do |r|
                    r[:new_name] = r[:name].sub(deployment,new_name)
                end

                state_file = "#{build_dir}/#{deployment}.tfstate"
                suite.deployments[deployment].all_resources.each do |r|
                    terraform.move(state_file, r[:type], r[:name], r[:new_name])
                    r[:name] = r[:new_name]
                    r.delete(:new_name)
                end
                suite.state.node[:deployments][new_name] = suite.state.node[:deployments].delete(deployment)

                puts "State renaming done!".colorize(:green)
                puts "Remember to change the deployment name in the deployment specifications too!".colorize(:yellow)

                count = 0
                suite.write_json_to(build_dir) do |file_name, destination, str, suite_deployment|
                    puts "Wrote #{str.length} bytes from #{file_name} to #{destination} (#{suite_deployment.export["resource"].length} resources)"
                    count = count + 1
                end

                puts "Wrote #{count} files under #{build_dir}"

                unless suite.state.node[:biosphere].nil?
                    suite.state.node[:biosphere][:last_build_time] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
                end

                FileUtils.mv("#{build_dir}/#{deployment}.tfstate", "#{build_dir}/#{new_name}.tfstate")
                suite.state.save()
                s3.save("#{build_dir}/state.node") unless localmode
                s3.delete_object("#{build_dir}/#{deployment}.tfstate") unless localmode
                s3.save("#{build_dir}/#{new_name}.tfstate") unless localmode
            end
        end
    end
end
