require 'biosphere'
require 'pp'

RSpec.describe Biosphere::TerraformProxy do

    it "can call Kube module" do
        p = Biosphere::TerraformProxy.new("test")
        val = nil
        p.load_from_block do
            val = kube_test("hello")
        end

        p.evaluate_resources()
        expect(val).to eq("hello")
    end

    it "can call Kube module from inside a resource" do
        p = Biosphere::TerraformProxy.new("test")
        p.load_from_block do
            resource "type", "name" do
                name kube_test("hello")
            end
        end
        p.evaluate_resources()
        
        expect(p.export["resource"]["type"]["name"][:name]).to eq("hello")
        
    end

    it "can load a manifest file" do
        p = Biosphere::TerraformProxy.new("test")
        resources = nil
        p.load_from_block do
            resources = kube_load_manifest_file("spec/biosphere/kube/test.yaml")
        end

        p.evaluate_resources()
        expect(resources[0].apiVersion).to eq("v1")
        expect(resources[0].kind).to eq("Service")
        expect(resources[0].class).to eq(::Kubeclient::Resource)
        expect(resources[1].apiVersion).to eq("v1")
        expect(resources[1].kind).to eq("ReplicationController")
        expect(resources[1].class).to eq(::Kubeclient::Resource)
    end

    describe "underscore_case" do
        it "will convert CamelCase into camel_case" do
            expect("CamelCase".underscore_case).to eq("camel_case")
            expect("CamelCaseCaseCase".underscore_case).to eq("camel_case_case_case")
        end

        it "will convert Camel into camel" do
            expect("Camel".underscore_case).to eq("camel")
        end
        
    end
    
    it "can load a directory hierarchy of manifest files" do
        p = Biosphere::TerraformProxy.new("test")
        resources = nil
        p.load_from_block do
            resources = kube_load_manifest_files("spec/biosphere/kube2/")
        end

        p.evaluate_resources()
        expect(resources.length).to eq(3)
    end

end
