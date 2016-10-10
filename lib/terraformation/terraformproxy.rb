require 'terraformation/mixing/from_file.rb'
require 'json'

class Terraformation
    class ResourceProxy
        attr_reader :output

        def initialize()
            @output = {}
        end

        def method_missing(symbol, *args)

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

        attr_accessor :output
        attr_reader :output

        def initialize(script_name)
            @script_name = script_name
            @output = {
                "provider" => {},
                "resource" => {}
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
            @output["provider"][name.to_s] = spec
        end

        def resource(type, name, spec={}, &block)
            @output["resource"][type.to_s] ||= {}
            if @output["resource"][type.to_s][name.to_s]
                throw "Tried to create a resource of type #{type} called '#{name}' when one already exists"
            end

            if block_given?
                proxy = ResourceProxy.new
                proxy.instance_eval(&block)

                proxy.output.each do |key, value|
                    spec[key] = value
                end

            end

            @output["resource"][type.to_s][name.to_s] = spec

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
                return JSON.pretty_generate(@output)
            else
                return JSON.generate(@output)
            end
        end
    end
end

#at_exit do
#  require 'json'
#  puts JSON.pretty_generate(@output)
#end
