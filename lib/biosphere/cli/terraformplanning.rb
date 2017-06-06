require 'pp'
require 'treetop'
require 'colorize'

class Biosphere

    class TerraformGraph

        attr_accessor :graph

        class Edge
            attr_accessor :src, :dst, :length

            def initialize(src, dst, length = 1)
                @src = src
                @dst = dst
                @length = length
            end
        end


        class Graph < Array
            attr_reader :edges, :map

            def initialize
                @map = {}
                @edges = []
            end

            def connect(src_name, dst_name, length = 1)
                unless @map.include?(src_name)
                    raise ArgumentError, "No such vertex: #{src_name}"
                end
                unless @map.include?(dst_name)
                    raise ArgumentError, "No such vertex: #{dst_name}"
                end

                src = @map[src_name]
                dst = @map[dst_name]

                @edges.push Edge.new(src, dst, length)
            end

            def push_name(name)
                if !@map[name]
                    index = @map.length + 1
                    @map[name] = index
                    self.push(index)
                    return index
                else
                    return @map[name]
                end
            end

            def connect_mutually(vertex1_name, vertex2_name, length = 1)
                self.connect vertex1_name, vertex2_name, length
                self.connect vertex2_name, vertex1_name, length
            end

            def neighbors(vertex_name)
                vertex = @map[vertex_name]
                neighbors = []
                @edges.each do |edge|
                    neighbors.push edge.dst if edge.src == vertex
                end
                return neighbors.uniq.collect { |x| @map.key(x) }
            end

            def neighbors_by_index(vertex)
                neighbors = []
                @edges.each do |edge|
                    neighbors.push edge.dst if edge.src == vertex
                end
                return neighbors.uniq
            end

            def length_between(src_name, dst_name)
                src = @map[src_name]
                dst = @map[dst_name]

                @edges.each do |edge|
                    return edge.length if edge.src == src and edge.dst == dst
                end
                nil
            end

            def length_between_index(src, dst)
                @edges.each do |edge|
                    return edge.length if edge.src == src and edge.dst == dst
                end
                nil
            end

            def dijkstra(src_name, dst_name = nil)
                src = @map[src_name]
                dst = @map[dst_name]
q
                distances = {}
                previouses = {}
                self.each do |vertex|
                    distances[vertex] = nil # Infinity
                    previouses[vertex] = nil
                end
                distances[src] = 0
                vertices = self.clone
                until vertices.empty?
                    nearest_vertex = vertices.inject do |a, b|
                        next b unless distances[a]
                        next a unless distances[b]
                        next a if distances[a] < distances[b]
                        b
                    end
                    break unless distances[nearest_vertex] # Infinity
                    if dst and nearest_vertex == dst
                        path = path_to_names(get_path(previouses, src, dst))
                        return { path: path, distance: distances[dst] }
                    end
                    neighbors = vertices.neighbors_by_index(nearest_vertex)
                    neighbors.each do |vertex|
                        alt = distances[nearest_vertex] + vertices.length_between_index(nearest_vertex, vertex)
                        if distances[vertex].nil? or alt < distances[vertex]
                            distances[vertex] = alt
                            previouses[vertex] = nearest_vertex
                            # decrease-key v in Q # ???
                        end
                    end
                    vertices.delete nearest_vertex
                end
                if dst
                    return nil
                else
                    paths = {}
                    distances.each { |k, v| paths[k] = path_to_names(get_path(previouses, src, k)) }
                    return { paths: paths, distances: distances }
                end
            end

            private
            def path_to_names(path)
                p = []
                path.each do |index|
                    p << @map.key(index)
                end

                return p
            end

            def get_path(previouses, src, dest)
                path = get_path_recursively(previouses, src, dest)
                path.is_a?(Array) ? path.reverse : path
            end

            # Unroll through previouses array until we get to source
            def get_path_recursively(previouses, src, dest)
                return src if src == dest
                raise ArgumentError, "No path from #{src} to #{dest}" if previouses[dest].nil?
                [dest, get_path_recursively(previouses, src, previouses[dest])].flatten
            end
        end

        def initialize()

        end

        def parse_line(line)
            if (m = line.match(/"\[(.+?)\] (?<name>\S+?)(\((.+?)\))?" \[label/))
                return {
                    :type => :node,
                    :name => m[:name]
                }
            elsif (m = line.match(/"\[(.+?)\] (?<from>\S+?)(\s\((.+?)\)){0,1}" -> "\[(.+?)\] (?<to>\S+?)(\s\((.+?)\)){0,1}"/))
                return {
                    :type => :edge,
                    :from => m[:from],
                    :to => m[:to]
                }
            else
                return nil
            end
        end

        def load(data)

            @graph = Graph.new

            lines = data.split("\n")
            lines.each do |line|

                m = parse_line(line)
                if m
                    if m[:type] == :node
                        @graph.push_name m[:name]
                    elsif m[:type] == :edge
                        @graph.push_name m[:from]
                        @graph.push_name m[:to]
                        @graph.connect(m[:from], m[:to], 1)
                    end
                end
            end
        end

        def get_blacklist_by_dependency(item)
            path = @graph.dijkstra("root", item)
            return path[:path]
        end

        def filter_tf_plan(plan)

            blacklist = []
            plan.items.each do |item|
                if item[:action] == :not_picked
                    begin
                        blacklist << get_blacklist_by_dependency(item[:resource_name])
                    rescue ArgumentError => e
                        puts "Error: #{e}. item: #{item}"
                    end
                end
            end

            blacklist.each do |blacklist_items|
                blacklist_items.each do |blacklist_path_item|
                    plan.items.each do |item|
                        if item[:resource_name] == blacklist_path_item && item[:action] != :not_picked
                            item[:action] = :not_picked
                            item[:reason] = "not selected as dependent on #{blacklist_items[blacklist_items.index(item[:resource_name])+1..-1].join(" -> ")}"
                        end
                    end
                end
            end
            return plan
        end
    end

    class CLI

        class TerraformPlanning

            class TerraformPlan
                attr_accessor :items
                def initialize()
                    @items = []
                    @graph = nil
                end

                def length
                    @items.length
                end

                def print(out = STDOUT)
                    last_target_group = nil
                    @items.sort_by { |a| a[:target_group] }.each do |item|
                        if last_target_group != item[:target_group]
                            if item[:target_group] != ""
                                out.write "\nTarget group: #{item[:target_group]}\n"
                            else
                                out.write "\nNot in any target groups:\n"
                            end
                            last_target_group = item[:target_group]
                        end
                        out.write "\t"
                        out.write "#{item[:resource_name]} "
                        if item[:action] == :create
                            out.write "(#{item[:reason]})".colorize(:green)
                        elsif item[:action] == :relaunch
                            out.write "(#{item[:reason]})".colorize(:yellow)
                        elsif item[:action] == :destroy
                            out.write "(#{item[:reason]})".colorize(:red)
                        elsif item[:action] == :change
                            out.write "(#{item[:reason]})".colorize(:yellow)
                        elsif item[:action] == :not_picked
                            out.write "(#{item[:reason]})".colorize(:yellow)
                        else
                            out.write "(#{item[:reason]}) unknown action: #{item[:action]}".colorize(:red)
                        end
                        out.write "\n"
                    end

                    if has_unpicked_resources()

                        out.write "\nWARNING: Not all resource changes will be applied!".colorize(:yellow)
                        out.write "\nYou need to do \"biosphere commit\" again when you have verified that it is safe to do so!".colorize(:yellow)
                    end
                end

                def has_unpicked_resources()
                    @items.find_index { |x| x[:action] == :not_picked } != nil
                end

                def get_resources()
                    @items.select { |x| x[:action] != :not_picked }.collect { |x| x[:resource_name] }
                end
            end

            def generate_plan(deployment, tf_output_str, tf_graph_str = nil)

                if tf_graph_str
                    @graph = Biosphere::TerraformGraph.new
                    @graph.load(tf_graph_str)
                end

                data = parse_terraform_plan_output(tf_output_str)

                plan = build_terraform_targetting_plan(deployment, data)

                if @graph
                    plan = @graph.filter_tf_plan(plan)
                end
                return plan
            end

            # returns object which contains interesting information on
            # the terraform plan output.
            #
            # :relaunches contains a list of resources which will be changed
            # by a relaunch
            def parse_terraform_plan_output(str)
                relaunches = []
                changes = []
                new_resources = []
                lines = str.split("\n")
                lines.each do |line|
                    # the gsub is to strip possible ansi colors away
                    # the match is to pick the TF notation about how the resource is about to change following the resource name itself
                    m = line.gsub(/\e\[[0-9;]*m/, "").match(/^([-~+\/]+)\s(\S+)/)
                    if m
                        # If the resource action contains a minus ('-' or '-/+') then
                        # we know that the action will be destructive.
                        if m[1].match(/[-]/)
                            relaunches << m[2]
                        elsif m[1] == "~"
                            changes << m[2]
                        elsif m[1] == "+"
                            new_resources << m[2]
                        end
                    end
                end
                return {
                    :relaunches => relaunches,
                    :changes => changes,
                    :new_resources => new_resources,
                }
            end

            def build_terraform_targetting_plan(deployment, changes)

                # This function will output an array of objects which describe a proper and safe
                # plan for terraform resources to be applied.
                #
                # We can include following sets in this array:
                # - resources which do not belong to any group
                # - resources which belong to a group where count(group) == 1
                # - a single resource from each group where count(group) > 1
                #
                # Each item is an object with the following fields:
                # - :resource_name
                # - :target_group (might be null)
                # - :reason (human readable reason)
                # - :action (symbol :not_picked, :relaunch, :change, :create, :destroy)
                #
                plan = TerraformPlan.new()

                group_changes_map = {}
                resource_to_target_group_map = {}

                resources_not_in_any_target_group = {}
                deployment.all_resources.each do |resource|
                    belong_to_target_group = false
                    resource_name = resource[:type] + "." + resource[:name]

                    deployment.target_groups.each do |group_name, resources|
                        if resources.include?(resource_name)
                            resource_to_target_group_map[resource_name] = group_name
                            belong_to_target_group = true
                        end
                    end

                    if !belong_to_target_group
                        resources_not_in_any_target_group[resource_name] = {
                            :resource_name => resource_name,
                            :target_group => "",
                            :reason => :no_target_group,
                            :action => :relaunch
                        }
                    end
                end

                # Easy case first: new resources. We just want to lookup the group so that we can show that to the user
                changes[:new_resources].each do |change|
                    group = resource_to_target_group_map[change]
                    if group
                        plan.items << {
                            :resource_name => change,
                            :target_group => group,
                            :reason => "new resource",
                            :action => :create
                        }
                    else
                        plan.items << {
                            :resource_name => change,
                            :target_group => "",
                            :reason => "new resource",
                            :action => :create
                        }
                        
                    end
                end

                # Easy case first: new resources. We just want to lookup the group so that we can show that to the user
                changes[:changes].each do |change|
                    group = resource_to_target_group_map[change]
                    if group
                        plan.items << {
                            :resource_name => change,
                            :target_group => group,
                            :reason => "non-destructive change",
                            :action => :change
                        }
                    else
                        plan.items << {
                            :resource_name => change,
                            :target_group => "",
                            :reason => "non-destructive change",
                            :action => :change
                        }
                        
                    end
                end

                # Relaunches are more complex: we need to bucket resources based on group, so that we can later pick just one change from each group
                changes[:relaunches].each do |change|
                    group = resource_to_target_group_map[change]
                    puts "group #{group} for change #{change}"
                    if group
                        group_changes_map[group] = (group_changes_map[group] ||= []) << change
                    elsif resources_not_in_any_target_group[change]
                        # this handles a change to a resource which does not belong to any target group
                        plan.items << resources_not_in_any_target_group[change]
                    else
                        # this handles the case where a resource was removed from the definition and
                        # now terraform wants to destroy this resource
                        plan.items << {
                            :resource_name => change,
                            :target_group => "",
                            :reason => "resource definition has been removed",
                            :action => :destroy
                        }
                        
                    end
                end

                # Handle safe groups: just one changing resource in the group
                safe_groups = group_changes_map.select { |name, resources| resources.length <= 1 }
                safe_groups.each do |group_name, resources|
                    resources.each do |resource_name|
                        plan.items << {
                            :resource_name => resource_name,
                            :target_group => group_name,
                            :reason => "only member in its group",
                            :action => :relaunch
                        }
                    end
                end

                # Handle problematic groups: select one from each group where count(group) > 1
                problematic_groups = group_changes_map.select { |name, resources| resources.length > 1 }
                problematic_groups.each do |group_name, resources|
                    original_length = resources.length
                    plan.items << {
                        :resource_name => resources.shift,
                        :target_group => group_name,
                        :reason => "group has total #{original_length} resources. Picked this as the first",
                        :action => :relaunch
                    }

                    resources.each do |resource_name|
                        plan.items << {
                            :resource_name => resource_name,
                            :target_group => group_name,
                            :reason => "not selected from this group",
                            :action => :not_picked
                        }
                    end
                    
                end

                return plan
            end
        end
    end
end
