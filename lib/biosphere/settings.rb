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

            def path()
                return @path
            end            
        end

        class_attribute :settings_hash, :path

        attr_accessor :settings, :path

        def initialize(settings = {})
            @settings = DeepDup.deep_dup(self.class.settings_hash)
            @path = self.class.path
            if settings
                @settings.deep_merge!(settings)
            end
        end

        def [](key)
            return @settings[key]
        end

        settings({})

        self.path = ""

    end
end
