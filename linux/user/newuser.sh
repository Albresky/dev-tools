#!/bin/bash

#================================================================
# 脚本名称: create_vnc_user.sh
# 脚本描述: 用于创建新用户，并为其配置家目录、数据软链接及TigerVNC端口。
# 使用方法: sudo bash create_vnc_user.sh
#================================================================

# --- 全局配置 ---
# VNC用户配置文件路径
VNC_USERS_FILE="/etc/tigervnc/vncserver.users"
LARGE_STORAGE_BASE="/media/4T/home" # 每台服务器不一样
SSH_PORT=22

# SSH key pair, generate it before run this script
# ssh-keygen -t ed25519 -f /home/$(USER)/.ssh/id_ed25519_temp -C "$(USER)@$(hostname)" -N ""
SSH_PRI_KEY="/home/$(USER)/.ssh/id_ed25519_temp"
SSH_PUB_KEY="/home/$(USER)/.ssh/id_ed25519_temp.pub"

# --- Helper 函数定义 ---
print_info() {
    echo -e "\033[32m[INFO] $1\033[0m"
}

print_error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
}

print_warning() {
    echo -e "\033[33m[WARNING] $1\033[0m"
}

# --- 脚本主逻辑 ---

# 1. 检查是否为root用户
if [[ $(id -u) -ne 0 ]]; then
   print_error "此脚本需要以root权限运行，请使用 'sudo bash $0'" 
   exit 1
fi

# 2. 从命令行读取输入
read -p "请输入新用户名 (e.g., zhangsan): " username
read -s -p "请输入新用户的密码: " password
echo # 换行
read -p "请输入VNC端口号 (e.g., 10): " vnc_port

# 3. 检查输入是否为空
if [ -z "$username" ] || [ -z "$password" ] || [ -z "$vnc_port" ]; then
    print_error "用户名、密码和VNC端口号均不能为空。"
    exit 1
fi

# 4. 检查用户名是否存在
if id "$username" &>/dev/null; then
    print_error "用户 '$username' 已存在。"
    exit 1
fi

# 5. 循环检测VNC端口号是否已被占用
while grep -q "^:${vnc_port}=" "$VNC_USERS_FILE"; do
    print_warning "端口号 ${vnc_port} 已被占用，请重新输入一个新的端口号。"
    read -p "请输入新的VNC端口号: " vnc_port
    if [ -z "$vnc_port" ]; then
        print_error "VNC端口号不能为空。"
        exit 1
    fi
done

print_info "端口号 ${vnc_port} 可用。"

# --- 开始执行创建流程 ---

# 6. 创建用户并设置家目录
print_info "正在创建用户 '$username'..."
useradd -m "$username"
if [ $? -ne 0 ]; then
    print_error "创建用户 '$username' 失败。"
    exit 1
fi

# 7. 为用户设置密码
print_info "正在为用户 '$username' 设置密码..."
echo "${username}:${password}" | chpasswd
if [ $? -ne 0 ]; then
    print_error "设置密码失败。"
    userdel -r "$username"
    exit 1
fi

# 8. 创建大型存储目录
TARGET_DIR="${LARGE_STORAGE_BASE}/${username}"
print_info "正在创建大型存储目录: ${TARGET_DIR}"
mkdir -p "$TARGET_DIR"

# 9. 修改大型存储目录的所有者
print_info "正在修改目录 ${TARGET_DIR} 的所有者为 ${username}:${username}"
chown -R "${username}:${username}" "$TARGET_DIR"

# 10. 在用户家目录下创建软链接
LINK_PATH="/home/${username}/large"
print_info "正在创建软链接: ${LINK_PATH} -> ${TARGET_DIR}"
ln -s "$TARGET_DIR" "$LINK_PATH"

# 11. 修改软链接本身的所有者（可选但推荐）
# 使用 -h 选项来修改软链接本身，而不是它指向的目标
chown -h "${username}:${username}" "$LINK_PATH"

# 12. 将VNC配置写入文件
print_info "正在将VNC配置写入到 ${VNC_USERS_FILE}"
echo ":${vnc_port}=${username}" >> "$VNC_USERS_FILE"

# 13. Add temp ssh-key
print_info "Adding SSH key to home/.ssh"
mkdir -p /home/$username/.ssh
cat $SSH_PUB_KEY > /home/$usrname/.ssh/authorized_key
sudo chmod 600 /home/$usrname/.ssh/authorized_key
sudo chown -R $username:$username /home/$usrname/.ssh

# 14. 打印最终信息
echo "----------------------------------------"
print_info "用户创建成功！"
echo "----------------------------------------"
echo "请记录以下信息："
echo "----------------------------------------"
echo "服务器地址  : $(hostname -I | awk '{print $1}')"
echo "SSH端口号  : $SSH_PORT"
echo "用户名        : $username"
echo "密码          : $password"
echo "VNC端口号     : $vnc_port"
echo "VNC 初始化  : python /usr/tools/vnc/vnc_init.py"
echo "VNC 启动    : /usr/tools/vnc/vnc_ctl start && /usr/tools/vnc/vnc_ctl enable"
echo "家目录      : /home/$username"
echo "数据目录链接 : /home/$username/large"
echo "实际数据目录 : $TARGET_DIR"
echo "SSH-Private-Key:  \n\n $SSH_PRI_KEY"
echo "----------------------------------------"

exit 0
