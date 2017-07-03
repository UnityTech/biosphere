require 'yaml'
require 'kubeclient'
require 'erb'
require 'hashdiff'
require 'ostruct'
require 'jsonpath'
require 'deep_dup'

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

        #
        # Encapsulates a single resource inside kube apiserver (eg. a Deployment or a DaemonSet).
        # A KubeResource comes from a manifest which has one or more resources (yaml allows separating
        # multiple documents with --- inside a single file).
        #
        #
        class KubeResource
            attr_accessor :resource, :document, :source_file, :preserve_current_values
            def initialize(document, source_file)
                @document = document
                @source_file = source_file
                @preserve_current_values = []
            end

            # Merges the resource with the current resource version in the api server, which
            # has important properties such as:
            #  - metadata.selfLink
            #  - metadata.uid
            #  - metadata.resourceVersion
            #
            # A document can't be updated (PUT verb) unless these are carried over
            #
            def merge_for_put(current)
                new_version = DeepDup.deep_dup(@document)

                if current["metadata"]
                    new_version["metadata"]["selfLink"] = current["metadata"]["selfLink"] if current["metadata"]["selfLink"]
                    new_version["metadata"]["uid"] = current["metadata"]["uid"] if current["metadata"]["uid"]
                    new_version["metadata"]["resourceVersion"] = current["metadata"]["resourceVersion"] if current["metadata"]["resourceVersion"]
                end

                if current["spec"]
                    new_version["spec"] = {} if !new_version["spec"]

                    # handle spec.clusterIP
                    if new_version["spec"]["clusterIP"] && new_version["spec"]["clusterIP"] != current["spec"]["clusterIP"]
                        raise ArgumentError, "#{@source_file}: Tried to modify spec.clusterIP from #{current["spec"]["clusterIP"]} to #{new_version["spec"]["clusterIP"]} but the field is immutable"
                    end
                    new_version["spec"]["clusterIP"] = current["spec"]["clusterIP"] if current["spec"]["clusterIP"]

                end

                @preserve_current_values.each do |jsonpath_query|
                    jp = JsonPath.new(jsonpath_query)
                    current_value = jp.on(current)
                    if current_value.length > 1
                        raise ArgumentError, "#{@source_file}: A JSONPath query \"#{jsonpath_query}\" matched more than one element: #{current_value}. This is not allowed because it should be used to preserve the current value in the Kubernets API server for the property."
                    end

                    new_value = jp.on(new_version)
                    if new_value.length > 1
                        raise ArgumentError, "#{@source_file}: A JSONPath query \"#{jsonpath_query}\" matched more than one element: #{new_value}. This is not allowed because it should be used to preserve the current value in the Kubernets API server for the property."
                    end

                    if current_value.first != new_value.first
                        new_version = JsonPath.for(new_version).gsub(jsonpath_query) { |proposed_value| current_value.first }.to_hash
                    end
                end

                return new_version
            end
        end

        class KubeResourceERBBinding < OpenStruct
            attr_accessor :preserve_current_values

            def initialize(object)
                @preserve_current_values = []
                super(object)
            end

            def preserve_current_value(jsonpathquery)
                @preserve_current_values << jsonpathquery
            end

        end

        class Client
            def initialize(hostname, ssl_options)
                @clients = []

                @clients << ::Kubeclient::Client.new("#{hostname}/api" , "v1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/apps/" , "v1beta1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/extensions/" , "v1beta1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/batch/" , "v2alpha1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/storage.k8s.io/" , "v1", ssl_options: ssl_options)
                @clients << ::Kubeclient::Client.new("#{hostname}/apis/autoscaling/" , "v1", ssl_options: ssl_options)

                @clients.each do |c|
                    begin
                        c.discover
                    rescue KubeException => e
                        puts "Could not discover api #{c.api_endpoint} - maybe this kube version is too old."
                    end
                end
            end

            def get_resource_name(resource)
                resource_name = nil
                kind = resource["kind"].underscore_case
                @clients.each do |c|
                    if c.instance_variable_get("@entities")[kind]
                        return c.instance_variable_get("@entities")[kind].resource_name
                    end
                end
                return nil
            end

            def get_client(resource)
                kind = resource["kind"].underscore_case
                @clients.each do |c|
                    if c.instance_variable_get("@api_group") + c.instance_variable_get("@api_version") == resource[:apiVersion]
                        return c
                    end
                end
                return nil
            end

            def post(resource)
                name = resource["metadata"]["name"]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource[:kind]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource["metadata"]["namespace"])
                body = JSON.pretty_generate(resource.to_h)
                begin
                    ret =  client.rest_client[ns_prefix + resource_name].post(body, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
                rescue RestClient::MethodNotAllowed => e
                    if !resource[:metadata][:namespace]
                        puts "Error doing api call: #{e}".colorize(:red)
                        puts "This might be because you did not specify namespace in your resource: #{resource[:metadata]}".colorize(:yellow)
                    else 
                        puts "Error calling API (on RestClient::MethodNotAllowed): #{e}"
                    end
                    puts "rest_client: #{ns_prefix + resource_name}, client: #{client.rest_client[ns_prefix + resource_name]}"
                    puts "Dumpin resource request:"
                    pp body
                    raise e

                rescue RestClient::BadRequest => e
                    handle_bad_request(client, e, body, ns_prefix, resource_name)
                    raise e

                rescue RestClient::Exception => e
                    puts "Error calling API (on RestClient::Exception rescue): #{e}"
                    puts "rest_client: #{ns_prefix + resource_name}, client: #{client.rest_client[ns_prefix + resource_name]}"
                    puts "Dumpin resource request:"
                    pp resource.to_h.to_json
                    raise e
                end
                return {
                    action: :post,
                    resource: ns_prefix + resource_name + "/#{name}",
                    body: JSON.parse(ret.body)
                }
            end

            def get(resource)
                name = resource["metadata"]["name"]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource["kind"]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource["metadata"]["namespace"])
                key = ns_prefix + resource_name + "/#{name}"
                ret = client.rest_client[key].get(client.instance_variable_get("@headers"))
                return {
                    action: :get,
                    resource: key,
                    body: JSON.parse(ret.body)
                }
            end

            def put(resource)
                name = resource["metadata"]["name"]
                client = get_client(resource)
                resource_name = get_resource_name(resource)

                if !client
                    raise ArgumentError, "Unknown resource #{resource["kind"]} of #{name} for kubernetes. Maybe this is in a new extension api?"
                end

                ns_prefix = client.build_namespace_prefix(resource["metadata"]["namespace"])
                key = ns_prefix + resource_name + "/#{name}"
                ret = client.rest_client[key].put(resource.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(client.instance_variable_get("@headers")))
                return {
                    action: :put,
                    resource: key,
                    body: JSON.parse(ret.body)
                }

            end

            # Applies the KubeResource into the api server
            #
            # The update process has the following sequence:
            #
            #  1) Try to fetch the resource to check if the resource is already there
            #  2.1) If a new resource: issue a POST
            #  2.2) If resource exists: merge existing resource with the KubeResource and issue a PUT (update)
            def apply_resource(kuberesource)
                resource = kuberesource.resource
                name = resource["metadata"]["name"]
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

                    update_resource = kuberesource.merge_for_put(current_resource)

                    begin
                        responses << put(update_resource)
                    rescue RestClient::BadRequest => e
                        handle_bad_request(client, e, body, ns_prefix, resource_name)
                        raise e
                    rescue RestClient::Exception => e
                        puts "Error updating resource: #{e} #{e.class}"
                        pp JSON.parse(e.response)
                    end
                    
                    return responses
                end
            end

            def print_error_location(lines, linenumber)
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

            def handle_bad_request(client, e, body, ns_prefix, resource_name)
                puts "Error calling API (on RestClient::BadRequest rescue): #{e}"
                puts "rest_client: #{ns_prefix + resource_name}, client: #{client.rest_client[ns_prefix + resource_name]}"

                begin
                    msg = JSON.parse(e.http_body)
                    if msg["message"]
                        m = msg["message"].match(/\[pos ([0-9]+?)\]:\s?(.+)/)
                        if m
                            error_pos = m[1].to_i
                            if error_pos < body.length
                                # Find the line number where the error is
                                line_number = 0
                                for pos in 0..body.length - 1
                                    if body[pos] == "\n"
                                        line_number += 1
                                    end
                                    if pos >= m[1].to_i
                                        break
                                    end
                                end
                                print_error_location(body.split("\n"), line_number)
                            end
                        end
                    end
                rescue
                    puts "Error message from body #{e.http_body}"
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

            # Let's wrap the context into an OpenStruct based class so that context["foo"]
            # can be accessed as contextstruct.foo
            #
            # This is required for two reasons:
            #  1) The ERB template evaluation requires a binding object so that
            #     we can pass variables to the template (from the context object)
            #  2) We want to push some metadata from the ERB template to back here
            #     such as the preserve_current_value
            contextstruct = KubeResourceERBBinding.new(context)

            # Read the file in. A single .yaml can contain multiple documents
            data = IO.read(file)

            # First phase: Evaluate ERB templating. We'll use the context to pass
            # all the template variables into the erb.
            # Handle all ERB error reporting with the rescue clauses,
            # so that user gets as good error message as possible.
            begin
                str = ERB.new(data).result(contextstruct.instance_eval { binding })
            rescue NoMethodError => e
                puts "Error evaluating erb templating for #{file}. Error: #{e}"
                m = /\(erb\):([0-9]+):/.match(e.backtrace.first)
                if m
                    puts "Error at line #{m[1]}. This is before ERB templating. Remember to run biosphere build if you changed settings."
                    linenumber = m[1].to_i
                    lines = data.split("\n")
                    start_line = [0, linenumber - 4].max
                    end_line = [lines.length - 1, linenumber + 2].min

                    # Lines is the full .yaml file, one line in each index
                    # the [start_line..end_line] slices the subset of the lines
                    # which we want to display
                    lines[start_line..end_line].each_with_index do |line, num|

                        # num is the current line number from the subset of the lines
                        # We need to add start_line + 1 to it so that it shows
                        # the current line number when we print it out
                        num += start_line + 1
                        if num == linenumber
                            STDERR.printf("%04d>  %s\n".red, num, line)
                        else
                            STDERR.printf("%04d|  %s\n", num, line)
                        end
                    end
                end
                raise e
            end

            # Second phase: Parse YAML into an array of KubeResource.
            # Again handle error reporting on the rescue clause.
            begin
                Psych.load_stream(str) do |document|
                    kind = document["kind"]
                    resource = KubeResource.new(document, file)

                    # The preserve_current_values is a metadata field which is used later
                    # when merging the updated resource with the current object from apiserver.
                    resource.preserve_current_values = contextstruct.preserve_current_values

                    resources << resource
                end
            rescue Psych::SyntaxError => e
                STDERR.puts "\n"
                STDERR.puts "YAML syntax error while parsing file #{file}. Notice this happens after ERB templating, so line numbers might not match."
                STDERR.puts "Here are the relevant lines. Error '#{e.problem}' occured at line #{e.line}"
                STDERR.puts "Notice that yaml is very picky about indentation when you have arrays and maps. Check those first."
                lines = str.split("\n")
                linenumber = e.line
                start_line = [0, linenumber - 4].max
                end_line = [lines.length - 1, linenumber + 2].min
                lines[start_line..end_line].each_with_index do |line, num|
                    # num is the current line number from the subset of the lines
                    # We need to add start_line + 1 to it so that it shows
                    # the current line number when we print it out
                    num += start_line + 1
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

    end
end
