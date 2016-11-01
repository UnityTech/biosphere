require 'biosphere'
require 'pp'

RSpec.describe Biosphere::TerraformProxy do

    it "can evaluate file" do
        p = Biosphere::TerraformProxy.new("spec/biosphere/terraformproxy_test1.rb")
        p.load_from_file()
        p.evaluate_resources()
        expect(p.export["resource"]["type"]["name"]).to eq({:foo => "one", :bar=> false})
    end

    it "can evaluate block" do
        p = Biosphere::TerraformProxy.new("test")
        p.load_from_block do
            resource "type", "name" do
                foo "one"
                bar true
            end
        end

        p.evaluate_resources()
        expect(p.export["resource"]["type"]["name"]).to eq({:foo => "one", :bar=> true})
    end

    it "supports node outside resource or plan definition" do
        p = Biosphere::TerraformProxy.new("test")
        p.load_from_block do
            node[:settings] = true
        end

        expect(p.node[:settings]).to eq(true)

    end

    describe "resource" do
        it "can use block notation" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                resource "type", "name" do
                    foo "one"
                    bar true

                    if true
                        ingress [
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

            p.evaluate_resources()

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:from_port]).to eq(0)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:protocol]).to eq("-1")
        end

        it "can do ingress into array multiple times" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                resource "type", "name" do
                    foo "one"
                    bar true

                    ingress({
                        test: "first"
                    })
                    
                    ingress({
                        test: "second"
                    })
                    
                end
            end
            p.evaluate_resources()

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:test]).to eq("first")
            expect(p.export["resource"]["type"]["name"][:ingress][1][:test]).to eq("second")
        end

        it "can do ingress into array multiple times 2" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                resource "type", "name" do
                    foo "one"
                    bar true

                    ingress [
                        {
                            test: "first"
                        },
                        {
                            test: "second"
                        }
                    ]
                    
                    ingress({
                        test: "3rd"
                    })
                    
                end
            end
            p.evaluate_resources()

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:test]).to eq("first")
            expect(p.export["resource"]["type"]["name"][:ingress][1][:test]).to eq("second")
            expect(p.export["resource"]["type"]["name"][:ingress][2][:test]).to eq("3rd")
        end 

        it "can refer to an already set property later in resource definition block" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                resource "type", "name" do
                    name "one"
                    bar name
                end
            end
            p.evaluate_resources()
            
            expect(p.export["resource"]["type"]["name"][:name]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq("one")
        end

        it "can handle scoping" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                the_name = "one"
                resource "type", "name" do
                    name the_name
                end
            end
            p.evaluate_resources()
            
            expect(p.export["resource"]["type"]["name"][:name]).to eq("one")
            
        end

        it "can call function defined outside of the resource block" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                def foo()
                    return "bar"
                end
                
                resource "type", "name" do
                    name foo()
                end
            end
            p.evaluate_resources()
            
            expect(p.export["resource"]["type"]["name"][:name]).to eq("bar")
            
        end
    end

    describe("plan") do
        it "can execute a plan" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                plan "world domination" do
                    node[:name] = "test"
                end
            end

            p.evaluate_plans()
            expect(p.node[:name]).to eq("test")
        end
    end

    describe("included templates") do
        it("is possible to include a file with a function and define resources via that function") do

            p = Biosphere::TerraformProxy.new("spec/biosphere/suite_test2/main_file.rb")
            p.load_from_file()
            p.evaluate_resources()

            expect(p.export["resource"]["type"]["name1"]).to eq({:foo => "I'm Garo"})
            expect(p.export["resource"]["type"]["name2"]).to eq({:property => "test"})
            expect(p.export["resource"]["type"]["name3"]).to eq({:foo => "test3"})

        end
   
    end

    describe("actions") do
        it "is possible to define an action" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                action "init", "Description what this does"
            end
            
            expect(p.actions["init"]).not_to be_empty
            expect(p.actions["init"][:name]).to eq("init")
            expect(p.actions["init"][:description]).to eq("Description what this does")

        end

        it "can use function defined outside the action" do
            p = Biosphere::TerraformProxy.new("test")
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

    describe("expose outputs") do
        it("is possible to expose an output variable") do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                output "foobar", "${aws_instance.master.0.public_ip}"
            end

            expect(p.export["output"]["foobar"]["value"]).to eq("${aws_instance.master.0.public_ip}")
            
        end
    end    

    describe("expose variables") do
        it("is possible to define a simple string variable") do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                variable "foobar", "Hello, World!"
            end

            expect(p.export["variable"]["foobar"]["default"]).to eq("Hello, World!")

        end
    end

    describe("load") do

        it "can load a file which ends in .rb" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                load "spec/biosphere/suite_test2/lib/template_file.rb"
            end

            expect(p.actions["template_action"][:name]).to eq("template_action")
        end

        it "can load a file which does not ends in .rb" do
            p = Biosphere::TerraformProxy.new("test")
            p.load_from_block do
                load "spec/biosphere/suite_test2/lib/template_file"
            end

            expect(p.actions["template_action"][:name]).to eq("template_action")
        end

        it "can load a file which defines a function and then use that function" do
            p = Biosphere::TerraformProxy.new("test")

            p.load_from_block do
                puts "Going to load test.rb"
                load "spec/biosphere/suite_load/test.rb"

                def delegator(str)
                    return duplicate_string(str)
                end

                resource "type", "name" do
                    payload delegator("foo")
                end
            end
            p.evaluate_resources()

            expect(p.export["resource"]["type"]["name"][:payload]).to eq("foofoo")
        end        
        
    end


end
