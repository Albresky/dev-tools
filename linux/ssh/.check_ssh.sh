#!/bin/bash

AGENT_NAME="${USER}@$(hostname)"
SOCKET_FILE="${HOME}/.ssh/ssh-agent.sock"
ENV_FILE="${HOME}/.ssh/ssh-agent.env"
LOCK_FILE="${HOME}/.ssh/ssh-agent.lock"

KEYS_TO_ADD=(
    "${HOME}/.ssh/id_rsa_baidu"
    "${HOME}/.ssh/id_ed25519_github"
)

echo -e "\n==== 检查 ssh-agent 状态 [$AGENT_NAME] ===="

exec 200>"$LOCK_FILE"
flock -n 200 || {
    echo "==== ⏳ 等待其他进程释放 ssh-agent 锁... ===="
    flock 200
}

try_load_agent() {
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE" >/dev/null

        if [[ -n "$SSH_AGENT_PID" ]] && \
           kill -0 "$SSH_AGENT_PID" 2>/dev/null && \
           [[ -S "$SSH_AUTH_SOCK" ]]; then
            echo "==== ✅ 成功加载已存在的 ssh-agent (PID: $SSH_AGENT_PID) ===="
            return 0
        else
            echo "==== ⚠️ 检测到无效或过期的 agent 记录，正在清理... ===="
            rm -f "$ENV_FILE" "$SOCKET_FILE"
            return 1
        fi
    fi
    return 1
}

add_keys() {
    echo "==== 🔍 检查需要添加的 SSH 密钥... ===="
    
    local loaded_fingerprints
    loaded_fingerprints=$(ssh-add -l)

    for key_path in "${KEYS_TO_ADD[@]}"; do
        if [[ -f "$key_path" ]]; then
            local key_fingerprint
            key_fingerprint=$(ssh-keygen -lf "$key_path" | awk '{print $2}')
            
            if ! echo "$loaded_fingerprints" | grep -qF "$key_fingerprint"; then
                echo "==== ➕ 正在添加密钥: $key_path ===="
                ssh-add "$key_path"
            else
                echo "==== 👍 密钥已加载: $key_path ===="
            fi
        else
            : # no-hop
        fi
    done
}

start_new_agent() {
    echo "==== 🚀 启动新的 ssh-agent... ===="
    
    ssh-agent -a "$SOCKET_FILE" > "$ENV_FILE"
    
    source "$ENV_FILE" >/dev/null
    
    if [[ -S "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        echo "==== ✅ 新 ssh-agent 启动成功 (PID: $SSH_AGENT_PID) ===="
        return 0
    else
        echo "==== ❌ ssh-agent 启动失败! ===="
        return 1
    fi
}

if ! try_load_agent; then
    if ! start_new_agent; then
        flock -u 200
        echo -e "==== ❗ 无法初始化 ssh-agent，请检查权限或系统问题。 ====\n"
        exit 1
    fi
fi

add_keys

flock -u 200

echo -e "==== ssh-agent 状态检查完成 ====\n"
