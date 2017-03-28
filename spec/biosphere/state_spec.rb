require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::State do

    it "has a constructor" do
        s = Biosphere::State.new()
        s.node[:foo] = "bar"
        expect(s.node()[:foo]).to eq("bar")
        
    end


    it "can save state to file" do
        if File.exists?("spec/biosphere/state_save/state.node")
            File.delete("spec/biosphere/state_save/state.node")
        end

        s = Biosphere::State.new
        s.node[:foo] = "bar"
        s.save("spec/biosphere/state_save/state.node")

        expect(File.exists?("spec/biosphere/state_save/state.node")).to eq(true)
    end

    it "can load state from file automatically" do
        s = Biosphere::State.new("spec/biosphere/state_save/state.node")
        expect(s.node[:foo]).to eq("bar")
    end

    describe "load_from_structure!" do
        it "can merge loaded state into a nested state tree" do

            s = Biosphere::State.new
            s.node[:root] = "root"
            s.node[:deployments] = {
                "foo" => {
                },
                "bar" => {
                }
            }

            foo = s.node[:deployments]["foo"]
            bar = s.node[:deployments]["bar"]

            structure = Class.new {
                attr_accessor :data
            }.new
            structure.data = {
                root: "root",
                deployments: {
                    "foo" => {
                        name: "foo",
                        certs: {
                            machine: "cert 1 here"
                        }
                    },
                    "bar" => {
                        name: "bar",
                        certs: {
                            machine: "cert 2 here"
                        }
                    }
                },
                nested: {
                    very: {
                        wow: "yeah"
                    }
                }
            }

            s.load_from_structure!(structure)

            expect(foo[:name]).to eq("foo")
            expect(bar[:name]).to eq("bar")

            expect(foo[:certs][:machine]).to eq("cert 1 here")
            expect(bar[:certs][:machine]).to eq("cert 2 here")

            expect(s.node[:nested][:very][:wow]).to eq("yeah")

        end

        it "can remove feature manifests on merge" do
            s = Biosphere::State.new
            s.node[:root] = "root"

            # This is the state which the new build created.
            # We'll simulate a situation where there was more than one feature_manifests under "foo" .. "test"
            # but then that gets removed
            s.node[:deployments] = {
                "foo" => {
                    feature_manifests: {
                        test: [
                            "foo"
                        ]
                    }
                },
                "bar" => {
                    feature_manifests: {
                        test: [
                            "foo",
                            "bar"
                        ]
                    }
                },
                "baz" => {
                    feature_manifests: {
                        test: [
                            "foo"
                        ]
                    }
                }                
            }

            foo = s.node[:deployments]["foo"]
            bar = s.node[:deployments]["bar"]

            structure = Class.new {
                attr_accessor :data
            }.new

            # This represents the stored state where the "foo" .. "test" still had more than one feature_manifest
            structure.data = {
                deployments: {
                    "foo" => {
                        feature_manifests: {
                            test: [
                                "foo",
                                "bar"
                            ]
                        }
                    },
                    "bar" => {
                        feature_manifests: {
                            test: [
                                "foo"
                            ]
                        }
                    },
                    "baz" => {
                        feature_manifests: {
                            test: [
                                "foo"
                            ]
                        }
                    }
                }
            }

            s.load_from_structure!(structure)

            # Make sure the feature manifest is removed
            expect(s.node[:deployments]["foo"][:feature_manifests][:test]).to eq(["foo"])

            # And placed into the removed list
            expect(s.node[:deployments]["foo"][:removed_feature_manifests][:test]).to eq(["bar"])

            # This should be the same
            expect(s.node[:deployments]["bar"][:feature_manifests][:test]).to eq(["foo", "bar"])
            expect(s.node[:deployments]["baz"][:feature_manifests][:test]).to eq(["foo"])

        end
    end
    
end
