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

    describe "deep_set" do
        it "can get a new nested property" do
            s = Biosphere::Node.new
            s.deep_set(:foo, :bar, "foobar")
            expect(s[:foo][:bar]).to eq("foobar")
        end

        it "can get a new nested without destroying old one" do
=begin
            s = Biosphere::Node.new
            puts "1111111111111"
            s.deep_set(:foo, :bar, {})
            expect(s[:foo][:bar]).to eq({})

            s[:foo][:bar]["1"] = 1
            expect(s[:foo][:bar]["1"]).to eq(1)

            puts "11111111111112"

            s.deep_set(:foo, :bar, "2", 2)
            expect(s[:foo][:bar]["1"]).to eq(1)
            expect(s[:foo][:bar]["2"]).to eq(2)
=end
        end

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
