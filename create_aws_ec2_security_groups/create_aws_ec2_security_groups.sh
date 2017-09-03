#!/bin/bash

CreateAWSSecurityGroup(){

   # This function will create Amazon Web Services security groups using the AWS CLI tool
   
   echo "Creating security group named ${sg_name} with for ${vpc_identifier} with the following description - ${sg_description}"
   aws ec2 create-security-group --group-name "${sg_name}" --description "${sg_description}" --vpc-id "${vpc_identifier}"

}

# This script sets up security groups for a specified VPC in AWS. Rules in the security 
# group(s) are set to the default configuration when the security group is created.
#
# You can add multiple security groups using the CreateAWSSecurityGroup function
# For each group, add a new name and description, then call the CreateAWSSecurityGroup
# function as shown.

sg_name="First Security Group Name Goes Here"
sg_description="Describe Security Group Purpose Here"
vpc_identifier="vpc_id_goes_here"

CreateAWSSecurityGroup

sg_name="Second Security Group Name Goes Here"
sg_description="Describe Second Security Group Purpose Here"

CreateAWSSecurityGroup

sg_name="Third Security Group Name Goes Here"
sg_description="Describe Third Security Group Purpose Here"

CreateAWSSecurityGroup