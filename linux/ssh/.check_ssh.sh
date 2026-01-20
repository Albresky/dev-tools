#!/usr/bin/env sh

# ==============================================================================
# SSH Agent Loader
# Compatibility: sh, bash, zsh
# ==============================================================================

_auto_load_ssh_agent() {
    # --- Configs ---
    local SSH_ENV="$HOME/.ssh/agent.env"
    # solit with space
    local KEYS_TO_ADD="$HOME/.ssh/id_ed25519_github"

    _log() {
        printf "=> [SSH] %s\n" "$*"
    }
    
    _start_agent() {
        _log "Launching NEW ssh-agent..."
        ssh-agent -s > "$SSH_ENV"
        chmod 600 "$SSH_ENV"
        . "$SSH_ENV" > /dev/null
    }

    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        if [ -z "$SSH_AGENT_PID" ]; then
            _log "External Forward Agent Detected (Socket: $SSH_AUTH_SOCK)"
        fi
    else
        if [ -f "$SSH_ENV" ]; then
            . "$SSH_ENV" > /dev/null
        fi

        if [ -n "$SSH_AGENT_PID" ] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
             _log "Reusing Alive Agent (PID: $SSH_AGENT_PID)"
        else
            _start_agent
        fi
    fi

    if ! command -v ssh-add >/dev/null 2>&1; then
        _log "Error: ssh-add command not found"
        return 0
    fi

    local loaded_fingerprints
    loaded_fingerprints=$(ssh-add -l 2>/dev/null)

    if [ -n "$ZSH_VERSION" ]; then
        setopt localoptions shwordsplit 2>/dev/null
    fi

    for key in $KEYS_TO_ADD; do
        if [ -f "$key" ]; then
            local key_fingerprint
            key_fingerprint=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}')

            if [ -z "$key_fingerprint" ]; then
                 _log "Warning: Failed in Reading fingerprint: $key"
                 continue
            fi

            if echo "$loaded_fingerprints" | grep -qF "$key_fingerprint"; then
                _log "Skipping loading fingerprint (exists already): $(basename "$key")"
            else
                _log "Adding Key: $key"
                ssh-add "$key"
            fi
        else
            _log "Error: Failed in Finding Key: $key"
        fi
    done
}

_auto_load_ssh_agent

unset -f _auto_load_ssh_agent
