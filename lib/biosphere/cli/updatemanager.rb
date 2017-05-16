require 'pp'
require 'treetop'
require 'colorize'
require 'net/http'

class Biosphere

    class CLI
        class UpdateManager


            def check_for_update(version = ::Biosphere::Version)
                url = URI('https://rubygems.org/api/v1/versions/biosphere/latest.json')

                response = get_response_with_redirect(url)
                pp response

                return info
            end

            private
            def get_response_with_redirect(uri)
                r = Net::HTTP.get_response(uri)
                if r.code == "301"
                    r = Net::HTTP.get_response(URI.parse(r.header['location']))
                end
                r
            end
        end
    end
end
