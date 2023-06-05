# ErlyTalk - Infrastructure as Code

It provides a fully automated end-to-end deployment of the ErlyTalk Messaging Service and Web application on AWS. It leverages Terraform and Ansible to provision and configure the necessary AWS resources, allowing for seamless scaling based on the load.

- The various AWS services such as VPC, EC2, Route 53, S3, DynamoDB, CloudWatch, EKS, and IAM are utilized for the infrastructure.
- The infrastructure is provisioned by using Terraform.
- Deployment of micro-services on EKS (Kubernetes) is carried out using Ansible.
- Automatic scaling of the EKS cluster is facilitated by Kubernetes Autoscaler.
- Container Insights is used to monitor the EKS cluster, providing valuable insights into its performance and health.
- DNS records for EKS Ingress and Services are created in Route 53 using ExternalDNS.
- Provisioning of ALB/NLB for EKS Ingress and Services is handled by AWS Load Balancer Controller.

## Pre-requirements
- AWS access & secret key (name: erlytalk-terraform | Minimum AWS permissions necessary for a Terraform run)
- Private bucket to store terraform state (name: erlytalk-iac-terraform-state)
- DynamoDB table to state locking and consistency (name: erlytalk-iac-terraform-locks | Partition key: "LockID")

### Requirements packages
- terraform
- awscli
- kubectl
- helm
- python3.8
- pipenv

### Set the AWS credential
```bash
export AWS_ACCESS_KEY_ID="<YOUR_AWS_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_AWS_SECRET_ACCESS_KEY>"
```

## Getting start
Since we use some external projects as submodules, it's necessary to run the command below to get the repositories:
```bash
git submodule update --init --recursive
```

### Customize
- To edit the resource sizes and configurations, modify the dev.tfvars file in the terraform directory as well as ansible/inventories/dev/.
- To add users, modify the main.yml file in the ansible/user-mgmt/defaults directory.
- You can change the S3 bucket and DynamoDB table that Terraform stores the state in by modifying the terraform/providers.tf file.

### Use Terraform to build infrastructure on AWS
```bash
cd terraform
terraform init
terraform workspace new dev / terraform workspace select dev
terraform apply --var-file=dev.tfvars
```

### Use Ansible to configure the infrastructure (for fresh installation)
```bash
cd assets
chmod 400 dev_keypair_default
ssh-add dev_keypair_default
cd ansible
pipenv install
pipenv shell
ansible-playbook site.yml -i inventories/dev -e "presetup_mode=upgrade ansible_user=root" --tags never,all 
```

### Run Ansible (for non-fresh installation)
```bash
ansible-playbook site.yml -i inventories/dev -e "ansible_user=your-username"
```

### SSH private key passphrase
If you want to bypass the key's passphrase, you will need to use an agent:
```bash
eval $(ssh-agent)
ssh-add path-to-your-key
<TYPE IN YOUR PASSPHRASE>
ssh-add -l
```

Contact
-----
For any questions or inquiries, please visit https://www.aliyousefian.com/contact.

For more information, visit the [project blog post](https://www.aliyousefian.com/880/erlytalk-project).
