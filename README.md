# Sistema de Atualização Automática Ubuntu
Sistema completo para automação de atualizações do Ubuntu com verificação de reboot

---

## 📋 VISÃO GERAL

Este pacote contém 3 scripts para gerenciar atualizações no Ubuntu:

1. **auto-update.sh** - Script completo com logging detalhado e notificações
2. **auto-update-simple.sh** - Versão simplificada e direta
3. **check-updates.sh** - Verificador de atualizações (não executa, apenas verifica)

---

## 🚀 INÍCIO RÁPIDO

### Instalação em 3 passos:

```bash
# 1. Copiar script para o servidor
sudo cp auto-update.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/auto-update.sh

# 2. Configurar cron para executar toda Segunda às 2h
sudo crontab -e
# Adicionar: 0 2 * * 1 /usr/local/bin/auto-update.sh

# 3. Testar manualmente
sudo /usr/local/bin/auto-update.sh
```

---

## 📁 ARQUIVOS INCLUÍDOS

### 1. auto-update.sh (RECOMENDADO)
**Script principal com recursos completos:**
- ✅ Logging detalhado em `/var/log/auto-update.log`
- ✅ Executa `apt-get update` e `upgrade`
- ✅ Remove pacotes desnecessários (autoremove)
- ✅ Limpa cache (autoclean)
- ✅ Detecta necessidade de reboot
- ✅ Aguarda 2 minutos antes de reiniciar
- ✅ Suporte para notificações por email (opcional)
- ✅ Tratamento de erros robusto

**Quando usar:**
- Produção e ambientes críticos
- Quando você precisa de logs detalhados
- Quando quer receber notificações

### 2. auto-update-simple.sh
**Versão minimalista:**
- ✅ Código simples e direto
- ✅ Log básico
- ✅ Atualiza e reinicia se necessário
- ✅ Aguarda 1 minuto antes de reiniciar

**Quando usar:**
- Ambientes de desenvolvimento/teste
- Quando você prefere simplicidade
- Servidores não-críticos

### 3. check-updates.sh
**Verificador de atualizações:**
- ✅ Verifica atualizações disponíveis
- ✅ Lista pacotes que serão atualizados
- ✅ Identifica atualizações de segurança
- ✅ Verifica se reboot é necessário
- ✅ Mostra informações do sistema
- ⚠️ NÃO executa atualizações

**Quando usar:**
- Antes de agendar o script principal
- Para monitoramento manual
- Para verificar status sem fazer alterações

---

## ⚙️ CONFIGURAÇÃO DO CRON

### Horários Recomendados

```bash
# Domingo às 3h da manhã (fim de semana)
0 3 * * 0 /usr/local/bin/auto-update.sh

# Segunda às 2h da manhã (início da semana)
0 2 * * 1 /usr/local/bin/auto-update.sh

# Sábado às 4h da manhã (fim de semana)
0 4 * * 6 /usr/local/bin/auto-update.sh
```

### Como Configurar

```bash
# Editar crontab do root
sudo crontab -e

# Adicionar a linha desejada e salvar
```

---

## 🔍 MONITORAMENTO

### Verificar Logs
```bash
# Ver últimas entradas
sudo tail -f /var/log/auto-update.log

# Ver log completo
sudo less /var/log/auto-update.log

# Ver últimas 50 linhas
sudo tail -n 50 /var/log/auto-update.log
```

### Verificar Status do Cron
```bash
# Ver tarefas agendadas
sudo crontab -l

# Verificar se cron está ativo
sudo systemctl status cron

# Ver execuções recentes do cron
grep CRON /var/log/syslog | tail -20
```

### Verificar Reboot Pendente
```bash
# Verificar se reboot é necessário
ls -la /var/run/reboot-required

# Ver pacotes que requerem reboot
cat /var/run/reboot-required.pkgs
```

---

## 🧪 TESTES

### 1. Testar Verificação (Sem Executar)
```bash
sudo bash check-updates.sh
```

### 2. Testar Execução Manual
```bash
# Script completo
sudo /usr/local/bin/auto-update.sh

# Script simples
sudo /usr/local/bin/auto-update-simple.sh
```

### 3. Testar Cron (Execução Imediata)
```bash
# Adicionar temporariamente no cron para executar em 5 minutos
# Por exemplo, se agora são 14:30, adicione:
# 35 14 * * * /usr/local/bin/auto-update.sh

# Depois remova essa linha
```

---

## 🛡️ SEGURANÇA

### Recomendações:

1. **Backup antes de agendar:**
   - Faça snapshot/backup do servidor antes da primeira execução automática

2. **Teste manual primeiro:**
   - Execute o script manualmente algumas vezes antes de agendar

3. **Horário adequado:**
   - Agende para horários de baixo tráfego (madrugada/fim de semana)

4. **Notificações:**
   - Configure email para ser notificado de problemas

5. **Monitoramento:**
   - Verifique os logs regularmente nas primeiras semanas

---

## 🔧 PERSONALIZAÇÃO

### Alterar Tempo de Espera antes do Reboot

No script, encontre e altere:
```bash
sleep 120  # Trocar para 300 = 5 minutos, ou 60 = 1 minuto
```

### Habilitar Notificações por Email

1. Instalar mailutils:
```bash
sudo apt-get install mailutils
```

2. No script, descomentar:
```bash
# echo "$message" | mail -s "$subject" seu-email@rfaa.com.br
```

### Adicionar dist-upgrade

No script auto-update.sh, descomentar o bloco:
```bash
# log_message "Executando apt-get dist-upgrade..."
# if DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade...
```

---

## 📊 ROTAÇÃO DE LOGS

Para evitar crescimento infinito do arquivo de log:

```bash
# Criar arquivo de configuração
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
```

---

## ❌ DESINSTALAÇÃO

```bash
# 1. Remover do cron
sudo crontab -e
# Deletar a linha do script

# 2. Remover scripts
sudo rm /usr/local/bin/auto-update.sh
sudo rm /usr/local/bin/auto-update-simple.sh
sudo rm /usr/local/bin/check-updates.sh

# 3. Remover logs
sudo rm /var/log/auto-update.log
```

---

## 🐛 SOLUÇÃO DE PROBLEMAS

### Script não executa automaticamente
```bash
# Verificar se cron está ativo
sudo systemctl status cron
sudo systemctl start cron
sudo systemctl enable cron
```

### Permissões incorretas
```bash
sudo chmod +x /usr/local/bin/auto-update.sh
sudo chown root:root /usr/local/bin/auto-update.sh
```

### Ver erros do cron
```bash
sudo grep CRON /var/log/syslog | grep auto-update
```

---

## 📞 SUPORTE

Para dúvidas ou problemas:
1. Consulte os logs: `sudo tail -f /var/log/auto-update.log`
2. Execute manualmente para ver erros: `sudo bash -x /usr/local/bin/auto-update.sh`
3. Verifique as permissões: `ls -la /usr/local/bin/auto-update.sh`

---

## 📝 CHANGELOG

- **v1.0** - Versão inicial com 3 scripts
  - Script completo com logging
  - Versão simplificada
  - Verificador de atualizações

---

**Desenvolvido para: Rayes Fagundes Advogados Associados**  
**Administrador: Celso Nassif**  
**Data: 2025**
