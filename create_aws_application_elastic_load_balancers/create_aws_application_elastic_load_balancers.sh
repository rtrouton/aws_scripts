#!/bin/bash

# Creating an Amazon Web Services Application Elastic Load Balancer using the AWS CLI tool

CreateAWSElasticLoadBalancer(){

   # This function will create an AWS Application Load Balancer using the AWS CLI tool
   
   echo "Creating application load balancer named ${lb_name} with the following scheme - ${elb_scheme}."
   echo "Load balancer is associated with the following subnets - ${subnet_1} ${subnet_2} ${subnet_3}"
   echo "Load balancer is associated with the following security groups - ${security_group_1} ${security_group_2} ${security_group_3} ${security_group_4} ${security_group_5}"
   aws elbv2 create-load-balancer --name "${lb_name}" --subnets "${subnet_1}" "${subnet_2}" "${subnet_3}" --security-groups "${security_group_1}" "${security_group_2}" "${security_group_3}" "${security_group_4}" "${security_group_5}" --scheme "${elb_scheme}"

}

# Create Application Elastic Load Balancer (ELB)

# Provide the following values

# Name of the ELB

lb_name="load_balancer_name_goes_here"

# Subnets to associate with the ELB

subnet_1="subnet_1_goes_here"
subnet_2="subnet_2_goes_here"
subnet_3="subnet_3_goes_here"

# Security groups to associate with the ELB
# Up to five security groups can be associated
# with one ELB

security_group_1="sg_1_goes_here"
security_group_2="sg_2_goes_here"
security_group_3="sg_3_goes_here"
security_group_4="sg_4_goes_here"
security_group_5="sg_5_goes_here"

# Scheme to associate with the ELB
# Two possible scheme values are available:
# 
# internet-facing
# internal

elb_scheme="elb_scheme_here"

CreateAWSElasticLoadBalancer