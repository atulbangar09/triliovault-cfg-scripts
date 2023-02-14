#!/bin/bash -x

set -e

if [ $# -ne 2 ];then
   echo -e "Script takes exactly 2 arguments\n"
   echo -e "./build_container.sh <container_name> <container_tag>"
   echo -e "./build_container.sh trilio/openstack-horizon-with-trilio-plugin queens"
   exit 1
fi

name=$1
tag=$2

docker build --no-cache -t $name:$tag .
docker push $name:$tag
