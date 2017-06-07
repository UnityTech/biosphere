require 'aws-sdk'

class S3
    def initialize(bucket, main_key)
        if !ENV['AWS_REGION'] || !ENV['AWS_SECRET_KEY'] || !ENV['AWS_ACCESS_KEY']
            puts "You need to specify AWS_REGION, AWS_ACCESS_KEY and AWS_SECRET_KEY"
            exit -1
        end
        @client = Aws::S3::Client.new
        @bucket_name = bucket
        @main_key = main_key
    end

    def save(path_to_file)
        filename = path_to_file.split('/')[-1]
        key = "#{@main_key}/#{filename}"
        puts "Saving #{path_to_file} to S3 #{key}"
        begin
            File.open(path_to_file, 'rb') do |file|
                @client.put_object({
                    :bucket => @bucket_name,
                    :key => key,
                    :body => file
                })
            end
        rescue
            puts "\nError occurred while saving the remote state, can't continue"
            puts "Error: #{$!}"
            exit 1
        end
    end

    def retrieve(path_to_file)
        filename = path_to_file.split('/')[-1]
        key = "#{@main_key}/#{filename}"
        puts "Fetching #{filename} from S3 from s3://#{@bucket_name}/#{key} (#{ENV['AWS_REGION']})"
        begin
            resp = @client.get_object({
                :bucket => @bucket_name,
                :key => key
            })
            File.open(path_to_file, 'w') do |f|
                f.puts(resp.body.read)
            end
        rescue Aws::S3::Errors::NoSuchKey
            puts "Couldn't find remote file #{filename} from S3 at #{key}"
        rescue
            puts "\nError occurred while fetching the remote state, can't continue."
            puts "Error: #{$!}"
            exit 1
        end
    end

    def delete_object(path_to_file)
        filename = path_to_file.split('/')[-1]
        key = "#{@main_key}/#{filename}"
        puts "Fetching #{filename} from S3 from #{key}"
        begin
            resp = @client.delete_object({
                :bucket => @bucket_name,
                :key => key
            })
        rescue Aws::S3::Errors::NoSuchKey
            puts "Couldn't find remote file #{filename} from S3 at #{key}"
        rescue
            puts "\nError occurred while deleting file #{path_to_file}."
            puts "Error: #{$!}"
            exit 1
        end
    end

    def set_lock()
        begin
            resp = @client.get_object({
                :bucket => @bucket_name,
                :key => "#{@main_key}/biosphere.lock"
            })
            puts "\nThe remote state is locked since #{resp.last_modified}\nCan't continue."
            exit 1
        rescue Aws::S3::Errors::NoSuchKey
            puts "\nRemote state was not locked, adding the lockfile.\n"
            @client.put_object({
                :bucket => @bucket_name,
                :key => "#{@main_key}/biosphere.lock"
            })
        rescue
            puts "\There was an error while accessing the lock. Can't continue.'"
            puts "Error: #{$!}"
            exit 1
        end
    end

    def release_lock()
        begin
            @client.delete_object({
                :bucket => @bucket_name,
                :key => "#{@main_key}/biosphere.lock"
            })
        rescue
            puts "\nCouldn't release the lock!"
            puts "Error: #{$!}"
            exit 1
        end
        puts "\nLock released successfully"
    end
end
