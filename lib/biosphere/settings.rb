require 'set'
require 'deep_dup'

class Biosphere

    class Settings

        class << self
            def class_attribute(*attrs)
                singleton_class.class_eval do
                    attr_accessor(*attrs)
                end

                class_attributes.merge(attrs)
            end

            def class_attributes
                @class_attributes ||= ::Set.new
            end

            def inherited(subclass)
                class_attributes.each do |attr|
                    value = send(attr)
                    value = DeepDup.deep_dup(value) # rescue value
                    subclass.class_attribute attr
                    subclass.send("#{attr}=", value)

                    p = path
                    if p != ""
                        p = p + "/"
                    end
                    subclass.send("path=", p + subclass.name.split('::').last)
                end
            end

            def settings(settings=nil)
                if settings
                    c = @settings_hash ||= ::Hash.new
                    c = DeepDup.deep_dup(c)
                    c.deep_merge!(settings)
                    @settings_hash = c
                end
                return @settings_hash
            end

            def add_feature_manifest(feature, manifests=nil)
                if manifests
                    if !manifests.is_a?(Array)
                        manifests = [manifests]
                    end

                    c = @feature_manifests_hash ||= ::Hash.new
                    c = DeepDup.deep_dup(c)
                    a = (c[feature] ||= ::Array.new)
                    c[feature] = (a + manifests).uniq
                    @feature_manifests_hash = c
                end

                return feature_manifests(feature)
            end

            def set_feature_manifests(obj)
                @feature_manifests_hash = obj
            end

            def feature_manifests(feature=nil)
                if feature
                    if @feature_manifests_hash
                        return @feature_manifests_hash[feature]
                    else
                        return nil
                    end
                else
                    return @feature_manifests_hash
                end
            end

            def path()
                return @path
            end

            # Finds files from relative path
            def find_files(p)
                entries = Dir[($current_biosphere_path_stack + "/" + p)] - [".", ".."]
                return entries
            end

            
        end

        class_attribute :settings_hash, :feature_manifests_hash, :path

        attr_accessor :settings, :path, :feature_manifests

        def initialize(settings = {})
            @settings = DeepDup.deep_dup(self.class.settings_hash)
            @feature_manifests = DeepDup.deep_dup(self.class.feature_manifests_hash)
            @path = self.class.path
            if settings
                @settings.deep_merge!(settings)
            end
        end

        def [](key)
            return @settings[key]
        end

        # Initiate defaults
        settings({})
        set_feature_manifests({})

        self.path = ""

    end
end
