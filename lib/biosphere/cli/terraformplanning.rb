require 'pp'
require 'treetop'

class Biosphere

    class CLI

        class TerraformPlanning

            # returns object which contains interesting information on
            # the terraform plan output.
            #
            # :relaunches contains a list of resources which will be changed
            # by a relaunch
            def parse_terraform_plan_output(str)
                relaunches = []
                new_resources = []
                lines = str.split("\n")
                lines.each do |line|
                    m = line.match(/^([-~+\/]+)\s(.+)$/)
                    if m
                        # If the resource action contains a minus ('-' or '-/+') then
                        # we know that the action will be destructive.
                        if m[1].match(/[-]/)
                            relaunches << m[2]
                        elsif m[1] == "+"
                            new_resources << m[2]
                        end
                    end
                end
                return {
                    :relaunches => relaunches,
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
                # - :marked_for_relaunch (bool)
                #
                resource_change_plan = []

                group_changes_map = {}
                resource_to_target_group_map = {}
                pp deployment

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
                            :target_group => nil,
                            :reason => "does not belong to any target group",
                            :marked_for_relaunch => true
                        }
                    end
                end

                puts "resource_to_target_group_map"
                pp resource_to_target_group_map

                # Easy case first: new resources. We just want to lookup the group so that we can show that to the user
                changes[:new_resources].each do |change|
                    group = resource_to_target_group_map[change]
                    if group
                        resource_change_plan << {
                            :resource_name => change,
                            :target_group => group,
                            :reason => "new resource",
                            :marked_for_relaunch => true
                        }
                    else
                        resource_change_plan << {
                            :resource_name => change,
                            :target_group => nil,
                            :reason => "new resource",
                            :marked_for_relaunch => true
                        }
                        
                    end
                end

                # Relaunches are more complex: we need to bucket resources based on group, so that we can later pick just one change from each group
                changes[:relaunches].each do |change|
                    group = resource_to_target_group_map[change]
                    if group
                        puts "group: #{group}, change: #{change}"
                        group_changes_map[group] = (group_changes_map[group] ||= []) << change
                    elsif resources_not_in_any_target_group[change]
                        # this handles a change to a resource which does not belong to any target group
                        resource_change_plan << resources_not_in_any_target_group[change]
                    else
                        # this handles the case where a resource was removed from the definition and
                        # now terraform wants to destroy this resource
                        resource_change_plan << {
                            :resource_name => change,
                            :target_group => nil,
                            :reason => "resource definition has been removed",
                            :marked_for_relaunch => true
                        }
                        
                    end
                end

                puts "group_changes_map"
                pp group_changes_map

                # Handle safe groups: just one changing resource in the group
                safe_groups = group_changes_map.select { |name, resources| resources.length <= 1 }
                safe_groups.each do |group_name, resources|
                    resources.each do |resource_name|
                        resource_change_plan << {
                            :resource_name => resource_name,
                            :target_group => group_name,
                            :reason => "only member in its group",
                            :marked_for_relaunch => true
                        }
                    end
                end

                # Handle problematic groups: select one from each group where count(group) > 1
                problematic_groups = group_changes_map.select { |name, resources| resources.length > 1 }
                problematic_groups.each do |group_name, resources|
                    original_length = resources.length
                    resource_change_plan << {
                        :resource_name => resources.shift,
                        :target_group => group_name,
                        :reason => "group has total #{original_length} resources. Picked this as the first",
                        :marked_for_relaunch => true
                    }

                    resources.each do |resource_name|
                        resource_change_plan << {
                            :resource_name => resource_name,
                            :target_group => group_name,
                            :reason => "not selected from this group",
                            :marked_for_relaunch => false
                        }
                    end
                    
                end

                return resource_change_plan
            end
        end
    end
end
