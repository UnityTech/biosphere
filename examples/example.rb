
puts "At example.rb"

resource "type", "name",
         foo: "one",
         bar: false

resource "aws_vpc", "default",
	cidr_block: "1.0.0.0/16",
	enable_dns_hostnames: true,
	tags: {
		Name: "Garo's machine"
	}

resource "aws_security_group", "nat",
	name: "vpc-nat",
	ingress: [
		{
			from_port: 80,
			to_port: 80,
			protocol: "tcp",
			cidr_blocks: ["${var.private_subnet_cidr}"]
		}
	]