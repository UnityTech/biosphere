require 'ipaddress'

class IPAddress::IPv4

    def allocate(skip = 0)
        if !@allocator
            @allocator = 1
        else
            @allocator += + 1
        end

        @allocator += skip

        next_ip = network_u32+@allocator
        if next_ip > broadcast_u32+1
            raise StopIteration
        end
        self.class.parse_u32(network_u32+@allocator, @prefix)
    end

end