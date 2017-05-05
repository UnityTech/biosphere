require 'biosphere/mixing/from_file.rb'
require 'biosphere/kube.rb'
require 'json'
require 'pathname'
require 'base64'
require 'zlib'

class Biosphere
    class ActionContext
        attr_accessor :build_directory
        attr_accessor :caller
        attr_accessor :src_path

        def initialize()

        end

        def state
            return @caller.state.node
        end

        def method_missing(symbol, *args)
            #puts ">>>>>>>> method missing: #{symbol}, #{args}"

            if @caller.methods.include?(symbol)
                return @caller.method(symbol).call(*args)
            end

            super
        end

        def find_file(filename)
            src_path = Pathname.new(@src_path.last + "/" + File.dirname(filename)).cleanpath.to_s
            return src_path + "/" + File.basename(filename)
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

        def set(symbol, value)

            # Support setter here
            if [:ingress, :egress, :route].include?(symbol)
                @output[symbol] ||= []
                if value.kind_of?(Array)
                    @output[symbol] += value
                else
                    @output[symbol] << value
                end
            else
                @output[symbol] = value
            end

            if symbol === :user_data
              @output[symbol] = Base64.strict_encode64(Zlib::Deflate.new(nil, 31).deflate(value, Zlib::FINISH))
            end
        end

        def get(symbol)
            return @output[symbol]
        end

        def node
            return @caller.node
        end

        def state
            return @caller.state.node
        end

        def id_of(type,name)
            if self.name
                name = self.name + "_" + name
            end
            "${#{type}.#{name}.id}"
        end

        def output_of(type, name, *values)
            if self.name
                name = self.name + "_" + name
            end
            
            "${#{type}.#{name}.#{values.join(".")}}"
        end

        def method_missing(symbol, *args)
            return @caller.method(symbol).call(*args)
        end
    end

    class TerraformProxy

        attr_accessor :export
        attr_accessor :resources
        attr_accessor :actions
        attr_reader :src_path

        include Kube


        def initialize(script_name, suite)
            @script_name = script_name
            @src_path = [File.dirname(script_name)]

            @export = {
                "provider" => {},
                "resource" => {},
                "variable" => {},
                "output" => {}
            }
            @suite = suite
            @actions = {}
            @deployments = []

        end

        def register(deployment)
            @suite.register(deployment)
        end

        def load_from_file()
            self.from_file(@script_name)
        end

        def load_from_block(&block)
            self.instance_eval(&block)
        end

        def find_file(filename)
            src_path = Pathname.new(@src_path.last + "/" + File.dirname(filename)).cleanpath.to_s
            return src_path + "/" + File.basename(filename)
        end

        def find_dir(dirname)
            return Pathname.new(@src_path.last).cleanpath.to_s
        end

        def load(filename)
            src_path = Pathname.new(@src_path.last + "/" + File.dirname(filename)).cleanpath.to_s
            # Push current src_path and overwrite @src_path so that it tracks recursive loads
            @src_path << src_path
            $current_biosphere_path_stack = src_path

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
            $current_biosphere_path_stack = @src_path.last
        end

        include Biosphere::Mixing::FromFile

        def action(name, description, &block)
            @actions[name] = {
                :name => name,
                :description => description,
                :block => block,
                :location => caller[0],
                :src_path => @src_path.clone
            }
        end

        def call_action(name, context)
            context.caller = self
            context.src_path = @actions[name][:src_path]

            context.instance_eval(&@actions[name][:block])
        end

        def id_of(type,name)
            "${#{type}.#{name}.id}"
        end

        def output_of(type, name, *values)
            "${#{type}.#{name}.#{values.join(".")}}"
        end

        def state
            return @suite.state
        end

        def suite
            return @suite
        end
    end

end
