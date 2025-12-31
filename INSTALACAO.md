# Instruções de Instalação e Configuração
# Script de Atualização Automática do Ubuntu

## 1. INSTALAÇÃO DO SCRIPT

### Copiar o script para o servidor
scp auto-update.sh root@seu-servidor:/usr/local/bin/

### OU criar diretamente no servidor
sudo nano /usr/local/bin/auto-update.sh
# Cole o conteúdo do script e salve (Ctrl+O, Enter, Ctrl+X)

### Dar permissões de execução
sudo chmod +x /usr/local/bin/auto-update.sh

### Criar o diretório de log (se não existir)
sudo touch /var/log/auto-update.log
sudo chmod 644 /var/log/auto-update.log


## 2. CONFIGURAÇÃO DO CRON (AGENDAMENTO SEMANAL)

### Editar o crontab do root
sudo crontab -e

### Adicionar uma das seguintes linhas:

# Opção 1: Executar todo Domingo às 3h da manhã
0 3 * * 0 /usr/local/bin/auto-update.sh

# Opção 2: Executar toda Segunda-feira às 2h da manhã
0 2 * * 1 /usr/local/bin/auto-update.sh

# Opção 3: Executar todo Sábado às 4h da manhã
0 4 * * 6 /usr/local/bin/auto-update.sh


## 3. FORMATO DO CRON EXPLICADO

# ┌───────────── minuto (0 - 59)
# │ ┌───────────── hora (0 - 23)
# │ │ ┌───────────── dia do mês (1 - 31)
# │ │ │ ┌───────────── mês (1 - 12)
# │ │ │ │ ┌───────────── dia da semana (0 - 6) (0 = Domingo)
# │ │ │ │ │
# │ │ │ │ │
# * * * * * comando a executar

### Dias da semana:
# 0 = Domingo
# 1 = Segunda-feira
# 2 = Terça-feira
# 3 = Quarta-feira
# 4 = Quinta-feira
# 5 = Sexta-feira
# 6 = Sábado


## 4. VERIFICAR SE O CRON ESTÁ CONFIGURADO

### Listar tarefas do cron
sudo crontab -l

### Verificar se o serviço cron está rodando
sudo systemctl status cron


## 5. TESTAR O SCRIPT MANUALMENTE

### Executar o script
sudo /usr/local/bin/auto-update.sh

### Verificar o log
sudo tail -f /var/log/auto-update.log


## 6. CONFIGURAÇÕES OPCIONAIS

### A) Habilitar notificações por email
# Instalar mailutils
sudo apt-get install mailutils

# No script, descomentar e configurar as linhas:
# echo "$message" | mail -s "$subject" seu-email@rfaa.com.br

### B) Alterar tempo de espera antes do reboot
# No script, alterar a linha:
# sleep 120  # Trocar 120 por outro valor em segundos

### C) Habilitar dist-upgrade (atualizações mais agressivas)
# No script, descomentar o bloco dist-upgrade

### D) Rotação de logs (evitar crescimento infinito)
sudo nano /etc/logrotate.d/auto-update

# Adicionar:
/var/log/auto-update.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
}


## 7. MONITORAMENTO E MANUTENÇÃO

### Ver últimas 50 linhas do log
sudo tail -n 50 /var/log/auto-update.log

### Ver todo o log
sudo less /var/log/auto-update.log

### Verificar se há reboot pendente
ls -la /var/run/reboot-required

### Ver próximas execuções do cron
grep CRON /var/log/syslog | tail -20


## 8. SOLUÇÃO DE PROBLEMAS

### Problema: Script não executa automaticamente
# Verificar se o cron está ativo
sudo systemctl status cron
sudo systemctl start cron
sudo systemctl enable cron

### Problema: Permissões incorretas
sudo chmod +x /usr/local/bin/auto-update.sh
sudo chown root:root /usr/local/bin/auto-update.sh

### Problema: Script executa mas não atualiza
# Verificar o log para mensagens de erro
sudo cat /var/log/auto-update.log


## 9. DESABILITAR TEMPORARIAMENTE

### Comentar a linha no cron
sudo crontab -e
# Adicionar # no início da linha do script


## 10. REMOVER COMPLETAMENTE

### Remover do cron
sudo crontab -e
# Deletar a linha do script

### Remover o script
sudo rm /usr/local/bin/auto-update.sh

### Remover o log
sudo rm /var/log/auto-update.log


## EXEMPLOS DE AGENDAMENTOS ALTERNATIVOS

# A cada 2 semanas no Domingo às 3h
0 3 * * 0 [ $(date +\%U) -eq $(($(date +\%U) \% 2)) ] && /usr/local/bin/auto-update.sh

# Primeiro Domingo do mês às 4h
0 4 1-7 * 0 /usr/local/bin/auto-update.sh

# Toda terça e sexta às 2h
0 2 * * 2,5 /usr/local/bin/auto-update.sh
