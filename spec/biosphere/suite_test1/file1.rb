
class TestDeployment1 < ::Biosphere::Deployment

    def setup(settings)
        resource "type", "name" do
            set :foo, "file1"
        end

        output "foobar", "${aws_instance.foobar.0.public_ip}" do |value|
            node[:foobar] = value
        end

    end
end

action "one", "desc"

TestDeployment1.new(suite, {deployment_name: "test1"})
