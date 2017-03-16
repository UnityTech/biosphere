require 'set'

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
                    value = value.dup rescue value
                    subclass.class_attribute attr
                    subclass.send("#{attr}=", value)
                end
            end

            def settings(settings=nil)
                if settings
                    c = @settings_hash ||= ::Hash.new
                    c = c.dup
                    c.deep_merge!(settings)
                    @settings_hash = c
                end
                return @settings_hash
            end
        end

        class_attribute :settings_hash

        attr_accessor :settings

        def initialize(settings = {})
            @settings = self.class.settings_hash
            if settings
                @settings.deep_merge!(settings)
            end
        end

        settings({})

    end
end
