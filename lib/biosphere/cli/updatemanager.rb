require 'pp'
require 'treetop'
require 'colorize'
require 'rest-client'

class Biosphere

    class CLI
        class UpdateManager


            def self.check_for_update(current_version = ::Biosphere::Version)
                begin
                    response = RestClient::Request.execute(method: :get, url: 'https://rubygems.org/api/v1/versions/biosphere/latest.json', timeout: 1)

                    if response.code != 200
                        return nil
                    end

                    data = JSON.parse(response.body)

                    info = {
                        latest: data["version"],
                        current: current_version,
                    }

                    info[:up_to_date] = Gem::Version.new(info[:current]) == Gem::Version.new(info[:latest])

                    return info
                rescue JSON::ParserError
                    return nil
                rescue RestClient::Exceptions::OpenTimeout
                    return nil
                rescue RestClient::Exceptions::ReadTimeout
                    return nil
                end
            end

        end
    end
end
