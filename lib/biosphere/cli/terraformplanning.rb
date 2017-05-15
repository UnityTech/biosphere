require 'pp'
require 'treetop'
require 'colorize'

class Biosphere

    class CLI

        class TerraformPlanning

            class TerraformPlan
                attr_accessor :items
                def initialize()
                    @items = []
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

            def generate_plan(deployment, tf_output_str)
                data = parse_terraform_plan_output(tf_output_str)

                plan = build_terraform_targetting_plan(deployment, data)

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
                    m = line.gsub(/\e\[[0-9;]*m/, "").match(/^([-~+\/]+)\s(.+)$/)
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
                deployment.resources.each do |resource|
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
