#!/bin/bash

dockerhub_username="name"
github_repo_url="repo"
phish_infra_dir=/opt/phish_infra

packages="openssl python3-certbot-nginx python3-pip unzip tmux git docker docker.io docker-compose certbot net-tools iputils-ping iproute2 curl wget nano"

function usage {

    echo "Usage: $0 -m setup" >&2
    echo "       $0 -m gophish -h example.org -s login admin blog" >&2
    echo "       $0 -m evilginx -h example.org -t info -s login admin blog" >&2
    echo "" >&2
    echo "    -m : mode" >&2
    echo "    -h : hostname" >&2
    echo "    -s : subdomains" >&2
    echo "    -t : tracking domain" >&2
    exit 1
    
}


function setup {

    DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get -y dist-upgrade && apt-get install -y $packages && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
    for image in evilginx gophish nginx
    do
	    docker pull $dockerhub_username/$image
    done
    
    git clone $github_repo_url $phish_infra_dir

}

gophish() {
    
    hostname=$1
    subdomains=$2

    for i in ${!subdomains[@]}
    do
        hosts_here[i+1]=${subdomains[i]}.$hostname
    done
    hosts_here[0]=$hostname
    printf -v joined '%s,' "${hosts_here[@]}"
    hosts_here=`echo "${joined%,}"`

    cp $phish_infra_dir/docker-compose.template $phish_infra_dir/docker-compose.yml
    sed -i "s/hosts_here/$hosts_here/g" $phish_infra_dir/docker-compose.yml

    cd $phish_infra_dir
    docker-compose up -d

}

evilginx() {
    
    hostname=$1
    subdomains=$2
    tracker=$3.$1

    for i in ${!subdomains[@]}
    do
        subdomains[i]=${subdomains[i]}.$hostname
    done

    echo "Hostname: $hostname"
    echo "Subdomains: ${subdomains[@]}"
    echo "Tracker: $tracker"
    hosts_here[0]=$hostname
    printf -v joined '%s,' "${hosts_here[@]}"
    hosts_here=`echo "${joined%,}"`

    cp $phish_infra_dir/docker-compose.template $phish_infra_dir/docker-compose.yml
    sed -i "s/hosts_here/$tracker/g" $phish_infra_dir/docker-compose.yml
    sed -i "s/hosts_here/$hosts_here/g" $phish_infra_dir/evilginx/evilginx

    cd $phish_infra_dir
    docker-compose up -d


    cat <<EOF >/usr/local/bin/evilginx
#!/bin/bash
cd /opt/phish-infra/evilginx
bash evilginx
EOF
    chmod +x /usr/local/bin/evilginx

    tmux new-session -d -s evilginx && tmux send-keys -t evilginx "evilginx" Enter

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

      setup)
        setup
        ;;

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