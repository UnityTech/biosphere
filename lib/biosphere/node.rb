require 'pp'
require 'awesome_print'

class Biosphere
    class Node
        attr_reader :data
        def initialize(from_string = nil)
            if from_string
                blob = Marshal.load(from_string)
                @data = blob.data
            else
                @data = {}
            end
        end

        def include?(symbol)
            @data.include?(symbol)
        end

        def []=(symbol, *args)
            @data[symbol] = args[0]
        end

        def [](symbol, *args)
            if !@data[symbol]
                @data[symbol] = Node.new
            end
            return @data[symbol]
        end

        def save()
            return Marshal.dump(self)
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

