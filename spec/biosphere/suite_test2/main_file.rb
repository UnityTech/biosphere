
load 'lib/template_file.rb'

#require './lib/template_file.rb'

class TestDeployment < ::Biosphere::Deployment

    def setup(settings)
        helper = DeploymentHelper.new(self, "helper")
        helper.my_template("Garo")

        resource "type", "name3" do
            set :foo, "test3"
        end
    end
end

TestDeployment.new(suite, "TestDeployment")