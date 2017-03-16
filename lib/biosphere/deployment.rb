require 'pp'
require 'awesome_print'

class Biosphere

    class Deployment

        attr_reader :export, :name, :_settings
        attr_accessor :state, :node
        def initialize(*args)

            @parent = nil
            @name = "unnamed"
            if args[0].kind_of?(::Biosphere::Deployment) || args[0].kind_of?(::Biosphere::Suite)
                @parent = args.shift
            elsif args[0].kind_of?(String)
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
            end

            @export = {
                "provider" => {},
                "resource" => {},
                "variable" => {},
                "output" => {}
            }

            if @parent.is_a?(::Biosphere::Suite)
                if settings[:deployment_name]
                    @name = settings[:deployment_name]
                else
                    puts "\nYou need to specify :deployment_name in the Deployment settings. For example:"
                    puts "cluster = AdsDeliveryCluster.new(suite, MyDeliveryTestSettings.new({deployment_name: \"my-delivery-test-cluster\"})\n\n"
                    raise RuntimeError.new "No :deployment_name specified in Deployment settings"
                end
                
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

            self.setup(settings)

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

        def resource(type, name, &block)
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

            if block_given?
                resource[:block] = block
            else
                STDERR.puts("WARNING: No block set for resource call '#{type}', '#{name}' at #{caller[0]}")
            end

            @resources << resource

        end

        def output(name, value)
            @export["output"][name] = {
                "value" => value
            }
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
                proxy.instance_eval(&resource[:block])

                @export["resource"][resource[:type].to_s][resource[:name].to_s] = proxy.output
            end

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
