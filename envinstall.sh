#!/bin/bash

set -xv
exec > deploy.log 2>&1
############################################################
#    @file  envinstall.sh
#    @brief 安装环境
#    @author xiaojin 2018/8/21
############################################################
BUILD_PATH=`pwd`
CONFIG_PATH=${BUILD_PATH}/"config"
PHP_VERSION='7.2.9'
PHP_CONFIG_PATH=${CONFIG_PATH}/"php.configure"
NGINX_VERSION='1.14.0'
NGINX_CONFIG_PATH=${CONFIG_PATH}/"nginx.configure"
REDIS_VERSION='4.0.11'
# Redis 密码 这里修改了 config/redis 也要修改
REDIS_PASS='123456'
MYSQL_VERSION=''
MARIADB_VERSION='10.2.17'
MYSQL_SCRIPT=${BUILD_PATH}/"configmysql.sql"
NODE_VERSION='8.11.4'
DOWNLOAD_PATH="/usr/local/src"
MYSQL_PASSWD='123456'
PACKETS=${BUILD_PATH}/"packets"
START_SERVICE=${BUILD_PATH}/"script/start_service.sh"
JOBS=2 # cpu的核数 


function Install_Apm()
{
	echo "start yum install"
	yum -y update
	yum -y groupinstall "Development tools"
	yum -y install gcc gcc-c++ autoconf libtool automake make tcl
	yum -y install gdb gmp-devel libmcrypt libmcrypt-devel libxslt libxslt-devel libxml2 libxml2-devel openssl \
                   openssl-devel libcurl libcurl-devel libpng libpng-devel freetype.x86_64 freetype-devel.x86_64 \
				   libjpeg-turbo libjpeg-turbo-devel openldap openldap-devel bzip2 bzip2-devel perl perl-devel pcre pcre-devel
	yum -y install nodejs
}

function Download_Lnmp()
{
	cd ${DOWNLOAD_PATH}
	
	echo "Download Nginx"
	wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
	echo "Download Mariadb"
	wget https://mirrors.shu.edu.cn/mariadb//mariadb-${MARIADB_VERSION}/bintar-linux-x86_64/mariadb-${MARIADB_VERSION}-linux-x86_64.tar.gz
	echo "Download PHP"
	wget http://cn2.php.net/distributions/php-${PHP_VERSION}.tar.gz
	echo "Download Redis"
	wget http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
	echo "Download pcre"
	wget http://zy-res.oss-cn-hangzhou.aliyuncs.com/pcre/pcre-8.38.tar.gz
	echo "Download Openssl1.0.2"
	wget https://www.openssl.org/source/openssl-1.0.2p.tar.gz
}

function Install_Pcre()
{
	echo "install Pcre"
	cd ${DOWNLOAD_PATH}
	tar -zxf pcre-8.38.tar.gz
	cd pcre-8.38
	./configure --prefix=/usr/local/pcre
	make -j ${JOBS} && make install
}

function Install_Zlib()
{
	cd ${PACKETS}
	# 这里的版本如果修改了，config/nginx.configure 里面也要修改
	tar -zxf zlib-1.2.11.tar.gz
	mv -f zlib-1.2.11 ${DOWNLOAD_PATH}
	cd ${DOWNLOAD_PATH}/"zlib-1.2.11"
	./configure --prefix=/usr/local/zlib
	echo "make zlib install"
	make -j ${JOBS} && make install
}
#  openssl版本必须大于1.0.2e才能支持nginx http2
function Install_Openssl()
{
	cd ${DOWNLOAD_PATH}
	tar -zxf openssl-1.0.2p.tar.gz
	cd openssl-1.0.2p
	./config --prefix=/usr/local/openssl shared zlib
	echo "make openssl install"
	make -j ${JOBS} && make install
	mv /usr/bin/openssl /usr/bin/openssl.old
	mv /usr/include/openssl /usr/include/openssl.old
	ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
	ln -s /usr/local/openssl/include/openssl /usr/include/openssl
	echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
	ldconfig -v
	sleep 15
	openssl version	
	echo "end install openssl"
}

function Install_Nginx()
{
	set -e
	Install_Pcre
	sudo groupadd -r nginx
	sudo useradd -r -g nginx nginx
	cd ${DOWNLOAD_PATH}
	tar -zxf nginx-${NGINX_VERSION}.tar.gz
	cd nginx-${NGINX_VERSION}
	echo "check nginx configure"
	. ${NGINX_CONFIG_PATH}
	echo "make nginx install"
	make -j ${JOBS} && make install
	#mkdir -pv /var/tmp/nginx/{client,proxy,fastcgi,uwsgi,scgi}
	cp ${CONFIG_PATH}/"nginx.service" /lib/systemd/system
	chmod 754 /lib/systemd/system/nginx.service
	systemctl enable nginx.service
	# 这里应该还要重命名配置文件 安装后验证
	echo "end install nginx"
	set +e
	
}

function Install_Mariadb()
{
	yum install -y libaio-*
	rpm -e --nodeps mariadb-libs-5.5.56-2.el7.x86_64
	cd ${DOWNLOAD_PATH}
	tar -zxf mariadb-${MARIADB_VERSION}-linux-x86_64.tar.gz
	mv mariadb-${MARIADB_VERSION}-linux-x86_64 /usr/local/mysql
	cd /usr/local/mysql
	echo "add user mysql"
	sudo groupadd mysql
	sudo useradd -g mysql -s /sbin/nologin mysql
	cp -f ${CONFIG_PATH}/"my.cnf" /etc/my.cnf
	echo "init mysql"
	./scripts/mysql_install_db --user=mysql --defaults-file=/etc/my.cnf
	# /usr/local/mysql/bin/mysqladmin -u root password ${MYSQL_PASSWD}  #此处服务还没起来
	chown -R mysql:mysql .
	cp support-files/mysql.server /etc/init.d/mysqld
	chmod +x /etc/init.d/mysqld
	chkconfig --add mysqld
	chkconfig  mysqld on
	ln -sf /usr/local/mysql/bin/mysql /usr/bin/mysql
    ln -sf /usr/local/mysql/bin/mysqldump /usr/bin/mysqldump
    ln -sf /usr/local/mysql/bin/myisamchk /usr/bin/myisamchk
    ln -sf /usr/local/mysql/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -sf /usr/local/mysql/bin/mysqlcheck /usr/bin/mysqlcheck
	echo "end install mysql"
}

function Install_Jpeg()
{
	wget http://www.ijg.org/files/jpegsrc.v9c.tar.gz ${DOWNLOAD_PATH}
	cd ${DOWNLOAD_PATH}
	tar -zxvf jpegsr9c.zip
	mkdir /usr/local/libjpeg
	cd jpeg-9c/
	./configure --prefix=/usr/local/libjpeg --enable-shared --enable-static
	echo "make install JPEG"
	make -j ${JOBS} && make install
}

function Install_Php()
{
    set -e
	groupadd www
	useradd -g www -s /sbin/nologin www
	
	cd ${DOWNLOAD_PATH}
	tar -zxf php-${PHP_VERSION}.tar.gz
	cd php-${PHP_VERSION}
	. ${PHP_CONFIG_PATH}
	echo "make php install"
	make -j ${JOBS} && make install
	cp php.ini-production /usr/local/php/etc/php-cli.ini
	cp php.ini-production /usr/local/php/etc/php-fpm-fcgi.ini
	cp php.ini-production /usr/local/php/etc/php-cgi-fcgi.ini
	cp php.ini-production /usr/local/php/etc/php.ini
	echo "setting php config"
	cp -f sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
	chmod +x /etc/init.d/php-fpm
	chkconfig --add php-fpm    
	chkconfig --list php-fpm
	chkconfig php-fpm on
	
	ln -sf /usr/local/php/bin/php /usr/bin/php
	ln -sf /usr/local/php/bin/pear /usr/bin/pear
	ln -sf /usr/local/php/bin/php-config /usr/bin/php-config
	ln -sf /usr/local/php/bin/phpize /usr/bin/phpize
	ln -sf /usr/local/php/bin/php-cgi /usr/bin/php-cgi
	ln -sf /usr/local/php/bin/phpdbg /usr/bin/phpdbg
	
	cd /usr/local/php/etc/
	cp php-fpm.conf.default php-fpm.conf
	sed -i 's@;pid = run/php-fpm.pid@pid = /usr/local/php/var/run/php-fpm.pid@' php-fpm.conf
	cd /usr/local/php/etc/php-fpm.d
	cp -f www.conf.default www.conf
	
	##########################
	#   更改运行PHP的用户  www.conf
    #
	#user = www
	#group = www
	#listen.user = www
	#listen.group = www
	#listen.mode = 0666
	#listen.backlog = 1024
	#pm = static
	#pm.max_children = 256
	#pm.start_servers = 4
	#pm.min_spare_servers = 8
	#pm.max_spare_servers = 32
	#pm.max_requests = 1000
	#request_terminate_timeout = 30
    
	#  php.ini
	#register_globals = Off //禁止将$GET,$POST等数组变量里的内容自动注册为全局变量
	#allow_url_include = Off //禁止通过include/require来执行一个远程文件
	#expose_php = Off //禁止显示PHP的版本号
	#display_errors = Off //禁止将error、notice、warning日志打印出来，以及打印的位置
	#display_startup_errors = Off //避免PHP启动时产生的错误被打印到页面上而造成信息泄漏
	cp ${CONFIG_PATH}/"php-fpm.service" /lib/systemd/system
	chmod 754 /lib/systemd/system/php-fpm.service
	systemctl enable php-fpm.service
	set +e
}

function Install_Phplib()
{
	# phpredis  github:  https://github.com/phpredis/phpredis
	# extensions=redis.so
	echo "install phpredis"
	cp ${PACKETS}/"phpredis-4.1.1.tar.gz" ${DOWNLOAD_PATH}
	cd ${DOWNLOAD_PATH}
	tar -zxf phpredis-4.1.1.tar.gz
	mkdir /usr/local/phpredis
	cd phpredis-4.1.1
	/usr/local/php/bin/phpize
	./configure --prefix=/usr/local/phpredis --with-php-config=/usr/local/php/bin/php-config
	make -j ${JOBS} && make install
}

function Install_Swoolelib()
{
	echo "install swoole lib --- nghttp2"
	# nghttp2  github: https://github.com/nghttp2/nghttp2
	cd ${PACKETS}
	tar -xf nghttp2-1.32.1.tar.bz2
	mv nghttp2-1.32.1/ /usr/local/nghttp2
	cd /usr/local/nghttp2
	./configure
	make libdir=/usr/lib64
	make libdir=/usr/lib64 install
	
	echo "install hredis"
	cp ${PACKETS}/"hiredis-0.13.3.tar.gz" ${DOWNLOAD_PATH}
	cd ${DOWNLOAD_PATH}
	tar -zxf hiredis-0.13.3.tar.gz
	cd hiredis-0.13.3
	make -j ${JOBS}
	make install
	ldconfig
}

function Install_Swoole()
{
	echo "install swoole"
	cp ${PACKETS}/"swoole-src-4.0.4.tar.gz" ${DOWNLOAD_PATH}
	cd ${DOWNLOAD_PATH}
	tar -zxf swoole-src-4.0.4.tar.gz
	cd swoole-src-4.0.4
	/usr/local/php/bin/phpize
	./configure	--enable-openssl --enable-http2 --enable-async-redis --enable-sockets
	make clean && make -j ${JOBS} && sudo make install
}

function Install_Composer()
{
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
}

function Start_Service()
{
	echo "Start service"
	bash ${START_SERVICE}
}

function Configure_Mysql()
{
	echo "edit mysql"
	mysql < ${MYSQL_SCRIPT}
}

function Redis_server()
{
	echo "install Redis server"
	cd ${DOWNLOAD_PATH}
	tar -zxf redis-${REDIS_VERSION}.tar.gz
	mkdir /etc/redis
	mv redis-${REDIS_VERSION} /usr/local/redis
	cd /usr/local/redis
	cp ./redis.conf /etc/redis/
	make -j ${JOBS} && cd ./src && make install
	sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
	sed -i 's/daemonize no/daemonize yes/' /etc/redis/redis.conf
	sed -i "s/# requirepass foobared/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
	cp -f ${CONFIG_PATH}/"redis" /etc/init.d/ && chmod +x /etc/init.d/redis
}

Install_Apm

Download_Lnmp

Install_Pcre

Install_Zlib

Install_Openssl

Install_Nginx

Install_Mariadb

Install_Php

Install_Swoolelib

Install_Swoole

Install_Composer

Redis_server