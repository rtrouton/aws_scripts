#!/bin/bash

# Adding all specified IPs to an AWS security group.
# IP addresses are supplied from text files with up 
# to 50 IP addresses listed.

AddSpecifiedRulesToSecurityGroup(){

 # This function will update Amazon Web Services security groups with specified IP rules using the AWS CLI tool

for ip in $(cat "$ip_list")
do

   # Check to see if the input IP in question includes a forward
   # slash, which would indicate CIDR notation for an IP range.
   # If no slash is present, add "/32" to the end to add the 
   # correct CIDR notation for a single IP address. 
  
  if [[ "$ip" == *\/* ]]; then
      cidr_ip="$ip"
  else
      cidr_ip="$ip/32"
  fi
  echo "Adding $cidr_ip for $protocol port $tcp_port to security group $security_group_id"
  aws ec2 authorize-security-group-ingress --protocol "$protocol" --port "$tcp_port" --cidr "cidr_ip" --group-id "$security_group_id"
done

}

# Example use to update five existing security groups
# with list of IPs from five separate text files, where all IPs
# are being enabled to use TCP port 443

# First group

security_group_id=sg-security_group_id_here
ip_list="/path/to/ip_list_here1.txt"
protocol=tcp
tcp_port=443

AddSpecifiedRulesToSecurityGroup

# Second group

security_group_id=sg-security_group_id_here
ip_list="/path/to/ip_list_here2.txt"

AddSpecifiedRulesToSecurityGroup

# Third group

security_group_id=sg-security_group_id_here
ip_list="/path/to/ip_list_here3.txt"

AddSpecifiedRulesToSecurityGroup

# Fourth group

security_group_id=sg-security_group_id_here
ip_list="/path/to/ip_list_here4.txt"

AddSpecifiedRulesToSecurityGroup

# Fifth group

security_group_id=sg-security_group_id_here
ip_list="/path/to/ip_list_here5.txt"

AddSpecifiedRulesToSecurityGroup