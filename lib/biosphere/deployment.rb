require 'pp'
require 'awesome_print'

class Biosphere

    class Deployment

        attr_reader :node, :export, :name
        attr_accessor :state
        def initialize(*args)

            @parent = nil
            @name = "unnamed"
            if args[0].kind_of?(::Biosphere::Deployment)
                @parent = args.shift
            elsif args[0].kind_of?(String)
                @name = args.shift
            end

            settings = {}
            if args[0].kind_of?(Hash)
                puts "settings is an hash"
                settings = args.shift
            elsif args[0].kind_of?(::Biosphere::Settings)
                puts "settings is a Settings object"
                settings = (args.shift).settings
            end

            if @parent
                @node = @parent.node
                @state = @parent.state
                @export = @parent.export
                @parent.register(self)
            else
                @node = Node.new
                @node.merge!(settings)

                @export = {
                    "provider" => {},
                    "resource" => {},
                    "variable" => {},
                    "output" => {}
                }
            end

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
