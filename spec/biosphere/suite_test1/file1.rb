
class TestDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        resource "type", "name" do
            set :foo, "file1"
        end
    end
end

action "one", "desc"

register(TestDeployment1.new("test1"))