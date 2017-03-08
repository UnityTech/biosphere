require 'biosphere'
require 'pp'

RSpec.describe Biosphere::TerraformProxy do

    it "can call Kube module" do
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
        val = nil
        p.load_from_block do
            val = kube_test("hello")
        end

        p.evaluate_resources()
        expect(val).to eq("hello")
    end

    it "can call Kube module from inside a resource" do
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
        p.load_from_block do
            resource "type", "name" do
                name kube_test("hello")
            end
        end
        p.evaluate_resources()
        
        expect(p.export["resource"]["type"]["name"][:name]).to eq("hello")
        
    end

    it "can load a manifest file" do
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
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
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
        resources = nil
        p.load_from_block do
            resources = kube_load_manifest_files("spec/biosphere/kube2/")
        end

        p.evaluate_resources()
        expect(resources.length).to eq(3)
    end

    describe "kube_merge_resource_for_put!" do
        it "can merge new values in" do
            current = {
                :metadata => {
                    :name => "foo"
                }
            }
            new_version = {
                :metadata => {
                    :name => "foo"
                },
                :bar => 2
            }
            
            modified = ::Biosphere::Kube.kube_merge_resource_for_put!(current, new_version)
            expect(modified[:metadata][:name]).to eq("foo")
            expect(modified[:bar]).to eq(2)
        end

        it "can merge nested value in" do
            current = {
                :metadata => {
                    :name => "foo"
                }
            }
            new_version = {
                :metadata => {
                    :name => "foo"
                },
                :bar => {
                    :baz => 3
                }
            }

            modified = ::Biosphere::Kube.kube_merge_resource_for_put!(current, new_version)
            expect(modified[:metadata][:name]).to eq("foo")
            expect(modified[:bar]).to eq({:baz => 3})
        end

        it "will remove removed attributes" do
            current = {
                :metadata => {
                    :name => "foo",
                    :labels => {
                        :"k8s-app" => "test",
                        :"version" => "v1"
                    }
                }
            }
            new_version = {
                :metadata => {
                    :name => "foo",
                    :labels => {
                        :"k8s-app" => "test"
                    }
                }
            }

            modified = ::Biosphere::Kube.kube_merge_resource_for_put!(current, new_version)
            expect(modified[:metadata][:labels][:"k8s-app"]).to eq("test")
            expect(modified[:metadata][:labels]).not_to have_key(:version)
        end

        it "will merge important attributes from current to new" do
            current = {
                :metadata => {
                    :name => "foo",
                    :selfLink => "self-link",
                    :uid => "uid",
                    :resourceVersion => "123",
                    :labels => {
                        :"k8s-app" => "test"
                    }
                },
                :spec => {
                    :clusterIP => "1.0.0.0"
                }
            }
            new_version = {
                :metadata => {
                    :name => "foo",
                    :labels => {
                        :"k8s-app" => "test"
                    }
                }
            }

            modified = ::Biosphere::Kube.kube_merge_resource_for_put!(current, new_version)
            expect(modified[:metadata][:labels][:"k8s-app"]).to eq("test")
            expect(modified[:metadata][:selfLink]).to eq("self-link")
            expect(modified[:metadata][:uid]).to eq("uid")
            expect(modified[:metadata][:resourceVersion]).to eq("123")
            expect(modified[:spec][:clusterIP]).to eq("1.0.0.0")
        end

        it "will raise ArgumentError when trying to modify immutable property" do
            current = {
                :spec => {
                    :clusterIP => "1.0.0.0"
                }
            }
            new_version = {
                :spec => {
                    :clusterIP => "1.0.0.2"
                }
            }

            expect { Biosphere::Kube.kube_merge_resource_for_put!(current, new_version) }.to raise_error(ArgumentError)
        end

    end

end
