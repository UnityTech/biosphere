require 'biosphere'
require 'pp'

RSpec.describe Biosphere::Deployment do

    default_settings = { deployment_name: "unnamed" }
    describe "constructor" do
        it "can be created" do
            d = Biosphere::Deployment.new(default_settings)
            expect(d).not_to eq(nil)
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
                d = MyDeployment1.new(default_settings)
            }.to raise_exception CustomError
        end

        it "will call setup with settings" do

            class MyDeployment2 < Biosphere::Deployment
                attr_accessor :test
                def setup(settings)
                    @test = settings
                end
            end

            d = MyDeployment2.new("", {deployment_name: "test", value: "test"})
            expect(d.test[:value]).to eq("test")
        end


        it "will call setup with settings Hash when a Settings object was passed to constructor" do

            class MyDeployment3 < Biosphere::Deployment
                attr_accessor :test
                def setup(settings)
                    @test = settings
                end
            end

            d = MyDeployment3.new("", Biosphere::Settings.new({value: "test2"}))
            expect(d.test[:value]).to eq("test2")
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

            d = MyDeployment4.new(default_settings)
            d.evaluate_resources

            expect(d.node).not_to eq(nil)
            expect(d.node[:foo]).to eq("bar")

        end

        it "can define variable" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    variable "aws_access_key", ""
                    variable "aws_secret_key", settings[:foo]
                end
            end

            d = TestDeployment.new({
                deployment_name: "test",
                foo: "bar"
            })

            expect(d.export["variable"]["aws_access_key"]).not_to eq(nil)
            expect(d.export["variable"]["aws_secret_key"]["default"]).to eq("bar")

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

            d = TestDeployment.new(default_settings)
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["name"][:name]).to eq("one")
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

            d = TestDeployment.new(default_settings)
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(d.export["resource"]["type"]["name"][:bar]).to eq(true)
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

            d = TestDeployment.new(default_settings)
            d.evaluate_resources()

            expect(d.export["resource"]["type"]["name"]).to eq({:foo => 2})
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

            d = TestDeployment.new(default_settings)
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

            d = TestDeployment.new(default_settings)
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

            d = TestDeployment.new(suite, default_settings)

            # Simulate that we load something from a persistent state before evaluating
            d.node[:foo] = "foo"

            suite.evaluate_resources()

            expect(d.node).not_to eq(nil)
            expect(d.node[:foobar]).to eq("foobar")
        end

    end

    describe("expose outputs") do
        it("is possible to expose an output variable") do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    output "foobar", "${aws_instance.master.0.public_ip}"
                end
            end

            a = TestDeployment.new(default_settings)
                
            expect(a.export["output"]["foobar"]["value"]).to eq("${aws_instance.master.0.public_ip}")
            
        end

        it "is possible to add a block to handle output value after applying terraform" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    output "foobar", "${aws_instance.master.0.public_ip}" do |key, value|
                        node[:foobar] = [key, value]
                    end
                end
            end

            a = TestDeployment.new(default_settings)
            
            a.evaluate_outputs({
                "foobar" => {
                    "sensitive" => false,
                    "type" => "string",
                    "value" => "hello"
                }
            })

            expect(a.node[:foobar]).to eq(["foobar", "hello"])

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

            a = TestDeployment.new(default_settings)

            expect(a.export["variable"]["foobar"]["default"]).to eq("Hello, World!")

        end
    end
    

end
