require 'biosphere'
require 'pp'

RSpec.describe Biosphere::TerraformProxy do

    describe "KubeResource" do
        it "can construct" do
            document = {
                "apiVersion" => "v1"
            }
            a = Biosphere::Kube::KubeResource.new(document, "")
        end

        describe "merge_for_put" do
            it "will remove removed attributes" do
                current = {
                    "metadata" => {
                        "name" => "foo",
                        "labels" => {
                            "k8s-app" => "test",
                            "version" => "v1"
                        }
                    }
                }
                new_version = {
                    "metadata" => {
                        "name" => "foo",
                        "labels" => {
                            "k8s-app" => "test"
                        }
                    }
                }
                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")
                modified = resource.merge_for_put(current)
                expect(modified["metadata"]["labels"]["k8s-app"]).to eq("test")
                expect(modified["metadata"]["labels"]).not_to have_key("version")
            end

            it "can merge new values in" do
                current = {
                    "metadata" => {
                        "name" => "foo"
                    }
                }
                new_version = {
                    "metadata" => {
                        "name" => "foo"
                    },
                    "bar" => 2
                }

                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")
                modified = resource.merge_for_put(current)
                expect(modified["metadata"]["name"]).to eq("foo")
                expect(modified["bar"]).to eq(2)
            end

            it "can merge nested value in" do
                current = {
                    "metadata" => {
                        "name" => "foo"
                    }
                }
                new_version = {
                    "metadata" => {
                        "name" => "foo"
                    },
                    "bar" => {
                        "baz" => 3
                    }
                }

                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")
                modified = resource.merge_for_put(current)
                expect(modified["metadata"]["name"]).to eq("foo")
                expect(modified["bar"]).to eq({"baz" => 3})
            end



            it "will merge important attributes from current to new" do
                current = {
                    "metadata" => {
                        "name" => "foo",
                        "selfLink" => "self-link",
                        "uid" => "uid",
                        "resourceVersion" => "123",
                        "labels" => {
                            "k8s-app" => "test"
                        }
                    },
                    "spec" => {
                        "clusterIP" => "1.0.0.0"
                    }
                }
                new_version = {
                    "metadata" => {
                        "name" => "foo",
                        "labels" => {
                            "k8s-app" => "test"
                        }
                    }
                }

                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")
                modified = resource.merge_for_put(current)
                expect(modified["metadata"]["labels"]["k8s-app"]).to eq("test")
                expect(modified["metadata"]["selfLink"]).to eq("self-link")
                expect(modified["metadata"]["uid"]).to eq("uid")
                expect(modified["metadata"]["resourceVersion"]).to eq("123")
                expect(modified["spec"]["clusterIP"]).to eq("1.0.0.0")
            end

            it "will raise ArgumentError when trying to modify immutable property" do
                current = {
                    "spec" => {
                        "clusterIP" => "1.0.0.0",
                    }
                }
                new_version = {
                    "spec" => {
                        "clusterIP" => "1.0.0.2"
                    }
                }
                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")

                expect { resource.merge_for_put(current) }.to raise_error(ArgumentError)
            end

            it "will use jsonpath to prefer current version values" do
                current = {
                    "spec" => {
                        "replicas" => 5,
                        "template" => {
                            "spec" => {
                                "containers" => [
                                    {
                                        "name" => "container-a",
                                        "image" => "image-a:abcdef"
                                    },
                                    {
                                        "name" => "container-b",
                                        "image" => "image-b:abcdef"
                                    },
                                ]
                            }
                        }
                    }
                }
                new_version = {
                    "spec" => {
                        "replicas" => 2,
                        "template" => {
                            "spec" => {
                                "containers" => [
                                    {
                                        "name" => "container-a",
                                        "image" => "image-a:master"
                                    },
                                    {
                                        "name" => "container-b",
                                        "image" => "image-b:master"
                                    },
                                ]
                            }
                        }
                    }
                }

                resource = ::Biosphere::Kube::KubeResource.new(new_version, "testfile")
                resource.preserve_current_values = [
                    ".spec.replicas",
                    ".spec.template.spec.containers[?(@.name==\"container-a\")].image"
                ]
                modified = resource.merge_for_put(current)

                expect(modified["spec"]["replicas"]).to eq(5)
                expect(modified["spec"]["template"]["spec"]["containers"][0]["image"]).to eq("image-a:abcdef")
                expect(modified["spec"]["template"]["spec"]["containers"][1]["image"]).to eq("image-b:master")

            end
        end
    end

    it "can call Kube module" do
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
        val = nil
        p.load_from_block do
            val = kube_test("hello")
        end

        expect(val).to eq("hello")
    end

    it "can load a manifest file" do
        p = Biosphere::TerraformProxy.new("test", Biosphere::State.new)
        resources = nil
        p.load_from_block do
            resources = ::Biosphere::Kube::load_resources("spec/biosphere/kube/test.yaml")
        end

        expect(resources[0].document["apiVersion"]).to eq("v1")
        expect(resources[0].document["kind"]).to eq("Service")
        expect(resources[0].preserve_current_values.first).to eq(".spec.replicas")

        expect(resources[1].document["apiVersion"]).to eq("v1")
        expect(resources[1].document["kind"]).to eq("ReplicationController")
        expect(resources[1].preserve_current_values.first).to eq(".spec.replicas")

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
        resources = []
        p.load_from_block do
            ::Biosphere::Kube::find_manifest_files("spec/biosphere/kube2/").each do |file|
                resources += ::Biosphere::Kube::load_resources(file)
            end
        end

        expect(resources.length).to eq(3)
    end

end
