require 'biosphere'
require 'pp'
require 'json'
require 'fileutils'

RSpec.describe Biosphere::Node do

    it "has a constructor" do
        s = Biosphere::Node.new
    end

    it "can get a new property" do
        s = Biosphere::Node.new
        s[:foo] = "bar"
        expect(s[:foo]).to eq("bar")
    end

    it "can get a new nested property" do
        s = Biosphere::Node.new
        s.deep_set(:foo, :bar, "foobar")
        expect(s[:foo][:bar]).to eq("foobar")
    end

    it "can evaluate to false when checking if a missing key exists" do
        s = Biosphere::Node.new
        if s.include?(:foo)
            expect(false).to eq(true)
        end
    end    

    it "can marshall itself into a string" do
        s = Biosphere::Node.new
        s.deep_set(:foo, :bar, "foobar")
        str = s.save()
        expect(str).to eq("\x04\bC:\x1FBiosphere::Node::Attribute{\x06:\bfooC;\x00{\x06:\bbarI\"\vfoobar\x06:\x06ET")
    end

    it "can load itself from a string" do
        s = Biosphere::Node.new("\x04\bC:\x1FBiosphere::Node::Attribute{\x06:\bfooC;\x00{\x06:\bbarI\"\vfoobar\x06:\x06ET")
        expect(s[:foo][:bar]).to eq("foobar")
    end

    it "will raise exception if trying to load old format" do
        expect {
            s = Biosphere::Node.new("\x04\bo:\x14Biosphere::Node\x06:\n@data{\x06:\bfooo;\x00\x06;\x06{\x06:\bbarI\"\vfoobar\x06:\x06ET")       
        }.to raise_exception RuntimeError
    end

end
