# mha_auto
mha自动化安装脚本

使用说明：
(1) 创建节点信任关系
在集群所有机器节点上执行：
sh manage_mha.sh --create_mha_ssh --host_list=192.168.1.20,192.168.1.22,192.168.1.23
    
(2) 创建mha账号
在集群主库节点上执行：
sh manage_mha.sh --create_mha_user --mysql_port=3312 --host_list=192.168.1.20,192.168.1.22,192.168.1.23
     
(3) 创建集群配置文件
在mha manager节点上执行：
sh manage_mha.sh --create_mha_conf --cluster_name=ycsb_3312 --mysql_port=3312 --mysql_master=192.168.1.20 --mysql_backup_master=192.168.1.22 --mysql_slave=192.168.1.23
    
(4) 启动mha
在mha manager节点上执行：
su - mysql
/usr/bin/start_mha_manager.sh ycsb_3312