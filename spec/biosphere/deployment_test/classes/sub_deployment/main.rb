
load '../main.rb'

class SubDeployment < TestDeployment

    def setup(settings)
        variable "aws_access_key", ""
        variable "aws_secret_key", ""

        resource "type", "name" do
            set :foo, "file1"
        end

        provider "aws",
            access_key: "${var.aws_access_key}",
            secret_key: "${var.aws_secret_key}",
            region: settings[:region]

        delayed do
            node[:my] = settings[:my]
        end
    end
end

