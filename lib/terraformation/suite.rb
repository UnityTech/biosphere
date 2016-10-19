require 'pp'

class Terraformation
	class Suite

		attr_accessor :files
		attr_accessor :actions

		def initialize(directory)

			@files = {}
			@actions = {}

			files = Dir::glob("#{directory}/*.rb")

			for file in files
				proxy = Terraformation::TerraformProxy.new(file)

				@files[file[directory.length+1..-1]] = proxy
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
