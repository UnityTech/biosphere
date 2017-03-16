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
end
