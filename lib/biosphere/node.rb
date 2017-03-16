require 'pp'
require 'awesome_print'

class Biosphere

    class Node

        class Attribute < Hash
            def deep_set(*args)
                #puts "deep_set: #{args}"
                raise ArgumentError, "must pass at least one key, and a value" if args.length < 2
                value = args.pop
                args = args.first if args.length == 1 && args.first.kind_of?(Array)

                key = args.first
                raise ArgumentError, "must be a number" if self.kind_of?(Array) && !key.kind_of?(Numeric)

                if args.length == 1
                    self[key] = value
                else
                    child = self[key]
                    unless child.respond_to?(:store_path)
                        self[key] = self.class.new
                        child = self[key]
                    end
                    child.deep_set(args[1..-1].push, value)
                end
            end
        end

        attr_reader :data
        def initialize(from = nil)
            if from && from.is_a?(String)
                blob = Marshal.load(from)
                if blob.class == Biosphere::Node
                    raise "Tried to load old state format. Unfortunately we are not backwards compatible"
                end
                @data = blob
            elsif from
                @data = from
            else
                @data = Attribute.new
            end
        end

        def data
            return @data
        end

        def data=(s)
            @data = s
        end

        def include?(symbol)
            @data.include?(symbol)
        end

        def deep_set(*args)
            @data.deep_set(*args)
        end

        def []=(symbol, *args)
            @data[symbol] = args[0]
        end

        def [](symbol, *args)
            return @data[symbol]
        end

        def merge!(obj)
            @data.deep_merge!(obj)
        end

        def save()
            return Marshal.dump(@data)
        end

        def values
            return @data.values
        end
    end
end

module AwesomePrint
    module Node
        def self.included(base)
            base.send :alias_method, :cast_without_node, :cast
            base.send :alias_method, :cast, :cast_with_node
        end

        def cast_with_node(object, type)
            cast = cast_without_node(object, type)
            if (defined?(::Biosphere::Node)) && (object.is_a?(::Biosphere::Node))
                cast = :node_instance
            end
            cast
        end

        def awesome_node_instance(object)
            "#{object.class} #{awesome_hash(object.data)}"
        end
        
    end
end

module AwesomePrint
    module IPAddress
        def self.included(base)
            base.send :alias_method, :cast_without_ipaddress, :cast
            base.send :alias_method, :cast, :cast_with_ipaddress
        end

        def cast_with_ipaddress(object, type)
            cast = cast_without_ipaddress(object, type)
            if (defined?(::IPAddress)) && (object.is_a?(::IPAddress))
                cast = :ipaddress_instance
            end
            cast
        end

        def awesome_ipaddress_instance(object)
            "#{object.class}(#{object.to_string})"
        end
        
    end
end

AwesomePrint::Formatter.send(:include, AwesomePrint::Node)
AwesomePrint::Formatter.send(:include, AwesomePrint::IPAddress)

