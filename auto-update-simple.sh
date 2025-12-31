#!/bin/bash

################################################################################
# Script: auto-update-simple.sh
# Descrição: Versão simplificada - Atualiza Ubuntu e reinicia se necessário
# Uso: Para quem prefere um script mais direto
################################################################################

# Executar como root
if [ "$EUID" -ne 0 ]; then 
    echo "Execute como root: sudo $0"
    exit 1
fi

LOG="/var/log/auto-update.log"
echo "[$(date)] Iniciando atualizações..." | tee -a "$LOG"

# Update
apt-get update >> "$LOG" 2>&1

# Upgrade não-interativo
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$LOG" 2>&1

# Limpeza
apt-get autoremove -y >> "$LOG" 2>&1
apt-get autoclean >> "$LOG" 2>&1

# Verificar se precisa reiniciar
if [ -f /var/run/reboot-required ]; then
    echo "[$(date)] Reiniciando servidor..." | tee -a "$LOG"
    sleep 60
    /sbin/shutdown -r now "Atualização automática"
else
    echo "[$(date)] Atualização concluída. Reboot não necessário." | tee -a "$LOG"
fi

exit 0
