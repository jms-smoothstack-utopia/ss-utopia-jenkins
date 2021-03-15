aws cloudformation create-stack `
--stack-name JenkinsCI `
--region=us-east-1 `
--template-body file://jenkins-stack.yaml `
--parameters file://.secret/jenkins-params.json `
--capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"