require 'pp'
require 'ipaddress'
require 'biosphere/node'

class Biosphere
    class State
        attr_accessor :filename, :node
        
        def initialize(filename = nil)
            if filename
                @filename = filename
                @node = Marshal.load(File.read(filename))
            else
                self.reset()
            end
        end

        def reset()
            @node = Node.new
        end

        def load(filename)
            @filename = filename
            @node = Marshal.load(File.read(filename))
        end

        def node(name=nil)
            if name
                return @node[name]
            else
                return @node
            end
        end

        def save(filename=nil)
            if !filename && @filename
                filename = @filename
            end
            str = Marshal.dump(@node)
            File.write(filename, str)
        end
    end
end
