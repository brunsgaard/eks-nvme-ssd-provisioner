#!/bin/bash

docker build -t docker.cloud.reveliolabs.com:5000/eks-nvme-ssd-provisioner-fork:latest .
docker push docker.cloud.reveliolabs.com:5000/eks-nvme-ssd-provisioner-fork:latest
