require 'biosphere'
require 'colorize'

class Biosphere
    class CLI
        class Utils
            # Asks a question
            # Choises is an array of valid answers, such as ['y', 'n']
            # If optional force is set to true then the first choise option is returned.
            def self.ask_question(question, choices, force: false, color: :yellow)
                answer = ""
                if force
                    puts question + " Forcing since --force is set"
                    return choices.first
                end

                while answer.empty? || !choices.include?(answer.downcase)
                    puts (question + " [" + choices.join('/') + "]").colorize(color)
                    answer = STDIN.gets.chomp
                end

                return answer
            end
        end
    end
end
