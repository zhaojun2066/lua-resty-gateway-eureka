
##install openresty
    sudo yum install yum-utils 
    sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo 
    sudo yum install openresty 
    
### luarocks install
    yum install cmake
    $ wget https://luarocks.org/releases/luarocks-2.4.1.tar.gz
    $ tar zxpf luarocks-2.4.1.tar.gz
    $ cd luarocks-2.4.1
    ./configure --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit/ \
        --lua-suffix=jit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1   
    make build
    make install     
    

##dep
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-http 0.15-0
    /usr/local/openresty/luajit/bin/luarocks install lua-typeof 0.1-0
    /usr/local/openresty/luajit/bin/luarocks install rapidjson 0.6.1-1
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher 0.4-0
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-radixtree 2.2-0
    /usr/local/openresty/luajit/bin/luarocks install lua-tinyyaml 1.0-0
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-balancer 0.02rc5-0
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-cookie 0.1.0-1
    
    
## config
    eureka 地址
    eureka:
      address: [""]
      port: 8001
      apps_uri: /eureka/apps
    
    
    插件配置，这里是跨域配置，可以扩展放到plugins 文件夹下 
    plugins:
      - name: cors
        enable: true
        scope: global     
  
## spring-boot 服务启动 的配置文件        
    eureka:
      client:
        service-url:
          defaultZone: http://localhost:8001/eureka/
      instance:
        metadata-map:
          routerpaths: '["/api-repository/*","/api-runtime/*","/api-history/*"]'  这里是配置的路由
          
## 启动和停止网关
    sh bin/start.sh  test  这个参数是环境参数[test , pre, prod]
    sh bin/stop.sh          