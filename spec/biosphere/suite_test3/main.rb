
class TestSubDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        resource "type", "name" do
            set :foo, "file1"
        end

    end
end

class TestDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        sub = TestSubDeployment1.new(self, "sub1")
        sub2 = TestSubDeployment1.new(self, "sub2")

        resource "type", "name" do
            set :foo, "file1"
        end        
    end
end

TestDeployment1.new(suite, "main")
