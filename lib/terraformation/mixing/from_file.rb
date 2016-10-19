
class Terraformation
    module Mixing
        module FromFile
            def from_file(filename)

                if File.exists?(filename) && File.readable?(filename)
                    self.instance_eval(IO.read(filename), filename, 1)
                else
                    raise IOError, "Cannot open or read #{filename}!"
                end
            end
            
        end
    end
end
