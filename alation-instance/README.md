# Terraform script to create an EC2 instance for alation 
# Make sure create and upload ssh key in AWS


## create new instance
  * create new folder
  ```
  mkdir agent
  ```

 * setup the any custom variables in agent/main.tf

 * Run below to create agent
  
  ```
  terraform -chdir=./agent init
  terraform -chdir=./agent plan -out=tfplan 
  terraform -chdir=./agent apply -auto-approve 
  ```
 * To destroy
  ```
  terraform -chdir=./agent destroy -auto-approve 
  ```
