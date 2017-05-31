
class Biosphere

    class ConfigurationError < ::RuntimeError

        attr_accessor :settings, :explanation

        def initialize(msg, settings = nil)
            super(msg)

            @settings = settings
        end
    end

end

