require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::CLI::TerraformPlanning do

    it "has a constructor" do
        s = Biosphere::CLI::TerraformPlanning.new()
    end

    describe "dependency graph" do

        it "can connect vertices by name" do

            graph = ::Biosphere::TerraformGraph::Graph.new
            a = graph.push_name "a"
            b = graph.push_name "b"
            c = graph.push_name "c"
            d = graph.push_name "d"

            expect(a).to eq(1)
            expect(b).to eq(2)
            expect(c).to eq(3)
            expect(d).to eq(4)

            graph.connect_mutually("a", "b", 7)
            graph.connect_mutually("a", "c", 9)
            graph.connect_mutually("c", "d", 2)

            puts "printing graph"
            pp graph
            expect(graph.length_between("a", "c")).to eq(9)
            expect(graph.neighbors("a")).to eq(["b", "c"])
            expect(graph.dijkstra("a", "d")[:distance]).to eq(11)
            expect(graph.dijkstra("a", "d")[:path]).to eq(["a", "c", "d"])
        end

        it "can parse lines" do
            graph = ::Biosphere::TerraformGraph.new

            expect(graph.parse_line('"[root] foo" -> "[root] bar"')).to eq({:type => :edge, :from => "foo", :to => "bar"})
            expect(graph.parse_line('"[root] root" -> "[root] provider.aws (close)"')).to eq({:type => :edge, :from => "root", :to => "provider.aws"})
            expect(graph.parse_line('"[root] root (derp derp)" -> "[root] provider.aws (close)"')).to eq({:type => :edge, :from => "root", :to => "provider.aws"})

            expect(graph.parse_line('"[root] foo.bar" [label = "foo.bar", shape = "box"]')).to eq({:type => :node, :name => "foo.bar"})

            expect(graph.parse_line('"[root] meta.count-boundary (count boundary fixup)" -> "[root] aws_autoscaling_group.delivery-staging-us-east-1d_asg-workers-ads-auction"')).to eq({:type => :edge, :from => "meta.count-boundary", :to => "aws_autoscaling_group.delivery-staging-us-east-1d_asg-workers-ads-auction"})
        end

        it "can parse dependency graph" do

            data = File.read("spec/biosphere/digraph.dot")

            graph = Biosphere::TerraformGraph.new
            graph.load(data)

            l = graph.get_blacklist_by_dependency("aws_instance.delivery-staging-us-east-1d_master-0")

            expect(l).to include("root")
            expect(l).to include("aws_eip.delivery-staging-us-east-1d_master-0")
        end

        it "can filter terraform plan based on the graph" do
            items = []

            items << {
                :resource_name => "master-0",
                :target_group => "group-1",
                :reason => "selected",
                :action => :relaunch
            }

            items << {
                :resource_name => "eip.master-0",
                :target_group => "group-1",
                :reason => "non-destructive change",
                :action => :change
            }
            items << {
                :resource_name => "master-1",
                :target_group => "group-1",
                :reason => "not selected",
                :action => :not_picked
            }
            items << {
                :resource_name => "eip.master-1",
                :target_group => "group-1",
                :reason => "non-destructive change",
                :action => :change
            }
            graph = Biosphere::TerraformGraph.new
            graph.load('
            "[root] eip.master-0" -> "[root] master-0"
            "[root] eip.master-1" -> "[root] master-1"
            "[root] root" -> "[root] eip.master-0"
            "[root] root" -> "[root] eip.master-1"
            ')

            plan = Biosphere::CLI::TerraformPlanning::TerraformPlan.new
            plan.items = items

            new_plan = graph.filter_tf_plan(plan)

            #
            # root -> eip.master-0 -> master-0 (all selected)
            # root -> eip.master-1 -> master-1 (master-1 selected, eip.master-1 should be culled)
            expect(new_plan.items).to include({
                :resource_name => "master-0",
                :target_group => "group-1",
                :reason => "selected",
                :action => :relaunch
            })

            expect(new_plan.items).to include({
                :resource_name => "eip.master-0",
                :target_group => "group-1",
                :reason => "non-destructive change",
                :action => :change
            })

            expect(new_plan.items).to include({
                :resource_name => "master-1",
                :target_group => "group-1",
                :reason => "not selected",
                :action => :not_picked
            })

            expect(new_plan.items).to include({
                :resource_name => "eip.master-1",
                :target_group => "group-1",
                :reason => "not selected as dependent on master-1",
                :action => :not_picked
            })
        end

    end

    describe "target grouping" do
        before(:each) do
            @dummy_suite = Biosphere::Suite.new(Biosphere::State.new())
        end

        it "can figure out if a single target group has more than one destroying change" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
-/+ type.main_name1
-/+ type.main_name2
-/+ type.main_name3
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name1",
                :target_group => "group-1",
                :reason => "group has total 2 resources. Picked this as the first",
                :action => :relaunch
            })

            expect(change_plan.items).to include({
                :resource_name => "type.main_name3",
                :target_group => "group-2",
                :reason => "only member in its group",
                :action => :relaunch
            })

            expect(change_plan.items).to include({
                :resource_name => "type.main_name2",
                :target_group => "group-1",
                :reason => "not selected from this group",
                :action => :not_picked
            })

        end

        it "can handle changes" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
~ type.main_name1
~ type.main_name2
~ type.main_name3
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name1",
                :target_group => "group-1",
                :reason => "non-destructive change",
                :action => :change
            })

            expect(change_plan.items).to include({
                :resource_name => "type.main_name3",
                :target_group => "group-2",
                :reason => "non-destructive change",
                :action => :change
            })

            expect(change_plan.items).to include({
                :resource_name => "type.main_name2",
                :target_group => "group-1",
                :reason => "non-destructive change",
                :action => :change
            })

        end


        it "handles resources which dont belong to any target group" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
-/+ type.main_name1
-/+ type.main_name2
-/+ type.main_name3
-/+ type.main_name4
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name4",
                :target_group => "",
                :reason => :no_target_group,
                :action => :relaunch
            })

        end

        it "handles just one resource which does not belong to any group" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
-/+ type.main_name4
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name4",
                :target_group => "",
                :reason => :no_target_group,
                :action => :relaunch
            })

            expect(change_plan.items.length).to equal(1)
        end

        it "handles a plan with no changes" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.length).to equal(0)
        end

        it "handles a plan with ansi colors" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
\e[0m\e[31m-/+ type.main_name1
\e[0m\e[0m
\e[0m\e[32m-/+ type.main_name2
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.length).to equal(2)
        end

        it "handles a resource-to-be-destroyed which does not exists as a resource definition any more" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
- type.main_name3
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name3",
                :target_group => "",
                :reason => "resource definition has been removed",
                :action => :destroy
            })
            expect(change_plan.length).to equal(1)
        end

        it "handles adding a new resource" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                    resource "type", "name4"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
+ type.main_name1
+ type.main_name2
+ type.main_name3
+ type.main_name4
})

            change_plan = s.build_terraform_targetting_plan(d, data)
            expect(change_plan.items).to include({
                :resource_name => "type.main_name1",
                :target_group => "group-1",
                :reason => "new resource",
                :action => :create
            })
            expect(change_plan.items).to include({
                :resource_name => "type.main_name2",
                :target_group => "group-1",
                :reason => "new resource",
                :action => :create
            })
            expect(change_plan.items).to include({
                :resource_name => "type.main_name3",
                :target_group => "group-2",
                :reason => "new resource",
                :action => :create
            })
            expect(change_plan.items).to include({
                :resource_name => "type.main_name4",
                :target_group => "",
                :reason => "new resource",
                :action => :create
            })
            expect(change_plan.length).to equal(4)
        end
    end

    describe "output" do
        before(:each) do
            @dummy_suite = Biosphere::Suite.new(Biosphere::State.new())
        end

        it "can print plan to stdout" do
            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                    resource "type", "name4"
                    resource "type", "name5"
                end
            end

            d = TestDeployment.new(@dummy_suite, "main")
            d.evaluate_resources()

            s = Biosphere::CLI::TerraformPlanning.new()

            data = s.parse_terraform_plan_output(%{
-/+ type.main_name1
- type.main_name2
+ type.main_name3
+ type.main_name4
})

            plan = s.build_terraform_targetting_plan(d, data)
            out = StringIO.new
            plan.print(out)
            puts out.string

            resources = plan.get_resources()
            expect(resources).to include("type.main_name1")
            expect(resources).not_to include("type.main_name2")
            expect(resources).to include("type.main_name3")
            expect(resources).to include("type.main_name4")
            expect(resources).not_to include("type.main_name5")
        end
    end

    describe "parsing" do
        it "can parse a terraform output" do
            s = Biosphere::CLI::TerraformPlanning.new()

            str = %{
aws_eip.garo-kube-test_master-0: Refreshing state... (ID: eipalloc-589d9869)
aws_route53_record.garo-kube-test_master-0: Refreshing state... (ID: Z2OVW5244ROWCA_master-0.garo-kube-test.applifier.info_A)
aws_route53_record.garo-kube-test_masters: Refreshing state... (ID: Z2OVW5244ROWCA_masters.garo-kube-test.applifier.info_A)

The Terraform execution plan has been generated and is shown below.
Resources are shown in alphabetical order for quick scanning. Green resources
will be created (or destroyed and then created if an existing resource
exists), yellow resources are being changed in-place, and red resources
will be destroyed. Cyan entries are data sources to be read.

Note: You didn't specify an "-out" parameter to save this plan, so when
"apply" is called, Terraform can't guarantee this is what will execute.

~ aws_eip.garo-kube-test_master-0
    associate_with_private_ip: "172.16.1.131" => "${aws_instance.garo-kube-test_master-0.private_ip}"
    instance:                  "i-054e5beff357482f3" => "${aws_instance.garo-kube-test_master-0.id}"

- aws_eip.garo-kube-test_master-1

-/+ aws_instance.garo-kube-test_master-0
    ami:                                       "ami-ad593cbb" => "ami-ad593cbb"
    associate_public_ip_address:               "true" => "true"
    availability_zone:                         "us-east-1b" => "us-east-1b"
    ebs_block_device.#:                        "0" => "<computed>"
    ephemeral_block_device.#:                  "0" => "<computed>"
    instance_state:                            "running" => "<computed>"
    instance_type:                             "t2.medium" => "t2.medium"
    ipv6_addresses.#:                          "0" => "<computed>"
    key_name:                                  "unity-ads-us-east-1-2016-02-26" => "unity-ads-us-east-1-2016-02-26"
    network_interface_id:                      "eni-e1a2dd05" => "<computed>"
    placement_group:                           "" => "<computed>"
    private_dns:                               "ip-172-16-1-131.ec2.internal" => "<computed>"
    private_ip:                                "172.16.1.131" => "<computed>"
    public_dns:                                "ec2-34-202-10-188.compute-1.amazonaws.com" => "<computed>"
    public_ip:                                 "34.202.10.188" => "<computed>"
    root_block_device.#:                       "1" => "1"
    root_block_device.0.delete_on_termination: "true" => "true"
    root_block_device.0.iops:                  "100" => "<computed>"
    root_block_device.0.volume_size:           "20" => "20"
    root_block_device.0.volume_type:           "gp2" => "gp2"
    security_groups.#:                         "0" => "<computed>"
    source_dest_check:                         "false" => "false"
    subnet_id:                                 "subnet-ea9bd584" => "subnet-ea9bd584"
    tags.%:                                    "1" => "1"
    tags.Name:                                 "master-0-garo-kube-test" => "master-0-garo-kube-test"
    tenancy:                                   "default" => "<computed>"
    user_data:                                 "483a082c20c89a22cb63b0da5df648a618347507" => "c45158b3257fb761d74b1c8507d63195283d3486" (forces new resource)
    vpc_security_group_ids.#:                  "1" => "1"
    vpc_security_group_ids.2180641009:         "sg-d9d56da7" => "sg-d9d56da7"

- aws_instance.garo-kube-test_master-1

- aws_instance.garo-kube-test_worker-1

- aws_instance.garo-kube-test_worker-2

- aws_route53_record.garo-kube-test_master-1

~ aws_route53_record.garo-kube-test_masters
    records.#:          "2" => "1"
    records.1722108530: "172.16.1.151" => ""
    records.822078964:  "172.16.1.131" => "172.16.1.131"

- aws_route53_record.garo-kube-test_worker-1

- aws_route53_record.garo-kube-test_worker-public-1


Plan: 1 to add, 2 to change, 7 to destroy.
}
            tree = s.parse_terraform_plan_output(str)
        end

        it "can parse a terraform output" do
            s = Biosphere::CLI::TerraformPlanning.new()

            str = %{
~ aws_eip.garo-kube-test_master-0
- aws_eip.garo-kube-test_master-1
-/+ aws_instance.garo-kube-test_master-0
+ aws_instance.garo-kube-test_master-1
- aws_instance.garo-kube-test_master-2 (deposed)
}
            data = s.parse_terraform_plan_output(str)
            expect(data[:relaunches]).not_to include("aws_eip.garo-kube-test_master-0")
            expect(data[:relaunches]).to include("aws_eip.garo-kube-test_master-1")
            expect(data[:relaunches]).to include("aws_instance.garo-kube-test_master-0")
            expect(data[:relaunches]).to include("aws_instance.garo-kube-test_master-2")
            expect(data[:relaunches]).not_to include("aws_instance.garo-kube-test_master-1")
            expect(data[:new_resources]).to include("aws_instance.garo-kube-test_master-1")
        end
    end

end
