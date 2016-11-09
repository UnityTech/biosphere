require 'yaml'
require 'kubeclient'
require 'erb'
require 'hashdiff'

class String
    # Converts "CamelCase"" into "camel_case"
    def underscore_case()
        str = ""
        self.chars.each do |c|
            if c == c.upcase
                if str != ""
                    str += "_"
                end
                str += c.downcase
            else
                str += c
            end
        end

        return str
    end
end

class Biosphere
    module Kube
        def kube_test(str)
            return str
        end

        def kube_load_manifest_files(dir)
            files = Dir[dir + "/**/*.erb"]
            resources = []
            files.each do |file|
                resources += kube_load_manifest_file(file)
            end

            files = Dir[dir + "/**/*.yaml"]
            files.each do |file|
                resources += kube_load_manifest_file(file)
            end

            resources
        end

        def kube_load_manifest_file(file)
            resources = []
            puts "Loading file #{file}"
            str = ERB.new(IO.read(file)).result(binding)
            begin
                Psych.load_stream(str) do |document|
                    kind = document["kind"]
                    resource = ::Kubeclient::Resource.new(document)
                    resources << resource
                end
            rescue Psych::SyntaxError => e
                STDERR.puts "\n"
                STDERR.puts "YAML syntax error while parsing file #{file}. Notice this happens after ERB templating, so line numbers might not match."
                STDERR.puts "Here are the relevant lines. Error '#{e.problem}' occured at line #{e.line}"
                STDERR.puts "Notice that yaml is very picky about indentation when you have arrays and maps. Check those first."
                lines = str.split("\n")
                start_line = [0, e.line - 3].max
                end_line = [lines.length - 1, e.line + 3].min
                lines[start_line..end_line].each_with_index do |line, num|
                    num += start_line
                    if num == e.line
                        STDERR.printf("%04d>  %s\n".red, num, line)
                    else
                        STDERR.printf("%04d|  %s\n", num, line)
                    end

                end
                STDERR.puts "\n"
                raise e
            end
            return resources
        end

        def kube_create_resource(client, resource)
            name = resource[:metadata][:name]
            resource_name = client.instance_variable_get("@entities")[resource[:kind].downcase].resource_name
            ns_prefix = client.build_namespace_prefix(resource[:metadata][:namespace])
            client.handle_exception do
                client.rest_client[ns_prefix + resource_name]
                .post(resource.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
            end
        end


        def kube_apply_resource(client, resource)
            name = resource[:metadata][:name]
            resource_name = client.instance_variable_get("@entities")[resource[:kind].underscore_case].resource_name
            ns_prefix = client.build_namespace_prefix(resource[:metadata][:namespace])

            responses = []
            begin
                ret = client.rest_client[ns_prefix + resource_name]
                .post(resource.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
                responses << {
                    action: :post,
                    resource: ns_prefix + resource_name + "/#{name}",
                    body: JSON.parse(ret.body)
                }
                puts "Created resource #{ns_prefix + resource_name}/#{name}"

            rescue RestClient::Conflict => e
                key = ns_prefix + resource_name + "/#{name}"
                rest = client.rest_client[key]

                ret = rest.get(client.instance_variable_get("@headers"))
                current_data = JSON.parse(ret.body, :symbolize_names => true)
                puts "Updating resource #{key}"
                headers = { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers"))
                update_resource = resource.dup
                update_resource.delete_field(:apiVersion)
                current_data.merge(update_resource)
                pp current_data.to_h
                
                begin
                    ret = rest.put(current_data.to_h.to_json, headers)
                    responses << {
                        action: :put,
                        resource: key,
                        body: JSON.parse(ret.body)
                    }
                    
                rescue RestClient::Exception => e
                    puts "Error updating resource: #{e} #{e.class}"
                    pp JSON.parse(e.response)
                rescue RestClient::Exception => e
                    puts "Misc exception: #{e}, #{e.class}, #{e.response}"
                end
                
                return responses
            end
        end        
    end
end
