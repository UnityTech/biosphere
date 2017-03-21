require 'pp'
require 'ipaddress'
require 'biosphere/node'
require 'deep_merge'

class Biosphere
    class State
        attr_accessor :filename, :node
        
        def initialize(filename = nil)
            if filename
                load(filename)
            else
                self.reset()
            end
        end

        def reset()
            @node = Node.new
        end

        def load(filename=nil)
            if filename
                @filename = filename
            end
            data = Marshal.load(File.read(@filename))
            #puts "Loading data from file #{@filename}: #{data}"
            load_from_structure!(data)
        end

        def node(name=nil)
            if name
                return @node[name]
            else
                return @node
            end
        end

        def merge!(settings)
            @node.merge!(settings)
        end

        def save(filename=nil)
            if !filename && @filename
                filename = @filename
            end
            str = Marshal.dump(@node)
            File.write(filename, str)
            puts "Saving state to #{filename}"
        end

        def load_from_structure!(structure)
            if @node
                @node.data.deep_merge(structure.data)
            else
                @node = structure
            end
        end
    end
end
