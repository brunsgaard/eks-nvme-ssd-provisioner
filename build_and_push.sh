#!/bin/bash

version=0.0.5

docker build -t docker.cloud.reveliolabs.com:5000/nvme-ssd-provisioner-fork:v${version} .
docker push docker.cloud.reveliolabs.com:5000/nvme-ssd-provisioner-fork:v${version}
