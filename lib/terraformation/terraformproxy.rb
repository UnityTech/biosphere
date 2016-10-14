require 'terraformation/mixing/from_file.rb'
require 'json'

class Terraformation
    class ResourceProxy
        attr_reader :output

        def initialize()
            @output = {}
        end

        def method_missing(symbol, *args)
            #puts "method missing: #{symbol}, #{args}"

            # Support getter here
            if args.length == 0
                return @output[symbol]
            end

            # Support setter here
            if [:ingress, :egress].include?(symbol)
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


        def initialize(script_name)
            @script_name = script_name
            @export = {
                "provider" => {},
                "resource" => {},
                "variable" => {},
                "output" => {}
            }

        end

        def load_from_file()
            self.from_file(@script_name)
        end

        def load_from_block(&block)
            self.instance_eval(&block)
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

        def resource(type, name, spec={}, &block)
            @export["resource"][type.to_s] ||= {}
            if @export["resource"][type.to_s][name.to_s]
                throw "Tried to create a resource of type #{type} called '#{name}' when one already exists"
            end

            if block_given?
                proxy = ResourceProxy.new
                proxy.instance_eval(&block)

                proxy.output.each do |key, value|
                    spec[key] = value
                end

            end

            @export["resource"][type.to_s][name.to_s] = spec

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

#at_exit do
#  require 'json'
#  puts JSON.pretty_generate(@export)
#end
