

class TestDeployment2 < ::Biosphere::Deployment

    def setup(settings)

        resource "type", "name" do
            set :foo, "file2"
        end
    end
end

action "two", "desc"

register(TestDeployment2.new("test2"))