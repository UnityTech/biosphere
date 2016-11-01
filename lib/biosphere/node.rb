require 'pp'

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
    end
end