########################################
# State backend — DEV
#
# For easy offline review this committed config uses Terraform's default
# LOCAL backend, so the following work with no flags and no AWS account:
#     terraform init
#     terraform validate
#     terraform plan -refresh=false
#
# The production remote-state configuration (S3 + DynamoDB lock, with a
# bucket/key unique to this environment) lives in `backend-s3.tf.example`.
# To use it for a real deployment, rename that file to `backend.tf` and run
# `terraform init` (Terraform will offer to migrate the local state).
########################################

# (No backend block here => Terraform uses the local backend.)
