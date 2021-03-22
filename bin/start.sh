#!/bin/bash
cd `dirname $0`
BIN_DIR=`pwd`
cd ..
DEPLOY_DIR=`pwd`


case "$1" in
   'prod')
      export gateway_env="prod"
      ;;
   'test')
      export gateway_env="test"
     ;;
  *)
esac

echo "nginx is start?"
nginx_progress=`ps -ef|grep "nginx" |wc -l`

if [ $nginx_progress -gt 1 ]
then
    echo "nginx started ,restart nginx"
    openresty -p $DEPLOY_DIR -c  conf/nginx-"$1".conf -s reload
else
    echo "nginx not started,stating nginx"
    openresty -p $DEPLOY_DIR  -c  conf/nginx-"$1".conf
fi

nginx_progress=`ps -ef|grep "nginx" |wc -l`

if [ $nginx_progress -gt 2 ]
then
    echo "nginx start sucess"
else
    echo "nginx start failed"
fi
