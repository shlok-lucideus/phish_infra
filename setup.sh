#!/bin/bash

phish_infra_dir=/opt/phish_infra

packages="openssl python3-certbot-nginx python3-pip unzip tmux git docker docker.io docker-compose certbot net-tools iputils-ping iproute2 curl wget nano"

function usage {
    echo "Usage: $0 -m gophish -h example.org -s login admin blog" >&2
    echo "       $0 -m evilginx -h example.org -t info -s login admin blog" >&2
    echo "" >&2
    echo "    -m : mode" >&2
    echo "    -h : hostname" >&2
    echo "    -s : subdomains" >&2
    echo "    -t : tracking domain" >&2
    exit 1    
}

function calc_hosts {
    for i in ${!subdomains[@]}
    do
        hosts_here[i+1]=${subdomains[i]}.$hostname
    done
    hosts_here[0]=$hostname
    printf -v joined '%s,' "${hosts_here[@]}"
    hosts_here=`echo "${joined%,}"`
}

function gen_certs {
    mkdir -p $phish_infra_dir/certs
    cd $phish_infra_dir/certs
    openssl genrsa 2048 > $hostname.key
    openssl req -new -x509 -nodes -sha256 -days 365 -key $hostname.key -out $hostname.crt -subj "/C=US/ST=Oregon/L=Portland/CN=*.$hostname"
}

function compose_init {
    cp $phish_infra_dir/docker-compose.template $phish_infra_dir/docker-compose.yml
}

function compose_up {
    cd $phish_infra_dir
    docker-compose up -d    
}

gophish() { 
    hostname=$1
    subdomains=$2
    gen_certs
    calc_hosts
    compose_init
    sed -i "s/hosts_here/$hosts_here/g" $phish_infra_dir/docker-compose.yml
    compose_up
}

evilginx() {   
    hostname=$1
    subdomains=$2
    tracker=$3.$1
    gen_certs
    calc_hosts
    compose_init
    sed -i "s/hosts_here/$tracker/g" $phish_infra_dir/docker-compose.yml
    sed -i "s/hosts_here/$hosts_here/g" $phish_infra_dir/evilginx/evilginx
    compose_up
    tmux new-session -d -s evilginx && tmux send-keys -t evilginx "cd $phish_infra_dir/evilginx ./evilginx" Enter
}

while getopts 'm:h:s:t:' flag; do
    case "$flag" in
      m)
        mode=${OPTARG}
        ;;
      h)
        hostname=${OPTARG}
        ;;

      s)
        subdomains=("$OPTARG")
        until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
                subdomains+=($(eval "echo \${$OPTIND}"))
                OPTIND=$((OPTIND + 1))
        done
        ;;

      t)
        tracker=${OPTARG}
        ;;
      *)
        usage
        ;;
    esac
done

case $mode in
      gophish)
        gophish $hostname ${subdomains[@]}
        ;;
      evilginx)
        evilginx $hostname $subdomains $tracker
        ;;
      *)
        usage
        ;;
esac

echo "Done!"
