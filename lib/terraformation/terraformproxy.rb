require 'terraformation/mixing/from_file.rb'
require 'json'
require 'pathname'

class Terraformation
    class ActionContext
        attr_accessor :build_directory
        attr_accessor :caller

        def initialize()

        end

        def method_missing(symbol, *args)
            #puts ">>>>>>>> method missing: #{symbol}, #{args}"

            if @caller.methods.include?(symbol)
                return @caller.method(symbol).call(*args)
            end
        end

        
    end

    
    class PlanProxy
        attr_accessor :node
        def initialize()
            @node = Node.new
        end

    end

    class ResourceProxy
        attr_reader :output
        attr_reader :caller

        def initialize(caller)
            @output = {}
            @caller = caller
        end


        def respond_to?(symbol, include_private = false)
            return true
        end

        def method_missing(symbol, *args)
            #puts ">>>>>>>> method missing: #{symbol}, #{args}"

            if @caller.methods.include?(symbol)
                return @caller.method(symbol).call(*args)
            end

            # Support getter here
            if args.length == 0
                return @output[symbol]
            end

            # Support setter here
            if [:ingress, :egress, :route].include?(symbol)
                @output[symbol] ||= []
                if args[0].kind_of?(Array)
                    @output[symbol] += args[0]
                else
                    @output[symbol] << args[0]
                end
            else
                @output[symbol] = args[0]
            end
        end
    end

    class TerraformProxy

        attr_accessor :export
        attr_accessor :resources
        attr_accessor :actions
        attr_accessor :plans
        attr_accessor :plan_proxy
        attr_reader :src_path


        def initialize(script_name, plan_proxy = nil)
            @script_name = script_name
            @src_path = [File.dirname(script_name)]

            @export = {
                "provider" => {},
                "resource" => {},
                "variable" => {},
                "output" => {}
            }
            if !plan_proxy
                plan_proxy = PlanProxy.new
            end
            @plan_proxy = plan_proxy
            @resources = []
            @actions = {}
            @plans = []

        end

        def load_from_file()
            self.from_file(@script_name)
        end

        def load_from_block(&block)
            self.instance_eval(&block)
        end

        def load(filename)
            src_path = Pathname.new(@src_path.last + "/" + File.dirname(filename)).cleanpath.to_s
            # Push current src_path and overwrite @src_path so that it tracks recursive loads
            @src_path << src_path
            
            #puts "Trying to open file: " + src_path + "/" + File.basename(filename)
            if File.exists?(src_path + "/" + File.basename(filename))
                self.from_file(src_path + "/" + File.basename(filename))
            elsif File.exists?(src_path + "/" + File.basename(filename) + ".rb")
                self.from_file(src_path + "/" + File.basename(filename) + ".rb")
            else
                raise "Can't find #{filename}"
            end

            # Restore it as we are unwinding the call stack
            @src_path.pop
        end


        include Terraformation::Mixing::FromFile

        def provider(name, spec={})
            @export["provider"][name.to_s] = spec
        end

        def variable(name, value)
            @export["variable"][name] = {
                "default" => value
            }
        end

        def output(name, value)
            @export["output"][name] = {
                "value" => value
            }
        end

        def action(name, description, &block)
            @actions[name] = {
                :name => name,
                :description => description,
                :block => block,
                :location => caller[0]
            }
        end

        def plan(name, &block)
            plan = {
                :name => name,
                :block => block,
                :location => caller[0]
            }
            @plans << plan
        end

        def node
            return @plan_proxy.node
        end        
        
        def evaluate_plans()
            @plans.each do |resource|
                @plan_proxy.instance_eval(&resource[:block])
            end
            
        end

        def call_action(name, context)
            context.caller = self

            context.instance_eval(&@actions[name][:block])
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

        def evaluate_resources()
            @resources.each do |resource|
                proxy = ResourceProxy.new(self)
                proxy.instance_eval(&resource[:block])

                @export["resource"][resource[:type].to_s][resource[:name].to_s] = proxy.output
            end
        end

        def id_of(type,name)
            "${#{type}.#{name}.id}"
        end

        def output_of(type, name, *values)
            "${#{type}.#{name}.#{values.join(".")}}"
        end

        def add_resource_alias(type)
            define_singleton_method type.to_sym do |name, spec={}|
              resource(type, name, spec)
            end
        end

        def use_resource_shortcuts!
            require_relative 'resource_shortcuts'
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
