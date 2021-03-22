#!/bin/bash

cd `dirname $0`
BIN_DIR=`pwd`
cd ..
DEPLOY_DIR=`pwd`

echo "nginx is start?"
nginx_progress=`ps -ef|grep "nginx" |wc -l`

if [ $nginx_progress -gt 1 ]
then
    echo "nginx started ,stoping nginxx"
    openresty -p  $DEPLOY_DIR -c  conf/nginx.conf -s quit
    echo "nginx stoped"
else
    echo "nginx not started"
fi

