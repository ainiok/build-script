## 说明


**shell 自动安装**

相关配置：

```
PHP_VERSION='7.2.9'   // PHP版本
NGINX_VERSION='1.14.0'   // NGINX 版本
REDIS_VERSION='4.0.11'   // redis版本
# Redis 密码 这里修改了 config/redis 也要修改
REDIS_PASS='123456'
MYSQL_VERSION=''
MARIADB_VERSION='10.2.17'
NODE_VERSION='8.11.4'
DOWNLOAD_PATH="/usr/local/src"
MYSQL_PASSWD='123456'  // mysql密码
JOBS=6 # cpu的核数 没啥卵用，加快了一丢丢编译时间
```

安装

后台运行

```
nohu bash -x envinstall.sh &
```

出现以下内容说明成功，按回车退出 nohup界面

```
nohup: ignoring input and appending output to ‘nohup.out’
```

查看任务有没有在进行

```
jobs -l

或者

tailf deploy.log
```