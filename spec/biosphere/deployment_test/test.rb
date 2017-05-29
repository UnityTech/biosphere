load './classes/sub_deployment/main.rb'

global_settings = {
    region: "us-east-1",

    # This is the name of the S3-bucket that will be used to store remote state
    s3_bucket: "techops-biosphere-test",
}

dummy_suite = Biosphere::Suite.new(Biosphere::State.new)
a = SubDeployment.new(dummy_suite, "subdeployment", global_settings.deep_merge({
    my: "sub-deployment",
    region: "us-east-1"
}))

register(a)
