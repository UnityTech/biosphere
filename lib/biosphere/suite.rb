require 'pp'
require 'ipaddress'
require 'biosphere/node'

class Biosphere
    class Suite

        attr_accessor :files
        attr_accessor :actions
        attr_reader :deployments, :biosphere_settings, :state
        
        def initialize(state)

            @files = {}
            @actions = {}
            @state = state
            @deployments = {}
            @biosphere_settings = {}
            @biosphere_path = ""
        end

        def register(deployment)
            if @deployments[deployment.name]
                raise RuntimeException.new("Deployment #{deployment.name} already registered")
            end
            @deployments[deployment.name] = deployment
            if !@state.node[:deployments]
                @state.node[:deployments] = Node::Attribute.new
            end
            @state.node[:deployments][deployment.name] = Node::Attribute.new
            deployment.node = Node.new(@state.node[:deployments][deployment.name])
            #@state.node.deep_set(:deployments, deployment.name, deployment.node.data)
            deployment.state = @state

            if deployment._settings[:biosphere]
                @biosphere_settings.deep_merge!(deployment._settings[:biosphere])
            end
            
        end

        def evaluate_resources()
            @deployments.each do |name, deployment|
                deployment.evaluate_resources()
            end
        end

        def node
            @state.node
        end

        def load_all(directory)
            @directory = directory
            files = Dir::glob("#{directory}/*.rb")

            for file in files
                proxy = Biosphere::TerraformProxy.new(file, self)

                @files[file[directory.length+1..-1]] = proxy
            end
            
            @files.each do |file_name, proxy|
                proxy.load_from_file()

                proxy.actions.each do |key, value|

                    if @actions[key]
                        raise "Action '#{key}' already defined at #{value[:location]}"
                    end
                    @actions[key] = value
                end
            end

            return @files.length
        end

        def call_action(name, context)
            found = false
            @files.each do |file_name, proxy|
                if proxy.actions[name]
                    found = true
                    proxy.call_action(name, context)
                end
            end

            return found
        end

        def write_json_to(destination_dir)
            if !File.directory?(destination_dir)
                Dir.mkdir(destination_dir)
            end

            @deployments.each do |name, deployment|
                dir = destination_dir + "/" + deployment.name
                if !File.directory?(dir)
                    Dir.mkdir(dir)
                end

                json_name = deployment.name + ".json.tf"
                str = deployment.to_json(true) + "\n"
                destination_name = dir + "/" + json_name
                File.write(destination_name, str)

                yield deployment.name, destination_name, str, deployment if block_given?
            end

        end
    end
end
