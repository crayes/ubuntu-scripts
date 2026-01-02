#!/bin/bash

################################################################################
# Script: auto-update.sh
# Descrição: Atualiza o sistema Ubuntu e reinicia se necessário
# Uso: Agendado via cron para execução semanal
# Autor: Nassif
# Data: 2024
################################################################################

# Configurações
LOG_FILE="/var/log/auto-update.log"
REBOOT_REQUIRED_FILE="/var/run/reboot-required"
DATE_FORMAT="+%Y-%m-%d %H:%M:%S"

# Função para logging
log_message() {
    echo "[$(date "$DATE_FORMAT")] $1" | tee -a "$LOG_FILE"
}

# Função para enviar email (opcional - requer mailutils instalado)
send_notification() {
    local subject="$1"
    local message="$2"
    
    # Descomente e configure se quiser receber emails
    # echo "$message" | mail -s "$subject" admin@rfaa.com.br
}

# Início do script
log_message "=========================================="
log_message "Iniciando processo de atualização automática"
log_message "=========================================="

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    log_message "ERRO: Este script precisa ser executado como root"
    exit 1
fi

# Atualizar lista de pacotes
log_message "Executando apt-get update..."
if apt-get update >> "$LOG_FILE" 2>&1; then
    log_message "apt-get update: SUCESSO"
else
    log_message "ERRO: Falha ao executar apt-get update"
    send_notification "Erro na Atualização do Servidor" "Falha ao executar apt-get update"
    exit 1
fi

# Verificar se há atualizações disponíveis
UPDATES_AVAILABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
log_message "Pacotes disponíveis para atualização: $UPDATES_AVAILABLE"

if [ "$UPDATES_AVAILABLE" -eq 0 ]; then
    log_message "Nenhuma atualização disponível. Sistema já está atualizado."
    log_message "=========================================="
    exit 0
fi

# Executar upgrade
log_message "Executando apt-get upgrade..."
if DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1; then
    log_message "apt-get upgrade: SUCESSO"
else
    log_message "ERRO: Falha ao executar apt-get upgrade"
    send_notification "Erro na Atualização do Servidor" "Falha ao executar apt-get upgrade"
    exit 1
fi

 Executar dist-upgrade (opcional - descomente se quiser)
 log_message "Executando apt-get dist-upgrade..."
 if DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1; then
     log_message "apt-get dist-upgrade: SUCESSO"
 else
     log_message "ERRO: Falha ao executar apt-get dist-upgrade"
 fi

# Remover pacotes desnecessários
log_message "Executando autoremove..."
if apt-get autoremove -y >> "$LOG_FILE" 2>&1; then
    log_message "autoremove: SUCESSO"
else
    log_message "AVISO: Falha ao executar autoremove (não crítico)"
fi

# Limpar cache
log_message "Executando autoclean..."
if apt-get autoclean >> "$LOG_FILE" 2>&1; then
    log_message "autoclean: SUCESSO"
else
    log_message "AVISO: Falha ao executar autoclean (não crítico)"
fi

# Verificar se é necessário reiniciar
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
    log_message "=========================================="
    log_message "REBOOT NECESSÁRIO DETECTADO!"
    log_message "Motivo: $(cat $REBOOT_REQUIRED_FILE 2>/dev/null || echo 'Atualizações de kernel ou sistema')"
    
    # Verificar se há pacotes que requerem reboot
    if [ -f "/var/run/reboot-required.pkgs" ]; then
        log_message "Pacotes que requerem reboot:"
        cat /var/run/reboot-required.pkgs | while read pkg; do
            log_message "  - $pkg"
        done
    fi
    
    # Notificar antes de reiniciar (opcional)
    send_notification "Servidor será reiniciado" "O servidor será reiniciado em 2 minutos devido a atualizações"
    
    # Aguardar 2 minutos antes de reiniciar (permite cancelar se necessário)
    log_message "Servidor será reiniciado em 2 minutos..."
    sleep 120
    
    log_message "Reiniciando servidor AGORA..."
    log_message "=========================================="
    
    # Reiniciar o servidor
    /sbin/shutdown -r now "Reinicialização automática após atualizações"
else
    log_message "=========================================="
    log_message "Reboot NÃO é necessário"
    log_message "Atualizações concluídas com sucesso!"
    log_message "=========================================="
fi

exit 0
