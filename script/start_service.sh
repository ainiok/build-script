#!/bin/bash

systemctl restart nginx
systemctl restart php-fpm
systemctl restart mysqld