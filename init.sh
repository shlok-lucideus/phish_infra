#!/bin/bash

phish_infra_dir=/opt/phish_infra
dockerhub_username="rteam417"
github_repo_url="https://github.com/shlok-lucideus/phish_infra"
packages="openssl unzip tmux git docker docker.io docker-compose net-tools iputils-ping iproute2 curl wget nano"
DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get -y dist-upgrade && apt-get install -y $packages && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
for image in evilginx gophish nginx-proxy
do
    docker pull $dockerhub_username/$image
    docker tag $dockerhub_username/$image $image
    docker rmi $dockerhub_username/$image
done
mkdir -p $phish_infra_dir
git clone $github_repo_url $phish_infra_dir
mkdir -p $phish_infra_dir/certs
