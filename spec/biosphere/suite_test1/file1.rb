
class TestDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        resource "type", "name" do
            set :foo, "file1"
        end

        output "foobar", output_of("aws_instance", "foobar", "0", "public_ip") do |deployment_name, key, value|
            node[:foobar] = [key, value]
        end

    end
end

action "one", "desc"

TestDeployment1.new(suite, "test1")
