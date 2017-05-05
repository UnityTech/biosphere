require 'biosphere'
require 'pp'

RSpec.describe Biosphere::TerraformProxy do

    describe "defining resources using Deployments" do
        it "can define a resource in the constructor" do

            res = {}

            p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
            p.load_from_block do
                class TestDeployment < Biosphere::Deployment
                    def setup(settings)
                        resource "type", "name" do
                            set :foo, "one"
                            set :bar, true
                        end
                    end
                end
                a = TestDeployment.new("unnamed")

                a.evaluate_resources()
                res[:a] = a
            end

            expect(res[:a].export["resource"]["type"]["unnamed_name"]).to eq({:foo => "one", :bar=> true})

        end
    end

    describe("actions") do
        it "is possible to define an action" do
            p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
            p.load_from_block do
                action "init", "Description what this does"
            end
            
            expect(p.actions["init"]).not_to be_empty
            expect(p.actions["init"][:name]).to eq("init")
            expect(p.actions["init"][:description]).to eq("Description what this does")

        end

        it "can use function defined outside the action" do
            p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
            p.load_from_block do
                def foo()
                    return "bar"
                end
                action "init", "Description what this does" do
                    foo()
                end
            end
            
            expect(p.actions["init"]).not_to be_empty
            expect(p.actions["init"][:name]).to eq("init")
            expect(p.actions["init"][:description]).to eq("Description what this does")
            
            context = Biosphere::ActionContext.new()

            p.call_action("init", context)

        end
    end

    describe("load") do

        it "can load a file which ends in .rb" do
            p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
            p.load_from_block do
                load "spec/biosphere/suite_test2/lib/template_file.rb"
            end

            expect(p.actions["template_action"][:name]).to eq("template_action")
        end

        it "can load a file which does not ends in .rb" do
            p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
            p.load_from_block do
                load "spec/biosphere/suite_test2/lib/template_file"
            end

            expect(p.actions["template_action"][:name]).to eq("template_action")
        end

    end


end
