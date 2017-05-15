require 'biosphere'
require 'pp'

RSpec.describe Biosphere::Deployment do

    describe "constructor" do
        it "can be created" do
            d = Biosphere::Deployment.new("test name, please ignore")
            expect(d).not_to eq(nil)
            expect(d.name).to eq("test name, please ignore")
        end

        it "will call setup in constructor" do

            class CustomError < RuntimeError
            end

            class MyDeployment1 < Biosphere::Deployment

                def setup(settings)
                    raise CustomError.new("called")
                end
            end

            expect {
                d = MyDeployment1.new("test name")
            }.to raise_exception CustomError
        end

        it "will call setup with settings" do

            class MyDeployment2 < Biosphere::Deployment
                attr_accessor :test
                def setup(settings)
                    @test = settings
                end
            end

            d = MyDeployment2.new("test name", {value: "test"})
            expect(d.test[:value]).to eq("test")
            expect(d.name).to eq("test name")
        end


        it "will call setup with settings Hash when a Settings object was passed to constructor" do

            class MyDeployment3 < Biosphere::Deployment
                attr_accessor :test
                def setup(settings)
                    @test = settings
                end
            end

            d = MyDeployment3.new("test name", Biosphere::Settings.new({value: "test2"}))
            expect(d.test[:value]).to eq("test2")
            expect(d.name).to eq("test name")            
        end

    end

    describe "features" do
        it "can have a delayed callback modifying state" do

            class MyDeployment4 < Biosphere::Deployment
                def setup(settings)
                    delayed do
                        node[:foo] = "bar"
                    end
                end
            end

            d = MyDeployment4.new("test name")
            d.evaluate_resources

            expect(d.node).not_to eq(nil)
            expect(d.node[:foo]).to eq("bar")
            expect(d.name).to eq("test name")
        end

        it "can define variable" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    variable "aws_access_key", ""
                    variable "aws_secret_key", settings[:foo]
                end
            end

            d = TestDeployment.new("test name", {
                foo: "bar"
            })

            expect(d.export["variable"]["aws_access_key"]).not_to eq(nil)
            expect(d.export["variable"]["aws_secret_key"]["default"]).to eq("bar")
            expect(d.name).to eq("test name")

        end

        it "can handle scoping" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    the_name = "one"
                    resource "type", "name" do
                        set :name, the_name
                    end
                end
            end

            d = TestDeployment.new("main")
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["main_name"][:name]).to eq("one")
            expect(d.name).to eq("main")
        end

        it "can handle resource setters" do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    resource "type", "name" do
                        set :foo, "one"
                        set :bar, true

                        set :ingress, [
                            {
                                from_port: 0,
                                to_port: 0,
                                protocol: "-1",
                                security_groups: ["${aws_security_group.master.id}", "${aws_security_group.worker.id}"]
                            }
                        ]
                    end
                end
            end

            d = TestDeployment.new("main")
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["main_name"][:foo]).to eq("one")
            expect(d.export["resource"]["type"]["main_name"][:bar]).to eq(true)
            expect(d.name).to eq("main")
        end

        it "can call a helper method in a resource" do

            class TestDeployment < Biosphere::Deployment

                def helper(value)
                    return value + 1
                end

                def setup(settings)
                    resource "type", "name" do
                        set :foo, helper(1)
                    end
                end
            end

            d = TestDeployment.new("main")
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["main_name"]).to eq({:foo => 2})
            expect(d.name).to eq("main")
        end

        it "can mark a resource into a target group" do

            class TestDeployment < Biosphere::Deployment

                def setup(settings)
                    resource "type", "name1", "group-1"
                    resource "type", "name2", "group-1"
                    resource "type", "name3", "group-2"
                end
            end

            d = TestDeployment.new("main")
            d.evaluate_resources()

            expect(d.target_groups['group-1']).to include('type.main_name1')
            expect(d.target_groups['group-1']).to include('type.main_name2')
            expect(d.target_groups['group-1']).not_to include('type.main_name3')
            expect(d.target_groups['group-2']).to include('type.main_name3')
        end

        it "can lookup output values after" do

            s = Biosphere::Suite.new(Biosphere::State.new)
            s.load_all("spec/biosphere/suite_test3/")
            s.evaluate_resources()

            d = s.deployments["main"]
            expect(d.export["resource"]["type"]["sub1_name"]).to eq({:foo => "file1"})
            expect(d.export["resource"]["type"]["sub2_name"]).to eq({:foo => "file1"})
            expect(d.export["resource"]["type"]["main_name"]).to eq({:foo => "file1"})

        end        
    end
    
    describe "state" do
        it "has a global state" do
            state = Biosphere::State.new
            suite = Biosphere::Suite.new(state)

            state.node[:foo] = "foo"

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    resource "type", "name" do
                        state[:foobar] = state[:foo] + "bar"
                    end
                end
            end

            d = TestDeployment.new("test name")
            suite.register(d)
            d.evaluate_resources()

            expect(d.node).not_to eq(nil)
            expect(state.node[:foobar]).to eq("foobar")
        end

        it "has local state" do
            state = Biosphere::State.new
            suite = Biosphere::Suite.new(state)

            state.node[:foo] = "foo"

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    resource "type", "name" do
                        node[:foobar] = state[:foo] + "bar"
                    end
                end
            end

            d = TestDeployment.new("test name")
            suite.register(d)
            d.evaluate_resources()

            expect(d.node).not_to eq(nil)
            expect(d.node[:foobar]).to eq("foobar")
        end

        it "has local state that belongs to the suite state tree" do
            state = Biosphere::State.new
            suite = Biosphere::Suite.new(state)


            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    delayed do
                        node[:foobar] = node[:foo] + "bar"
                    end
                end
            end

            d = TestDeployment.new(suite, "test name")

            # Simulate that we load something from a persistent state before evaluating
            d.node[:foo] = "foo"

            suite.evaluate_resources()

            expect(d.node).not_to eq(nil)
            expect(d.node[:foobar]).to eq("foobar")
            expect(d.name).to eq("test name")
        end
    end

    describe("expose outputs") do
        it("is possible to expose an output variable") do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    output "foobar", output_of("aws_instance", "master", "0", "public_ip")
                end
            end

            a = TestDeployment.new("main")
                
            expect(a.export["output"]["main_foobar"]["value"]).to eq("${aws_instance.main_master.0.public_ip}")
            
        end

        it "is possible to add a block to handle output value after applying terraform" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    output "foobar", output_of("aws_instance", "master", "0", "public_ip") do |deployment_name, key, value|
                        node[:foobar] = [deployment_name, key, value]
                    end
                end
            end

            a = TestDeployment.new("main")
            
            a.evaluate_outputs({
                "main_foobar" => {
                    "sensitive" => false,
                    "type" => "string",
                    "value" => "hello"
                }
            })

            expect(a.node[:foobar]).to eq(["main", "foobar", "hello"])

        end

        it "can lookup output values after" do

            s = Biosphere::Suite.new(Biosphere::State.new)
            s.load_all("spec/biosphere/suite_test1/")
            s.evaluate_resources()

            s.deployments["test1"].load_outputs("spec/biosphere/suite_test1/build/output.tfstate")

            expect(s.deployments["test1"].node[:foobar]).to eq(["foobar", "hello"])

        end
        
    end

    describe("expose variables") do
        it("is possible to define a simple string variable") do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    variable "foobar", "Hello, World!"
                end
            end

            a = TestDeployment.new("test name")

            expect(a.export["variable"]["foobar"]["default"]).to eq("Hello, World!")

        end
    end
    

end
