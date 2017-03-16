load './classes/sub_deployment/main.rb'

global_settings = {
    region: "us-east-1",

    # This is the name of the S3-bucket that will be used to store remote state
    s3_bucket: "techops-biosphere-test",
}

a = SubDeployment.new("subdeployment", global_settings.deep_merge({
    deployment_name: "subdeployment",
    my: "sub-deployment",
    region: "us-east-1"
}))

register(a)