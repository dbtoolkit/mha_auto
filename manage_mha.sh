#!/bin/bash
# 
# 功能描述: 部署mha工具
# Authors: 
#   zhaoyunbo@vip.qq.com

# mha软件源
mha_source="http://192.168.1.1"

# mha软件源
if [ "$env" = "lan" ];then
  mha_source="http://192.168.1.1"
elif [ "$env" = "wan" ];then
  mha_source="http://192.168.10.1"
fi

# mha软件包
mha_manager_rpm="mha4mysql-manager-0.57-0.el6.noarch.rpm"
mha_node_rpm="mha4mysql-node-0.57-0.el6.noarch.rpm"

# mha安装目录
installdir=/data/install/mysql_mha

# 创建mha安装目录
if [ ! -d $installdir ];then
  mkdir -p $installdir
fi

# 环境
get_dir_name(){ 
  declare -r n=${1:-$0}; 
  dirname $n;
}

get_base_name(){
  declare -r n=${1:-$0};
  echo ${n##*/};
}

get_app_name(){
  declare -r n=${1:-$0};
  declare -r p=$(get_base_name "$n");
  echo ${p%.*};
}

# 检查并安装依赖包
check_mha_env(){
  echo "start check and install perl package..."

  rpm -qa |egrep -i perl-Config-Tiny
  if [[ $? -ne 0 ]]; then
    yum -y install perl-Config-Tiny.noarch
  fi

  rpm -qa |egrep -i perl-Parallel-ForkManager
  if [[ $? -ne 0 ]]; then
    yum -y install perl-Parallel-ForkManager.noarch
  fi

  rpm -qa |egrep -i perl-Log-Log4perl
  if [[ $? -ne 0 ]]; then
    yum -y install perl-Log-Log4perl.noarch
  fi

  rpm -qa |egrep -i perl-DBI
  if [[ $? -ne 0 ]]; then
    yum -y install perl-DBI.x86_64
  fi

  rpm -qa |egrep -i perl-DBD-MySQL
  if [[ $? -ne 0 ]]; then
    yum -y install perl-DBD-MySQL.x86_64
  fi

  echo "finish check and install perl package"
}

# 安装mha manager
install_manager(){
  # 检查依赖包
  check_mha_env
  
  cd $installdir && wget ${mha_source}/mha/${mha_manager_rpm}
  rpm -qa |egrep -i mha4mysql-manager
  if [ $? -ne 0 ];then
    rpm -ivh ${mha_manager_rpm}
  else
    echo "mha manager rpm is already installed"
  fi
}

# 安装mha node
install_node(){
  # 检查依赖包
  check_mha_env

  cd $installdir && wget ${mha_source}/mha/${mha_node_rpm}
  rpm -qa |egrep -i mha4mysql-node
  if [ $? -ne 0 ];then
    rpm -ivh ${mha_node_rpm}
  else
    echo "mha node rpm is already installed"
  fi
}

# 升级mha manager
upgrade_manager(){
  # 检查依赖包
  check_mha_env
  
  # 备份二进制程序
  [ -f ${installdir}/${mha_manager_rpm} ] && mv ${installdir}/${mha_manager_rpm} ${installdir}/${mha_manager_rpm}_bak_$(date +'%Y%m%d%H%M%S')

  # 升级安装
  cd $installdir && wget ${mha_source}/mha/${mha_manager_rpm}
  rpm -qa |egrep -i mha4mysql-manager
  if [ $? -ne 0 ];then
    echo "mha4mysql-manager is not installed, just install it"
    rpm -ivh ${mha_manager_rpm}
  else
    echo "mha4mysql-manager rpm is already installed, force upgrade it"
    rpm -Uvh --force ${mha_manager_rpm}
  fi
  
  echo "upgrade mha4mysql-manager rpm success"
}

# 升级mha node
upgrade_node(){
  # 检查依赖包
  check_mha_env

  # 备份二进制程序
  [ -f ${installdir}/${mha_node_rpm} ] && mv ${installdir}/${mha_node_rpm} ${installdir}/${mha_node_rpm}_bak_$(date +'%Y%m%d%H%M%S')

  # 升级安装
  cd $installdir && wget ${mha_source}/mha/${mha_node_rpm}
  rpm -qa |egrep -i mha4mysql-node
  if [ $? -ne 0 ];then
    echo "mha4mysql-node is not installed, just install it"
    rpm -ivh ${mha_node_rpm}
  else
    echo "mha4mysql-node rpm is already installed"
    rpm -Uvh --force ${mha_node_rpm}
  fi
  
  echo "upgrade mha4mysql-node rpm success"  
}

# 创建mydrc场景mha.conf配置文件
create_mha_conf_mydrc(){

  # 检查参数
  if [ -z $cluster_name ];then
    logger_error "option --cluster_name should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mydrc_api ];then
    logger_error "option --mydrc_api should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_master ];then
    logger_error "option --mysql_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_backup_master ];then
    logger_error "option --mysql_backup_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_slave ];then
    logger_error "option --mysql_slave should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    mysql_slave_list=($mysql_slave)
    IFS="$OLD_IFS"
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    logger_info "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    echo "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  if [ ! -f ${mha_dir}/mha.conf ];then
    echo "mha.conf is not exist"
    echo "create mha.conf now..."
    
    cat >> ${mha_dir}/mha.conf <<EOF
[server default]
manager_log=${mha_dir}/manager.log
manager_workdir=$mha_dir
ping_interval=10
ping_type=SELECT
log_level=info

user=mha
password=mha_test
port=${mysql_port}

repl_user=slave
repl_password=slave_test

ssh_user=mysql
ssh_port=22
ssh_connection_timeout=20

master_ip_failover_script=/usr/bin/master_ip_failover_mydrc --mydrc_api=${mydrc_api} --manager_workdir=${mha_dir}
master_ip_online_change_script=/usr/bin/master_ip_online_change_mydrc --mydrc_api=${mydrc_api} --manager_workdir=${mha_dir}

[server_${mysql_master}]
hostname=${mysql_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

[server_${mysql_backup_master}]
hostname=${mysql_backup_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

EOF

if [ ! -z $mysql_slave_list ];then
  for i in ${mysql_slave_list[@]};do
    cat >> ${mha_dir}/mha.conf <<EOF
[server_${i}]
hostname=${i}
master_binlog_dir=/data/mysql/my${mysql_port}
ignore_fail=1
no_master=1

EOF
  done
fi
    chown -R mysql.mysql ${mha_dir}
    echo "finish create mha.conf"
  fi
}

# 创建zkapi场景mha.conf配置文件
create_mha_conf_zkapi(){

  # 检查参数
  if [ -z $cluster_name ];then
    logger_error "option --cluster_name should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $zkapi ];then
    logger_error "option --zkapi should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $rvip ];then
    logger_error "option --rvip should not be null"
    exit $MISSING_OPTION
  fi
 
  if [ -z $mysql_master ];then
    logger_error "option --mysql_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_backup_master ];then
    logger_error "option --mysql_backup_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_slave ];then
    logger_error "option --mysql_slave should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    mysql_slave_list=($mysql_slave)
    IFS="$OLD_IFS"
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    logger_info "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    echo "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  if [ ! -f ${mha_dir}/mha.conf ];then
    echo "mha.conf is not exist"
    echo "create mha.conf now..."
    
    cat >> ${mha_dir}/mha.conf <<EOF
[server default]
manager_log=${mha_dir}/manager.log
manager_workdir=$mha_dir
ping_interval=10
ping_type=SELECT
log_level=info

user=mha
password=mha_test
port=${mysql_port}

repl_user=slave
repl_password=slave_test

ssh_user=mysql
ssh_port=22
ssh_connection_timeout=20

master_ip_failover_script=/usr/bin/master_ip_failover_zkapi --zkapi=$zkapi --rvip=$rvip --manager_workdir=${mha_dir}
master_ip_online_change_script=/usr/bin/master_ip_online_change_zkapi --zkapi=$zkapi --rvip=$rvip --manager_workdir=${mha_dir}

[server_${mysql_master}]
hostname=${mysql_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

[server_${mysql_backup_master}]
hostname=${mysql_backup_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

EOF

if [ ! -z $mysql_slave_list ];then
  for i in ${mysql_slave_list[@]};do
    cat >> ${mha_dir}/mha.conf <<EOF
[server_${i}]
hostname=${i}
master_binlog_dir=/data/mysql/my${mysql_port}
ignore_fail=1
no_master=1

EOF
  done
fi

    chown -R mysql.mysql ${mha_dir}
    echo "finish create mha.conf"
  fi
}

# 创建mha.conf配置文件
create_mha_conf(){

  # 检查参数
  if [ -z $cluster_name ];then
    logger_error "option --cluster_name should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_master ];then
    logger_error "option --mysql_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_backup_master ];then
    logger_error "option --mysql_backup_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_slave ];then
    logger_error "option --mysql_slave should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    mysql_slave_list=($mysql_slave)
    IFS="$OLD_IFS"
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    logger_info "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  if [ ! -f ${mha_dir}/mha.conf ];then
    echo "mha.conf is not exist"
    echo "create mha.conf now..."

    cat >> ${mha_dir}/mha.conf <<EOF
[server default]
manager_log=${mha_dir}/manager.log
manager_workdir=$mha_dir
ping_interval=10
ping_type=SELECT
log_level=info

user=mha
password=mha_test
port=${mysql_port}

repl_user=slave
repl_password=slave_test

ssh_user=mysql
ssh_port=22
ssh_connection_timeout=20


[server_${mysql_master}]
hostname=${mysql_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

[server_${mysql_backup_master}]
hostname=${mysql_backup_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

EOF

if [ ! -z $mysql_slave_list ];then
  for i in ${mysql_slave_list[@]};do
    cat >> ${mha_dir}/mha.conf <<EOF
[server_${i}]
hostname=${i}
master_binlog_dir=/data/mysql/my${mysql_port}
ignore_fail=1
no_master=1

EOF
  done
fi

    chown -R mysql.mysql ${mha_dir}
    echo "finish create mha.conf"
  fi
}


# 创建读写vip场景mha.conf配置文件
create_mha_conf_wvip(){

  # 检查参数
  if [ -z $cluster_name ];then
    logger_error "option --cluster_name should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $vip ];then
    logger_error "option --vip should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $net_interface ];then
    logger_error "option --net_interface should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $net_mask ];then
    logger_error "option --net_mask should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $gateway ];then
    logger_error "option --gateway should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_master ];then
    logger_error "option --mysql_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_backup_master ];then
    logger_error "option --mysql_backup_master should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $mysql_slave ];then
    logger_error "option --mysql_slave should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    mysql_slave_list=($mysql_slave)
    IFS="$OLD_IFS"
  fi

  mha_dir="/data/mha/$cluster_name"
  if [ ! -f $mha_dir ];then
    logger_info "mha dir: $mha_dir is not exist, create it now"
    mkdir -p $mha_dir
  fi

  if [ ! -f ${mha_dir}/mha.conf ];then
    echo "mha.conf is not exist"
    echo "create mha.conf now..."

    cat >> ${mha_dir}/mha.conf <<EOF
[server default]
manager_log=${mha_dir}/manager.log
manager_workdir=$mha_dir
ping_interval=10
ping_type=SELECT
log_level=info

user=mha
password=mha_test
port=${mysql_port}

repl_user=slave
repl_password=slave_test

ssh_user=mysql
ssh_port=22
ssh_connection_timeout=20

master_ip_failover_script=/usr/bin/master_ip_failover --vip=$vip --net_interface=$net_interface --net_mask=$net_mask --gateway=$gateway --manager_workdir=${mha_dir}
master_ip_online_change_script=/usr/bin/master_ip_online_change --vip=$vip --net_interface=$net_interface --net_mask=$net_mask --gateway=$gateway --manager_workdir=${mha_dir}

[server_${mysql_master}]
hostname=${mysql_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

[server_${mysql_backup_master}]
hostname=${mysql_backup_master}
master_binlog_dir=/data/mysql/my${mysql_port}
candidate_master=1

EOF

if [ ! -z $mysql_slave_list ];then
  for i in ${mysql_slave_list[@]};do
    cat >> ${mha_dir}/mha.conf <<EOF
[server_${i}]
hostname=${i}
master_binlog_dir=/data/mysql/my${mysql_port}
ignore_fail=1
no_master=1

EOF
  done
fi

    chown -R mysql.mysql ${mha_dir}
    echo "finish create mha.conf"
  fi
}

# 创建读vip配置文件
create_mha_rvip_conf(){
 
  # 检查参数
  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi
  
  if [ -z $virtual_router_id ];then
    logger_error "option --virtual_router_id should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $vrrp_instance_vip ];then
    logger_error "option --vrrp_instance_vip should not be null"
    exit $MISSING_OPTION
  fi
  
  # 添加实例
  if [ ! -f /etc/mha_vip.conf ];then
    logger_warn "/etc/mha_vip.conf is not exist, create mha_vip.conf now..."

    cat >> /etc/mha_vip.conf <<EOF
#ismaintain  viptype  port        vrrp                       vip          gotofault
n    rvip    $mysql_port    vi_mysql_${virtual_router_id}    $vrrp_instance_vip    n
EOF
  
    logger_info "finish create add rvip:$vrrp_instance_vip to mha_vip.conf"
  else
    instance_num=$(less /etc/mha_vip.conf |egrep -i "vi_mysql_${virtual_router_id}" |grep -w $mysql_port |wc -l)
    if [ $instance_num -lt 1 ];then
      echo "n    rvip    $mysql_port    vi_mysql_${virtual_router_id}    $vrrp_instance_vip    n" >> /etc/mha_vip.conf
      logger_info "finish add rvip:$vrrp_instance_vip to /etc/mha_vip.conf"
    else
      logger_warn "rvip:$vrrp_instance_vip is already in /etc/mha_vip.conf"
    fi
  fi
}

# 创建keepalived.conf配置文件
create_keepalived_conf(){
 
  # 检查参数  
  if [ -z $vrrp_instance_vip ];then
    logger_error "option --vrrp_instance_vip should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $virtual_router_id ];then
    logger_error "option --virtual_router_id should not be null"
    exit $MISSING_OPTION
  fi
  
  # 添加实例
  if [ ! -f /etc/keepalived/keepalived.conf ];then
    logger_warn "/etc/keepalived/keepalived.conf is not exist, create it now..."

    cat >> /etc/keepalived/keepalived.conf <<EOF
vrrp_script vs_mysql_${virtual_router_id} {
    script "/usr/bin/check_rvip --vrrp-instance=vi_mysql_${virtual_router_id} --total-timeout-seconds=15"
    interval 15
}

vrrp_instance vi_mysql_${virtual_router_id} {
    state BACKUP
    nopreempt
    interface ${net_interface}
    virtual_router_id ${virtual_router_id}
    priority 100
    advert_int 2
    authentication {
       auth_type PASS
       auth_pass 6810${virtual_router_id}
    }
    track_script {
        vs_mysql_${virtual_router_id}
    }
    virtual_ipaddress {
        $vrrp_instance_vip
    }
}
EOF
  
    logger_info "finish create add rvip:$vrrp_instance_vip to keepalived.conf"
  else
    instance_num=$(less /etc/keepalived/keepalived.conf |egrep -i vrrp_instance |grep -w "vi_mysql_${virtual_router_id}" |wc -l)
    
    if [ $instance_num -lt 1 ];then
      cat >> /etc/keepalived/keepalived.conf <<EOF
vrrp_script vs_mysql_${virtual_router_id} {
    script "/usr/bin/check_rvip --vrrp-instance=vi_mysql_${virtual_router_id} --total-timeout-seconds=15"
    interval 15
}

vrrp_instance vi_mysql_${virtual_router_id} {
    state BACKUP
    nopreempt
    interface ${net_interface}
    virtual_router_id ${virtual_router_id}
    priority 100
    advert_int 2
    authentication {
       auth_type PASS
       auth_pass 6810${virtual_router_id}
    }
    track_script {
        vs_mysql_${virtual_router_id}
    }
    virtual_ipaddress {
        $vrrp_instance_vip
    }
}
EOF
      logger_info "finish add rvip:$vrrp_instance_vip to keepalived.conf"
    else
      logger_warn "rvip:$vrrp_instance_vip is already in /etc/keepalived/keepalived.conf"
    fi
  fi
}

# 创建mha ssh信任关系
create_mha_ssh(){
  
  # 检查参数  
  if [ -z $host_list ];then
    logger_error "option --host_list should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    db_host_list=($host_list)
    IFS="$OLD_IFS"
  fi

  # 参数
  ssh_dir="/home/mysql/.ssh"
  ssh_port=22
  ssh_user=mysql
  password="mysql_test"
  private_key_file="$ssh_dir/id_rsa"
  public_key_file="$ssh_dir/id_rsa.pub"
  authorized_key_file="$ssh_dir/authorized_keys"
  tmp_file="${public_key_file}.tmp"
  ssh_copy_id=$(which ssh-copy-id)
  ssh_keygen=$(which ssh-keygen)
  expect=$(which expect)
  
  # 检查执行用户
  echo $host
  current_user=${whoami}

  if [ "$current_user" != "mysql" ];then
    logger_info "current user is not mysql, use sudo to run cmd"
        
    # 检查创建ssh目录
    if [ ! -d $ssh_dir ];then
      sudo -u mysql mkdir -p $ssh_dir
    fi
      
    # 检查秘钥文件
    if [ ! -f $private_key_file ];then
      sudo -u mysql ${ssh_keygen} -t rsa -f $private_key_file -N ''
    fi

    # 拷贝秘钥文件到其它机器
    for db_host in ${db_host_list[@]}
    do
      $expect <<eof1
      proc do_exec_cmd {password} {
        set timeout 30
        expect {
          "(yes/no)?" {send "yes\r";expect "assword:";send "$password\r"}
          "assword:"  {send "$password\r"}
          timeout {exit 2}
        }
	expect "$"
      }
	    
      spawn sudo -u mysql ${ssh_copy_id} -i $public_key_file "-p${ssh_port} -oStrictHostKeyChecking=no -oConnectTimeout=30 mysql@${db_host}"
      do_exec_cmd $password
eof1
    done
  else
    # 检查创建ssh目录
    if [ ! -d $ssh_dir ];then
      mkdir -p $ssh_dir
    fi
      
    # 检查秘钥文件
    if [ ! -f $private_key_file ];then
      ${ssh_keygen} -t rsa -f $private_key_file -N ''
    fi

    # 拷贝秘钥文件到其它机器
    for db_host in ${db_host_list[@]}
    do
      $expect <<eof2
      proc do_exec_cmd {password} {
        set timeout 30
        expect {
          "(yes/no)?" {send "yes\r";expect "assword:";send "$password\r"}
          "assword:"  {send "$password\r"}
          timeout {exit 2}
        }
	expect "$"
      }
      spawn ${ssh_copy_id} -i $public_key_file "-p${ssh_port} -oStrictHostKeyChecking=no -oConnectTimeout=30 mysql@${db_host}"
      do_exec_cmd $password
eof2
    done        
  fi
}


# 创建mha用户账号
create_mha_user(){
  
  # 检查参数
  if [ -z $mysql_port ];then
    logger_error "option --mysql_port should not be null"
    exit $MISSING_OPTION
  fi

  if [ -z $host_list ];then
    logger_error "option --host_list should not be null"
    exit $MISSING_OPTION
  else
    OLD_IFS="$IFS"
    IFS=","
    db_host_list=($host_list)
    IFS="$OLD_IFS"
  fi

  if [ ! -z $host_list ];then

    # 检查sql文件
    if [ -f /tmp/create_mha_${mysql_port}.sql ];then
      mv /tmp/create_mha_${mysql_port}.sql /tmp/create_mha_${mysql_port}_bak.sql
    fi
    
    # 生成授权sql
    for i in ${host_list[@]};do
      cat >> /tmp/create_mha_${mysql_port}.sql <<EOF
GRANT PROCESS, SUPER, RELOAD, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'mha'@'$i' IDENTIFIED BY PASSWORD 'xxxxxxxxxxxxxxxxxxxxxxx';
GRANT SELECT ON mysql.* TO 'mha'@'$i';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON mysql_identity.* TO 'mha'@'$i';
EOF
    done
    mysql_basedir=$(less /etc/mytab |grep -v "#" | grep ${mysql_port} | awk '{print $1}' |uniq)

    read -p "Please input mysql pass: " mysql_pass

    if [ ! -z $mysql_pass ];then
      # 创建mha用户
      ${mysql_basedir}/bin/mysql --socket=/data/mysql/my3313/mysql.sock --port=${mysql_port} -uroot -p$mysql_pass < /tmp/create_mha_${mysql_port}.sql
    fi

  fi
}


#  ========================================================== 主程序 ==============================================================

# 初始化
dir_name=$(get_dir_name)
prog_name=$(get_base_name)
app_name=$(get_app_name)
app_file_name=$prog_name[$$]
curr_date=$(date '+%Y%m%d')

# 日志目录
log_dir=/var/log/mha
[ ! -d "$log_dir" ] && mkdir -p $log_dir
[ ! -x "$log_dir" -o ! -w "$log_dir" ] && { echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $app_file_name $log_dir is inaccessiable: Permission denied" >&2;}

# 日志文件名称
log_name=${log_dir}/${app_name}_${curr_date}.log

trap - EXIT INT TERM

# 检查并安装log4sh
if [ ! -f /usr/bin/log4sh ];then
  echo "start install log4sh"
  
  cd /usr/bin/ && wget ${mha_source}/mha/log4sh > /dev/null
  if [ $? -eq 0 ];then
    chmod +x /usr/bin/log4sh
    echo "install log4sh success"
  else
    echo "install log4sh failed"
  fi
fi

# 初始化log4sh
LOG4SH_SOURCE=$dir_name/log4sh
[ ! -r $LOG4SH_SOURCE ] && LOG4SH_SOURCE=/usr/local/bin/log4sh
[ ! -r $LOG4SH_SOURCE ] && LOG4SH_SOURCE=/usr/bin/log4sh
[ ! -r $LOG4SH_SOURCE ] && LOG4SH_SOURCE=/bin/log4sh

LOG4SH_PROPERTIES=${dir_name}/${app_name}.log4sh.properties
LOG4SH_DEFAULT_LAYOUT="%d [%p] %F %m%n"

LOG4SH_DEFAULT_LOGNAME="$log_dir/${app_name}_$(date '+%Y%m%d').log"
if [ ! -r $LOG4SH_SOURCE ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $app_file_name loading log4sh failed." >&2
fi

if [ -r $LOG4SH_PROPERTIES ]; then
  LOG4SH_CONFIGURATION=$LOG4SH_PROPERTIES source $LOG4SH_SOURCE
  logger_setFilename $app_file_name
  appender_file_setFile FILE "$LOG4SH_DEFAULT_LOGNAME"
  appender_activateOptions FILE
else
  LOG4SH_CONFIGURATION='none' source $LOG4SH_SOURCE
  log4sh_resetConfiguration
  logger_setLevel DEBUG
  logger_setFilename $app_name
  logger_addAppender STDOUT
  appender_setType STDOUT ConsoleAppender
  appender_setPattern STDOUT "$LOG4SH_DEFAULT_LAYOUT"
  appender_setLayout STDOUT PatternLayout
  appender_activateOptions STDOUT
  logger_addAppender FILE
  appender_setType FILE FileAppender
  appender_file_setFile FILE "$LOG4SH_DEFAULT_LOGNAME"
  appender_setPattern FILE "$LOG4SH_DEFAULT_LAYOUT"
  appender_setLayout FILE PatternLayout
  appender_activateOptions FILE
fi

LOG4SH_READY=Y

# 使用说明
usage()
{
  cat <<EOF
Usage: $0 [OPTION] ... {OPERATION} -- [PARAMETERS] ...

Basic Options:
  -h|--help
      this help.
  --log_level
      log level.
  --cluster_name
      mha manager instance name.
  --mha_manager_ip
      mha manager instance ip.
  --mysql_master
      mysql master.
  --mysql_backup_master
      mysql backup master.
  --mysql_slave
      mysql slave.
  --mysql_port
      mysql port.
  --mydrc_api
      mydrc api list, e.g.: --mydrc-api=192.168.1.2:4001,192.168.1.3:4001
  --zkapi
      zkapi list, e.g.: --zkapi=192.168.1.10:8181,192.168.1.11:8181
  --rvip
      read vip list, e.g.: --rvip=192.168.1.100,192.168.1.101
  --vip
      write vip.
  --net_interface
      net_interface.
  --net_mask
      net_mask.
  --gateway
      gateway.
  --virtual_router_id
      vrrp router id for keepalived.
  --vrrp_instance_vip
      vrrp instance vip for keepalived.
  --host_list
      host list for create mha ssh 

Other Options
  --check_mha_env
      check and install mha software.
  --install_manager
      install mha4mysql-manager rpm.
  --upgrade_manager
      upgrade mha4mysql-manager rpm.
  --install_node
      install mha4mysql-node rpm.
  --upgrade_node
      upgrade mha4mysql-node rpm.
  --create_mha_conf
      create mha.conf.
  --create_mha_conf_wvip
      create mha.conf for write vip.
  --create_mha_conf_mydrc
      create mha.conf for mydrc.
  --create_mha_conf_zkapi
      create mha.conf for zkapi.
  --create_mha_rvip_conf
      create /etc/mha_vip.conf file.
  --create_keepalived_conf
      create /etc/keepalived.conf file.
  --create_mha_ssh
      create mha ssh.
  --create_mha_user
      create mha user.
EOF
}

# 定义错误状态码
BAD_GETOPT=1
MISSING_OPTION=2
BAD_OPTIONS=3

# 初始化选项
SHORT_OPTS="hfing:vqdTDIVP"
LONG_OPTS="help version force interactive dry-run
log_level: verbose quiet debug
check_mha_env
install_manager
upgrade_manager
install_node
upgrade_node
create_mha_conf cluster_name: mysql_port: mysql_master: mysql_backup_master: mysql_slave:
create_mha_conf_wvip cluster_name: mysql_port: vip: net_interface: net_mask: gateway: mysql_master: mysql_backup_master: mysql_slave:
create_mha_conf_mydrc cluster_name: mysql_port: mydrc_api: mysql_master: mysql_backup_master: mysql_slave:
create_mha_conf_zkapi cluster_name: mysql_port: zkapi: rvip: mysql_master: mysql_backup_master: mysql_slave:
create_mha_rvip_conf virtual_router_id: vrrp_instance_vip:
create_keepalived_conf mysql_port: virtual_router_id: vrrp_instance_vip:
create_mha_ssh host_list:
create_mha_user mysql_port: host_list:
mha_manager_ip:
"

progname=$0
[ $# -gt 0 ] && ARGS=$(getopt -n$progname -o "hp:" -l "$LONG_OPTS" -- "$@") ||{ usage; exit $BAD_GETOPT; }
eval set -- "$ARGS"
while [ $# -gt 0 ]; do
  case "$1" in
    # basic options
    -h|--help) usage; exit;;
    --log_level) logger_setLevel $2; shift ;;

    --cluster_name) cluster_name=$2; shift ;;
    --mha_manager_ip) mha_manager_ip=$2; shift ;;
    --mysql_master) mysql_master=$2; shift ;;
    --mysql_backup_master) mysql_backup_master=$2; shift ;;
    --mysql_slave) mysql_slave=$2; shift ;;
    --mysql_port) mysql_port=$2; shift ;;

    # for mydrc
    --mydrc_api) mydrc_api=$2; shift ;;
    
    # for zkapi
    --zkapi) zkapi=$2; shift ;;
    --rvip) rvip=$2; shift ;;
    
    # for write vip
    --vip) vip=$2; shift ;;
    --net_interface) net_interface=$2; shift ;;
    --net_mask) net_mask=$2; shift ;;
    --gateway) gateway=$2; shift ;;
    
    # for read vip
    --virtual_router_id) virtual_router_id=$2 shift ;;
    --vrrp_instance_vip) vrrp_instance_vip=$2 shift ;;

    # for ssh key
    --host_list) host_list=$2 shift ;;

    # other options
    --check_mha_env) action=check_mha_env ;;
    --install_manager) action=install_manager ;;
    --upgrade_manager) action=upgrade_manager ;;
    --install_node) action=install_node ;;
    --upgrade_node) action=upgrade_node ;;
    --create_mha_conf) action=create_mha_conf ;;
    --create_mha_conf_wvip) action=create_mha_conf_wvip ;;
    --create_mha_conf_mydrc) action=create_mha_conf_mydrc ;;
    --create_mha_conf_zkapi) action=create_mha_conf_zkapi ;;
    --create_mha_rvip_conf) action=create_mha_rvip_conf ;;
    --create_keepalived_conf) action=create_keepalived_conf ;;
    --create_mha_ssh) action=create_mha_ssh ;;
    --create_mha_user) action=create_mha_user ;;
    --) shift
      break;;
    
    # bad options
    -*) usage ; exit $BAD_OPTIONS ;;
    *) usage ; exit $BAD_OPTIONS ;;
  esac
  shift
done

case "$action" in
   "check_mha_env") check_mha_env ;;
   "install_manager") install_manager ;;
   "upgrade_manager") upgrade_manager ;;
   "install_node") install_node ;;
   "upgrade_node") upgrade_node ;;
   "create_mha_conf") create_mha_conf ;;
   "create_mha_conf_wvip") create_mha_conf_wvip ;;
   "create_mha_conf_mydrc") create_mha_conf_mydrc ;;
   "create_mha_conf_zkapi") create_mha_conf_zkapi ;;
   "create_mha_rvip_conf") create_mha_rvip_conf ;;
   "create_keepalived_conf") create_keepalived_conf ;;
   "create_mha_ssh") create_mha_ssh ;;
   "create_mha_user") create_mha_user ;;

   *) logger_info "nothing to do."
esac