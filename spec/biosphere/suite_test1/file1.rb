
class TestDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        resource "type", "name" do
            set :foo, "file1"
        end
    end
end

action "one", "desc"

TestDeployment1.new(suite, {deployment_name: "test1"})
