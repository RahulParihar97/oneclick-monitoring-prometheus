#!/bin/bash

echo "Deleting NAT Gateways..."
for nat in $(aws ec2 describe-nat-gateways \
  --query "NatGateways[?State!='deleted'].NatGatewayId" \
  --output text)
do
    aws ec2 delete-nat-gateway --nat-gateway-id $nat
done

echo "Deleting Internet Gateways..."
for igw in $(aws ec2 describe-internet-gateways \
  --query "InternetGateways[?Attachments[0].VpcId!=null].InternetGatewayId" \
  --output text)
do
    vpc=$(aws ec2 describe-internet-gateways \
      --internet-gateway-ids $igw \
      --query "InternetGateways[0].Attachments[0].VpcId" \
      --output text)

    aws ec2 detach-internet-gateway \
      --internet-gateway-id $igw \
      --vpc-id $vpc

    aws ec2 delete-internet-gateway \
      --internet-gateway-id $igw
done
