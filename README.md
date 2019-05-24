## hassbian系统备份

- 安装homeassistant 配置系统 打包成镜像

## Usage

### Installation
```bash
git clone https://github.com/Ali-IoT-Lab/hassbackup.git
cd hassbackup

#修改权限
 sudo chmod +x backup_system.sh
#执行脚本
 sudo sh ./backup_system.sh
#备份保存
 sudo xz -zkv backup.img
#还原
 sudo dd if=backup.img of=/dev/sda
```
