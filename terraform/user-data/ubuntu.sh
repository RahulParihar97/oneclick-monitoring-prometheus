#!/bin/bash

apt-get update -y

apt-get install -y python3

apt-get install -y python3-pip

hostnamectl set-hostname $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
