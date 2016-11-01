require 'pp'
require 'ipaddress'
require 'biosphere/node'

class Biosphere
	class Suite

		attr_accessor :files
		attr_accessor :actions

		def initialize(directory)

			@files = {}
			@actions = {}
			@directory = directory

			files = Dir::glob("#{directory}/*.rb")

			@plan_proxy = PlanProxy.new

			for file in files
				proxy = Biosphere::TerraformProxy.new(file, @plan_proxy)

				@files[file[directory.length+1..-1]] = proxy
			end

			if File.exists?(directory + "/state.node")
				@plan_proxy.node = Marshal.load(File.read(directory + "/state.node"))
			end
		end

		def node(name=nil)
			if name
				return @plan_proxy.node[name]
			else
				return @plan_proxy.node
			end
		end


		def evaluate_resources()
			@files.each do |file_name, proxy|
				proxy.evaluate_resources()
			end
		end

		def load_all()
			@files.each do |file_name, proxy|
				proxy.load_from_file()

				proxy.actions.each do |key, value|

					if @actions[key]
						raise "Action '#{key}' already defined at #{value[:location]}"
					end
					@actions[key] = value
				end
			end
		end

		def save_node(filename = "state.node")
			str = Marshal.dump(@plan_proxy.node)
			File.write(@directory + "/" + filename, str)
		end


		def evaluate_plans()
			@files.each do |file_name, proxy|
				puts "evaluating plans for #{file_name}"
				
				proxy.evaluate_plans()
			end
		end

		def call_action(name, context)
			@files.each do |file_name, proxy|
				if proxy.actions[name]
					proxy.call_action(name, context)
				end
			end
		end

		def write_json_to(destination_dir)
			if !File.directory?(destination_dir)
				Dir.mkdir(destination_dir)
			end

			@files.each do |file_name, proxy|
				json_name = file_name[0..-4] + ".json.tf"
				str = proxy.to_json(true) + "\n"
				destination_name = destination_dir + "/" + json_name
				File.write(destination_name, str)

				yield file_name, destination_name, str, proxy if block_given?
			end

		end

	end
end
