require 'pp'

class Terraformation
	class Suite

		attr_accessor :files

		def initialize(directory)

			@files = {}

			files = Dir::glob("#{directory}/**/*.rb")

			for file in files
				proxy = Terraformation::TerraformProxy.new(file)

				@files[file[directory.length+1..-1]] = proxy
			end
		end

		def load_all()
			@files.each do |file_name, proxy|
				proxy.load_from_file()
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
