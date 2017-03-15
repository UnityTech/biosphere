require 'biosphere'
require 'pp'

RSpec.describe Biosphere::Deployment do
    it "can be created" do
        d = Biosphere::Deployment.new
        expect(d).not_to eq(nil)
    end

    it "has a state" do
        d = Biosphere::Deployment.new("test", {
            foo: "bar"
        })

        puts "MMMMMMMM"
        pp d
        expect(d.node).not_to eq(nil)
        expect(d.node[:foo]).to eq("bar")
    end

    describe "features" do
        it "can define variable" do

            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    variable "aws_access_key", ""
                    variable "aws_secret_key", node[:foo]
                end
            end

            d = TestDeployment.new({
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

            d = TestDeployment.new()
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

            d = TestDeployment.new()
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

            d = TestDeployment.new()
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

            d = TestDeployment.new()
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

            d = TestDeployment.new()
            suite.register(d)
            d.evaluate_resources()

            expect(d.node).not_to eq(nil)
            expect(d.node[:foobar]).to eq("foobar")
        end

    end

    describe "polymorphism" do

        it "can be used as ancestor on two levels" do

            class TestDeployment < Biosphere::Deployment
                def initialize(settings={})
                    super(settings)
                    @node.merge!({
                        deep: {
                            value: "hello"
                        },
                        name: "TestDeployment"
                    })
                end
            end

            class ATestDeployment < TestDeployment
                def initialize(settings={})
                    super(settings)
                    @node.merge!({
                        name: "ATestDeployment"
                    })
                end
                
            end

            class BTestDeployment < TestDeployment

                attr :cluster_name, "default"

                def initialize(settings={})
                    super(settings)
                    @node.merge!({
                        name: "BTestDeployment"
                    })
                end
            end

            a = ATestDeployment.new({
                foo: "bar",
                value: "A"
            })

            b = BTestDeployment.new({
                foo: "bar",
                value: "B"
            })
            
            expect(a.node[:name]).to eq("ATestDeployment")
            expect(a.node[:value]).to eq("A")
            expect(a.node[:foo]).to eq("bar")
            expect(a.node[:deep][:value]).to eq("hello")

            expect(b.node[:name]).to eq("BTestDeployment")
            expect(b.node[:value]).to eq("B")
            expect(b.node[:foo]).to eq("bar")
            expect(b.node[:deep][:value]).to eq("hello")
        end
    end

    describe("expose outputs") do
        it("is possible to expose an output variable") do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    output "foobar", "${aws_instance.master.0.public_ip}"
                end
            end

            a = TestDeployment.new
                
            expect(a.export["output"]["foobar"]["value"]).to eq("${aws_instance.master.0.public_ip}")
            
        end
    end    

    describe("expose variables") do
        it("is possible to define a simple string variable") do
            class TestDeployment < Biosphere::Deployment
                def setup(settings)
                    variable "foobar", "Hello, World!"
                end
            end

            a = TestDeployment.new

            expect(a.export["variable"]["foobar"]["default"]).to eq("Hello, World!")

        end
    end
    

end
