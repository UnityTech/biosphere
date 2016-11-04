require 'biosphere'
require 'pp'

RSpec.describe IPAddress::IPv4 do

    it "can be constructed" do
        a = IPAddress::IPv4.new("10.0.0.0/24")
        expect(a).not_to be_nil
    end

    it "can allocate addresses" do
        a = IPAddress::IPv4.new("10.0.0.0/24")
        ip1 = a.allocate
        ip2 = a.allocate
        ip3 = a.allocate
        expect(ip1.address).to eq("10.0.0.1")
        expect(ip2.address).to eq("10.0.0.2")
        expect(ip3.address).to eq("10.0.0.3")
    end

    it "can skip addresses" do
        a = IPAddress::IPv4.new("10.0.0.0/24")
        ip1 = a.allocate(2)
        expect(ip1.address).to eq("10.0.0.3")
    end    

    it "will raise StopIteration" do
        a = IPAddress::IPv4.new("10.0.0.0/30")
        ip1 = a.allocate
        ip2 = a.allocate
        ip3 = a.allocate
        ip4 = a.allocate
        expect{a.allocate}.to raise_error(StopIteration)
    end    
end
