require 'pp'
require 'awesome_print'

class Biosphere

    class Deployment

        attr_reader :export, :name, :_settings, :feature_manifests, :target_groups, :resources
        attr_accessor :state, :node
        def initialize(*args)

            @parent = nil
            @name = ""
            if args[0].kind_of?(::Biosphere::Deployment) || args[0].kind_of?(::Biosphere::Suite)
                @parent = args.shift
            end
            if args[0].kind_of?(String)
                @name = args.shift
            end

            settings = {}
            @_settings = {}
            if args[0].kind_of?(Hash)
                settings = args.shift
                @_settings = settings
            elsif args[0].kind_of?(::Biosphere::Settings)
                @_settings = args.shift
                settings = @_settings.settings
                @feature_manifests = @_settings.feature_manifests
            end


            @export = {
                "provider" => {},
                "resource" => {},
                "variable" => {},
                "output" => {}
            }

            settings[:deployment_name] = @name

            if @parent.is_a?(::Biosphere::Suite)
                @parent.register(self)
            elsif @parent
                @node = @parent.node
                @state = @parent.state
                @export = @parent.export
                @parent.register(self)
                
            else
                @node = Node.new
            end

            @delayed = []
            @resources = []
            @actions = {}
            @deployments = []
            @outputs = []
            @target_groups = {}

            if @feature_manifests
                node[:feature_manifests] = @feature_manifests
            end

            self.setup(settings)

        end

        def add_resource_to_target_group(resource_type, resource_name, target_group)
            name = resource_type + "." + resource_name
            (@target_groups[target_group] ||= []) << name
        end

        def setup(settings)
        end

        def node
            return @node
        end

        def state
            if @state != nil
                return @state
            end

            if @parent
                return @parent.state
            end
        end

        def register(deployment)
            @deployments << deployment
        end

        def variable(name, value)
            @export["variable"][name] = {
                "default" => value
            }
        end
        
        def provider(name, spec={})
            @export["provider"][name.to_s] = spec
        end

        def delayed(&block)
            delayed_call = {
                :block => block
            }
            @delayed << delayed_call
        end

        def resource(type, name, target_group = nil, &block)
            if self.name
                name = self.name + "_" + name
            end
            @export["resource"][type.to_s] ||= {}
            if @export["resource"][type.to_s][name.to_s]
                throw "Tried to create a resource of type #{type} called '#{name}' when one already exists"
            end

            spec = {}
            resource = {
                :name => name,
                :type => type,
                :location => caller[0] + "a"
            }

            if target_group
                add_resource_to_target_group(type, name, target_group)
            end

            if block_given?
                resource[:block] = block
            else
                #STDERR.puts("WARNING: No block set for resource call '#{type}', '#{name}' at #{caller[0]}")
            end

            @resources << resource

        end

        def output(name, value, &block)
            if self.name
                resource_name = self.name + "_" + name
            else
                resource_name = name
            end

            @export["output"][resource_name] = {
                "value" => value
            }

            if block_given?
                output = {
                    :name => name,
                    :resource_name => resource_name,
                    :block => block
                }

                @outputs << output
            end
        end

        def evaluate_outputs(outputs)

            # Call first sub-deployments
            @deployments.each do |deployment|
                deployment.evaluate_outputs(outputs)
            end
            
            @outputs.each do |output|
                begin
                    value = outputs[output[:resource_name]]
                    instance_exec(self.name, output[:name], value["value"], value, &output[:block])
                rescue NoMethodError => e
                    STDERR.puts "Error evaluating output #{output}. error: #{e}"
                    puts "output:"
                    pp output
                    puts "value:"
                    pp value
                    puts "outputs:"
                    pp outputs
                    STDERR.puts "This is an internal error. You should be able to run biosphere commit again to try to fix this."
                end
            end
        end

        def load_outputs(tfstate_filename)

            begin
                tf_state = JSON.parse(File.read(tfstate_filename))
            rescue SystemCallError
                puts "Couldn't read Terraform statefile, can't continue"
                exit
            end

            outputs = tf_state["modules"].first["outputs"]
            if outputs.length == 0
                STDERR.puts "WARNING: No outputs found from the terraform state file #{tfstate_filename}. This might be a bug in terraform."
                STDERR.puts "Try to run \"biosphere commit\" again."
            else
                evaluate_outputs(outputs)
            end
        end

        def evaluate_resources()

            # Call first sub-deployments
            @deployments.each do |deployment|
                deployment.evaluate_resources()
            end

            # Then all delayed calls
            @delayed.each do |delayed_call|
                proxy = ResourceProxy.new(self)
                proxy.instance_eval(&delayed_call[:block])
            end

            # And finish with our own resources
            @resources.each do |resource|
                proxy = ResourceProxy.new(self)
                if resource[:block]
                    proxy.instance_eval(&resource[:block])
                end

                @export["resource"][resource[:type].to_s][resource[:name].to_s] = proxy.output
            end
        end

        def id_of(type,name)
            "${#{type}.#{name}.id}"
        end

        def output_of(type, name, *values)
            if self.name
                name = self.name + "_" + name
            end
            "${#{type}.#{name}.#{values.join(".")}}"
        end

        def to_json(pretty=false)
            if pretty
                return JSON.pretty_generate(@export)
            else
                return JSON.generate(@export)
            end
        end
        
    end
end
