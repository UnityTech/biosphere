require 'pp'
require 'ipaddress'
require 'biosphere/node'
require 'deep_merge'
require 'deep_dup'

class Biosphere
    class State
        attr_accessor :filename, :node
        
        def initialize(filename = nil)
            if filename
                load(filename)
            else
                self.reset()
            end
        end

        def reset()
            @node = Node.new
        end

        def load(filename=nil)
            if filename
                @filename = filename
            end
            data = Marshal.load(File.read(@filename))
            #puts "Loading data from file #{@filename}: #{data}"
            load_from_structure!(data)
        end

        def node(name=nil)
            if name
                return @node[name]
            else
                return @node
            end
        end

        def merge!(settings)
            @node.merge!(settings)
        end

        def save(filename=nil)
            if !filename && @filename
                filename = @filename
            end
            str = Marshal.dump(@node)
            File.write(filename, str)
            puts "Saving state to #{filename}"
        end

        def load_from_structure!(structure)
            if @node

                # Objects which might get removed when building a new state need to be stored away before the merge
                feature_manifests = {}
                @node.data[:deployments].each do |name, deployment|
                    if deployment[:feature_manifests]
                        feature_manifests[name] = ::DeepDup.deep_dup(deployment[:feature_manifests])
                    end
                end

                # Merge the structured state into the current state
                @node.data.deep_merge(structure.data, {:overwrite_arrays => true})

                # Now re-apply the stored objects on top of the merged state so that removes are handled correctly
                @node.data[:deployments].each do |name, deployment|
                    removed = {}
                    if feature_manifests[name]
                        feature_manifests[name].each do |section, manifests|
                            diff = deployment[:feature_manifests][section] - manifests
                            removed[section] = diff if diff.length > 0
                        end
                        deployment[:feature_manifests] = feature_manifests[name]
                    end

                    if removed.length > 0
                        deployment[:removed_feature_manifests] = removed
                    end
                end

            else
                @node = structure
            end
        end
    end
end
