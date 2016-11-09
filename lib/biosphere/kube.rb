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

        class Client
            def initialize(hostname, ssl_options)
                @clients = []

                @clients << ::Kubeclient::Client.new("#{hostname}/api" , "v1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/extensions/" , "v1beta1", ssl_options: ssl_options)

                @clients.each { |c| c.discover }
            end

            def get_resource_name(resource)
                resource_name = nil
                kind = resource[:kind].underscore_case
                @clients.each do |c|
                    if c.instance_variable_get("@entities")[kind]
                        return c.instance_variable_get("@entities")[kind].resource_name
                    end
                end
                return nil
            end

            def get_client(resource)
                kind = resource[:kind].underscore_case
                @clients.each do |c|
                    if c.instance_variable_get("@entities")[kind]
                        return c
                    end
                end
                return nil
            end

            def post(resource)
                name = resource[:metadata][:name]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource[:kind]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource[:metadata][:namespace])
                ret =  client.rest_client[ns_prefix + resource_name].post(resource.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
                return {
                    action: :post,
                    resource: ns_prefix + resource_name + "/#{name}",
                    body: JSON.parse(ret.body, :symbolize_names => true)
                }
            end

            def get(resource)
                name = resource[:metadata][:name]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource[:kind]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource[:metadata][:namespace])
                key = ns_prefix + resource_name + "/#{name}"
                ret = client.rest_client[key].get(client.instance_variable_get("@headers"))
                return {
                    action: :get,
                    resource: key,
                    body: JSON.parse(ret.body, :symbolize_names => true)
                }
            end

            def put(resource)
                name = resource[:metadata][:name]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource[:kind]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource[:metadata][:namespace])
                key = ns_prefix + resource_name + "/#{name}"
                ret = client.rest_client[key].put(resource.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
                return {
                    action: :put,
                    resource: key,
                    body: JSON.parse(ret.body, :symbolize_names => true)
                }

            end

        end

        def kube_test(str)
            return str
        end

        def kube_get_client(hostname, ssl_options)
            return Client.new(hostname, ssl_options)
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
            responses = []
            not_found = false
            begin
                response = client.get(resource)
            rescue RestClient::NotFound => e
                not_found = true
            end

            if not_found
                begin
                    response = client.post(resource)
                    puts "Created resource #{response[:resource]}"
                    responses << response
                rescue RestClient::UnprocessableEntity => e
                    pp e
                    pp JSON.parse(e.response.body)
                end
            else
                puts "Updating resource #{response[:resource]}"

                # Get the current full resource from apiserver
                update_resource = response[:body]

                # Merge the updates on top of it
                # TODO: this doesn't remove fields from the update_resource which have been removed from the to-be-updated resource
                update_resource.merge(resource)

                # Remove fields which apiserver refuses to accept in PUT requests
                update_resource.delete(:apiVersion)
                
                begin
                    responses << client.put(update_resource)
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
