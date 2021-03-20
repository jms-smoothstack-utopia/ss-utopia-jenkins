# Utopia - Jenkins CI
This repository contains all required elements for instantiating a fresh Jenkins continuous integration server with Sonarqube. This is currently deployed on AWS and available at [http://ec2-52-90-241-158.compute-1.amazonaws.com:8080](http://ec2-52-90-241-158.compute-1.amazonaws.com:8080). Additionally, Sonarqube reports can be accessed at [http://ec2-52-90-241-158.compute-1.amazonaws.com:9000](http://ec2-52-90-241-158.compute-1.amazonaws.com:9000).

For credentials, please contact [Stephen Gerkin](mailto:stephen.gerkin@smoothstack.com).

## AWS Infrastructure
The stack created for this instance is fully self-contained and provides its own VPC, Subnet, routing, and EC2 instance with CloudFormation. The template for this is available at [./jenkins-stack.yaml](./jenkins-stack.yaml). Not included in this repository are the parameters that provide SSH access to the EC2 instance. This can either be provided as a JSON file in `.secret/jenkins-params.json` to be run with the `create.ps1` script for creating a new CF stack, or provided during creation with the AWS CLI.

The template design creates the following stack:
![template design](https://utopia-documentation-media.s3.amazonaws.com/jenkins/template1-designer.png)

## Creation
The [create.ps1](./create.ps1) file contains the AWS CLI command for creating a new stack. The stack name for this is hardcoded in the script and meant only as a reference for intial creation. If additional copies of this stack should be created, use the following command (substituting as necessary) in a bash terminal:
```sh
aws cloudformation create-stack \
  --stack-name ${STACK_NAME} \
  --region=us-east-1 \
  --template-body file://jenkins-stack.yaml \
  --parameters file://.secret/jenkins-params.json \
  --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"
```
Or
```powershell
aws cloudformation create-stack `
  --stack-name $env:STACK_NAME `
  --region=us-east-1 `
  --template-body file://jenkins-stack.yaml `
  --parameters file://.secret/jenkins-params.json `
  --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"
```

Both commands assume the presence of an included JSON file for the parameters that should be written as:
```json
[
  {
    "ParameterKey":"AccessCidr",
    "ParameterValue":"FULL CIDR FOR SSH ACCESS"
  },
  {
    "ParameterKey":"SSHKeyName",
    "ParameterValue":"EXISTING SSH KEY NAME"
  }
]
```

The stack uses a custom AMI that includes all Utopia projects as pipeline projects within Jenkins as of 2021-03-16. Future revisions of the AMI will need to be provided as a parameter to the stack. The keyname for this property is `ImageId` and can be included in the above mentioned JSON file:
```json
[
  {
    "ParameterKey":"ImageId",
    "ParameterValue":"ami-____"
  }
]
```

## Jenkins UI
The Jenkins instance includes an install of the Blue Ocean UI for simpler pipeline management. Additional pipelines can be included by entering the Blue Ocean UI and clicking `New Pipeline`. From there, follow the prompts as appropriate and click `Create Pipeline`:
![Blue Ocean New Pipeline](https://utopia-documentation-media.s3.amazonaws.com/jenkins/blue-ocean.png)

Additionally, a webhook must be created on GitHub to allow it to push changes to the repository with a payload URL of `http://ec2-52-90-241-158.compute-1.amazonaws.com:8080/github-webhook/`
![GitHub webhook creation](https://utopia-documentation-media.s3.amazonaws.com/jenkins/github-webhook.png)

## Unconfigured Instance
For a fresh, unconfigured instance with no credentials initialized (useful for creating a new AMI) can be created with the included [userdata-unconfigured.sh](./userdata-unconfigured.sh) file. This will create a new Jenkins and Sonarqube instance with no configuration.

The userdata file additionally includes the creation of a service daemon that will automatically turn on Jenkins and Sonarqube should the instance be rebooted or stopped and restarted for any reason.

After creating an EC2 with the userdata file, SSH into the instance to get the initial admin password for Jenkins by executing
```sh
$ docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Then open the Jenkins UI (on port 8080) to configure the instance with the username `admin` and the aforementioned password.

Sonarqube will also need administrative configuration and can be accessed with the default `admin:admin` username and password (on port 9000).

Once configured, a new AMI can be created from the configured settings and the [jenkins-stack.yaml](./jenkins-stack.yaml) template can be used with the new AMI ID.

## Example Build
Using the Blue Ocean UI, the full build pipeline can be clearly visualized. Each stage of the build can be inspected and log output for that individual stage can be reviewed for feedback for problems.

An example of a passing build is seen here:
![Passing Build](https://utopia-documentation-media.s3.amazonaws.com/jenkins/example_passing_build.png)

Should a build fail, we can inspect the specific stage for the specific causes for the failure:
![Failing Build](https://utopia-documentation-media.s3.amazonaws.com/jenkins/example_failing_build.png)

## Sonarqube Results
After the build has gone through the Sonarqube Quality Gates, we can visually inspect the output and address potential security hotspots, code smells, and review code coverage for specific files.
![Sonarqube Example](https://utopia-documentation-media.s3.amazonaws.com/jenkins/example_sonar.png)

## Example Jenkinsfile
The following Jenkinsfile is an example of a full build for one of the backend services, specifically the Authentication Service. For the orignal source, please [visit the repository](https://github.com/jms-smoothstack-utopia/ss-utopia-auth).

The pipeline accomplishes the following tasks:
1. Checkout the code from GitHub
2. Clean/Remove any existing binaries if present.
3. Run the [Apache Maven Checkstyle Plugin](https://maven.apache.org/plugins/maven-checkstyle-plugin/) against the [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html). Any violations will fail the pipeline.
4. Run all unit tests and package the `.jar` files. Any test failures will fail the pipeline.
5. Run static code analysis with the [SpotBugs Maven Plugin](https://spotbugs.github.io/) to find common coding mistakes. Any bugs found will fail the pipeline.
6. Run static code analysis with [PMD Source Code Analyzer Maven Plugin](https://pmd.github.io/) to find additional mistakes not found by the previous step. Any bugs found will fail the pipeline.
7. Run [Sonarqube Code Analysis](https://www.sonarqube.org/) to find bugs, code smells, security hotspots, and test code coverage.
8. Await the results of a Sonarqube Quality Gate. The quality gate is the default "Sonar way" and consists of the following checks:
![Quality Gate controls](https://utopia-documentation-media.s3.amazonaws.com/jenkins/quality-gate.png)
Any error returned from the quality gate will fail the pipeline.
9. Build the project into a Docker image. Failure to build will result in a pipeline failure.
10. If on the main branch, the built Docker image will be pushed to AWS ECR for deployment.

Finally, once the pipeline is complete (regardless of failure or success), all built items will be cleaned from the system to prevent clutter and save on storage costs.

```groovy
pipeline {
    agent any
    stages {
        stage('Clean target') {
            steps {
                sh 'mvn clean'
            }
        }
        stage('Lint') {
            steps {
                sh 'mvn checkstyle:check'
            }
        }
        stage('Test and Package') {
            steps {
                sh 'mvn test package'
            }
        }
        stage('Code Analysis: SpotBugs') {
            steps {
                sh 'mvn spotbugs:check'
            }
        }
        stage('Code Analysis: PMD') {
            steps {
                sh 'mvn pmd:check'
            }
        }
        stage('Code Analysis: Sonarqube') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }
        stage('Await Quality Gateway') {
            steps {
                waitForQualityGate abortPipeline: true
            }
        }
        stage('Build Docker image') {
            steps {
                sh 'mvn docker:build'
            }
        }
        stage('Push image to repository') {
            when {
                branch 'main'
            }
            steps {
                sh 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 247293358719.dkr.ecr.us-east-1.amazonaws.com'
                sh 'mvn docker:push'
            }
        }
    }
    post {
        always {
            sh 'mvn clean -Ddocker.removeMode=all docker:remove'
            sh 'docker system prune -f'
        }
    }
}

```