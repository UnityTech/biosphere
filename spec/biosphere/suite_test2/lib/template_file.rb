
class DeploymentHelper < ::Biosphere::Deployment

    def helper_function(variable)
        resource "type", "name1" do
            set :foo, "I'm #{variable}"
        end
    end

    def my_template(variable)
        puts "my_template called #{variable}"

        helper_function(variable)

        resource "type", "name2" do
            set :property, "test"
        end
    end
end


action "template_action", "test" do
    puts "template_action called"
end
