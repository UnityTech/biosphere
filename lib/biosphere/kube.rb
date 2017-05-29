require 'yaml'
require 'kubeclient'
require 'erb'
require 'hashdiff'
require 'ostruct'

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
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/batch/" , "v2alpha1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/storage.k8s.io/" , "v1", ssl_options: ssl_options)

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

            def apply_resource(resource)
                name = resource[:metadata][:name]
                responses = []
                not_found = false
                begin
                    response = get(resource)
                rescue RestClient::NotFound => e
                    not_found = true
                end

                if not_found
                    begin
                        response = post(resource)
                        puts "Created resource #{response[:resource]}"
                        responses << response
                    rescue RestClient::NotFound => e
                        pp e
                        pp JSON.parse(e.response.body)
                        puts "404 when applying resources might mean one of the following:"
                        puts "\t * You're trying to apply a non-namespaced manifest."
                        puts "\t   Confirm if your manifests metadata should contain a namespace field or not"
                    rescue RestClient::UnprocessableEntity => e
                        pp e
                        pp JSON.parse(e.response.body)
                    end
                else
                    puts "Updating resource #{response[:resource]}"

                    # Get the current full resource from apiserver
                    current_resource = response[:body]

                    update_resource = Kube.kube_merge_resource_for_put!(current_resource, resource)

                    begin
                        responses << put(update_resource)
                    rescue RestClient::Exception => e
                        puts "Error updating resource: #{e} #{e.class}"
                        pp JSON.parse(e.response)
                    rescue RestClient::Exception => e
                        puts "Misc exception: #{e}, #{e.class}, #{e.response}"
                    end
                    
                    return responses
                end
            end

        end # end of class Client

        def kube_test(str)
            return str
        end

        def kube_get_client(hostname, ssl_options)
            return Client.new(hostname, ssl_options)
        end

        def self.find_manifest_files(dir)
            files = []
            files += Dir[dir + "/**/*.erb"]

            files += Dir[dir + "/**/*.yaml"]
            files
        end

        def self.load_resources(file, context={})
            resources = []
            puts "Loading file #{File.absolute_path(file)}"
            data = IO.read(file)
            begin
                str = ERB.new(data).result(OpenStruct.new(context).instance_eval { binding })
            rescue NoMethodError => e
                puts "Error evaluating erb templating for #{file}. Error: #{e}"
                m = /\(erb\):([0-9]+):/.match(e.backtrace.first)
                if m
                    puts "Error at line #{m[1]}. This is before ERB templating. Remember to run biosphere build if you changed settings."
                    linenumber = m[1].to_i
                    if linenumber > 0 # Linenumbers seems to be off with 1 as the array is starting at zero
                        linenumber = linenumber - 1
                    end
                    lines = data.split("\n")
                    start_line = [0, linenumber - 3].max
                    end_line = [lines.length - 1, linenumber + 3].min
                    lines[start_line..end_line].each_with_index do |line, num|
                        num += start_line
                        if num == linenumber
                            STDERR.printf("%04d>  %s\n".red, num, line)
                        else
                            STDERR.printf("%04d|  %s\n", num, line)
                        end
                    end
                end
                raise e
            end

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
                linenumber = e.line
                if linenumber > 0 # Linenumbers seems to be off with 1 as the array is starting at zero
                    linenumber = linenumber - 1
                end
                
                start_line = [0, linenumber - 3].max
                end_line = [lines.length - 1, linenumber + 3].min
                lines[start_line..end_line].each_with_index do |line, num|
                    num += start_line
                    if num == linenumber
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

        #
        # Applies seleted properties from the current resource (as fetched from apiserver) to the new_version (as read from manifest file)
        #
        #
        def self.kube_merge_resource_for_put!(current, new_version)
            if current[:metadata]
                new_version[:metadata][:selfLink] = current[:metadata][:selfLink] if current[:metadata][:selfLink]
                new_version[:metadata][:uid] = current[:metadata][:uid] if current[:metadata][:uid]
                new_version[:metadata][:resourceVersion] = current[:metadata][:resourceVersion] if current[:metadata][:resourceVersion]
            end

            if current[:spec]
                new_version[:spec] = {} if !new_version[:spec]

                # handle spec.clusterIP
                if new_version[:spec][:clusterIP] && new_version[:spec][:clusterIP] != current[:spec][:clusterIP]
                    raise ArgumentError, "Tried to modify spec.clusterIP from #{current[:spec][:clusterIP]} to #{new_version[:spec][:clusterIP]} but the field is immutable"
                end
                new_version[:spec][:clusterIP] = current[:spec][:clusterIP] if current[:spec][:clusterIP]

            end
            return new_version
        end


    end
end
