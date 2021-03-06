require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::Settings do

    it "has a constructor" do
        s = Biosphere::Settings.new
    end

    it "can have defaults" do
        class TestSettings < Biosphere::Settings
            settings({
                name: "foo"
            })
        end

        expect(Biosphere::Settings.settings_hash).to eq({})
        expect(TestSettings.settings_hash[:name]).to eq("foo")
        expect(Biosphere::Settings.settings).to eq({})
        expect(TestSettings.settings[:name]).to eq("foo")
    end

    it "can have manifests" do
        class TestSettings < Biosphere::Settings
            settings({
                name: "foo"
            })

            add_feature_manifest :example, "foo.yaml"
            add_feature_manifest :example, "bar.yaml"
            add_feature_manifest :example2, "bar2.yaml"
        end
        
        expect(Biosphere::Settings.settings_hash).to eq({})
        expect(TestSettings.settings_hash[:name]).to eq("foo")
        expect(Biosphere::Settings.settings).to eq({})
        expect(TestSettings.settings[:name]).to eq("foo")

        expect(Biosphere::Settings.feature_manifests[:example]).to eq(nil)
        expect(TestSettings.feature_manifests(:example)[0]).to eq("foo.yaml")
        expect(TestSettings.feature_manifests(:example)[1]).to eq("bar.yaml")
        expect(TestSettings.feature_manifests(:example2)[0]).to eq("bar2.yaml")
    end

    it "can be created multiple times into an instance" do

        a = Biosphere::Settings.new({foo: "1"})
        b = Biosphere::Settings.new({foo: "2"})
        c = Biosphere::Settings.new({foo: "3", bar: "bar"})

        expect(Biosphere::Settings.settings_hash).to eq({})
        expect(a.settings[:foo]).to eq("1")
        expect(b.settings[:foo]).to eq("2")
        expect(c.settings[:foo]).to eq("3")
        expect(c.settings[:bar]).to eq("bar")
    end

    it "can be nested with classes" do
        class SuperSettings < Biosphere::Settings
            settings({
                name: "super",
                biosphere: {
                    s3_bucket: "test"
                }
            })

            add_feature_manifest :example, "foo.yaml"
        end

        class NestedSettings < SuperSettings
            settings({
                name: "overwritten",
                biosphere: {
                    state_name: "test-state"
                }
            })

            add_feature_manifest :example, "bar.yaml"
            
        end

        expect(Biosphere::Settings.settings).to eq({})

        expect(SuperSettings.settings[:name]).to eq("super")
        expect(SuperSettings.settings[:biosphere]).to eq({s3_bucket: "test"})

        expect(NestedSettings.settings[:name]).to eq("overwritten")
        expect(NestedSettings.settings[:biosphere]).to eq({s3_bucket: "test", state_name: "test-state"})

        expect(Biosphere::Settings.feature_manifests[:example]).to eq(nil)
        expect(SuperSettings.feature_manifests[:example][0]).to eq("foo.yaml")
        expect(SuperSettings.feature_manifests[:example][1]).to eq(nil)
        expect(NestedSettings.feature_manifests[:example][0]).to eq("foo.yaml")
        expect(NestedSettings.feature_manifests[:example][1]).to eq("bar.yaml")


        a = NestedSettings.new
        expect(a.settings[:name]).to eq("overwritten")
        expect(a.feature_manifests[:example][0]).to eq("foo.yaml")
        expect(a.feature_manifests[:example][1]).to eq("bar.yaml")
        
    end

    it "can be nested with classes" do
        class SuperSettings < Biosphere::Settings
            settings({
                name: "super"
            })
        end

        class NestedSettings < SuperSettings
            settings({
                name: "overwritten"
            })
        end

        expect(Biosphere::Settings.settings).to eq({})
        expect(SuperSettings.settings[:name]).to eq("super")
        expect(NestedSettings.settings[:name]).to eq("overwritten")

        a = NestedSettings.new
        expect(a.settings[:name]).to eq("overwritten")
    end

    it "can be instantiated with settings" do
        class SuperSettings < Biosphere::Settings
            settings({
                name: "super"
            })
        end

        class NestedSettings < SuperSettings
            settings({
                name: "overwritten"
            })
        end

        a = NestedSettings.new
        expect(a.settings[:name]).to eq("overwritten")

        b = NestedSettings.new({foo: "bar"})
        expect(b.settings[:name]).to eq("overwritten")
        expect(b.settings[:foo]).to eq("bar")

        c = NestedSettings.new({foo: "bar", name: "instantiated"})
        expect(c.settings[:name]).to eq("instantiated")
        expect(c.settings[:foo]).to eq("bar")

    end

    it "can build a nested path name" do
        class SuperSettings < Biosphere::Settings
            settings({
                name: "super"
            })
        end

        class NestedSettings < SuperSettings
            settings({
                name: "overwritten"
            })
        end

        a = NestedSettings.new
        expect(a.path).to eq("SuperSettings/NestedSettings")


    end
end
