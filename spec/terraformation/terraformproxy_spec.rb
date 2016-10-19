require 'terraformation'
require 'pp'

RSpec.describe Terraformation::TerraformProxy do

    it "can evaluate file" do
        p = Terraformation::TerraformProxy.new("spec/terraformation/terraformproxy_test1.rb")
        p.load_from_file()

        expect(p.export["resource"]["type"]["name"]).to eq({:foo => "one", :bar=> false})
    end

    it "can evaluate block" do
        p = Terraformation::TerraformProxy.new("test")
        p.load_from_block do
            resource "type", "name" do
                foo "one"
                bar true
            end
        end

        expect(p.export["resource"]["type"]["name"]).to eq({:foo => "one", :bar=> true})
    end

    describe "resource" do
        it "can use block notation" do
            p = Terraformation::TerraformProxy.new("test")
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

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:from_port]).to eq(0)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:protocol]).to eq("-1")
        end

        it "can do ingress into array multiple times" do
            p = Terraformation::TerraformProxy.new("test")
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

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:test]).to eq("first")
            expect(p.export["resource"]["type"]["name"][:ingress][1][:test]).to eq("second")
        end

        it "can do ingress into array multiple times 2" do
            p = Terraformation::TerraformProxy.new("test")
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

            expect(p.export["resource"]["type"]["name"][:foo]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq(true)
            expect(p.export["resource"]["type"]["name"][:ingress][0][:test]).to eq("first")
            expect(p.export["resource"]["type"]["name"][:ingress][1][:test]).to eq("second")
            expect(p.export["resource"]["type"]["name"][:ingress][2][:test]).to eq("3rd")
        end 

        it "can refer to an already set property later in resource definition block" do
            p = Terraformation::TerraformProxy.new("test")
            p.load_from_block do
                resource "type", "name" do
                    name "one"
                    bar name
                end
            end
            expect(p.export["resource"]["type"]["name"][:name]).to eq("one")
            expect(p.export["resource"]["type"]["name"][:bar]).to eq("one")

        end       

    end

    describe("included templates") do
        it("is possible to include a file with a function and define resources via that function") do

            p = Terraformation::TerraformProxy.new("spec/terraformation/suite_test2/main_file.rb")
            p.load_from_file()

            expect(p.export["resource"]["type"]["name1"]).to eq({:foo => "I'm Garo"})
            expect(p.export["resource"]["type"]["name2"]).to eq({:property => "test"})
            expect(p.export["resource"]["type"]["name3"]).to eq({:foo => "test3"})

        end
   
    end

    describe("expose outputs") do
        it("is possible to expose an output variable") do
            p = Terraformation::TerraformProxy.new("test")
            p.load_from_block do
                output "foobar", "${aws_instance.master.0.public_ip}"
            end

            expect(p.export["output"]["foobar"]["value"]).to eq("${aws_instance.master.0.public_ip}")
            
        end
    end    

    describe("expose variables") do
        it("is possible to define a simple string variable") do
            p = Terraformation::TerraformProxy.new("test")
            p.load_from_block do
                variable "foobar", "Hello, World!"
            end

            expect(p.export["variable"]["foobar"]["default"]).to eq("Hello, World!")

        end
    end


end
