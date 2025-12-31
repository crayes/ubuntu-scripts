#!/bin/bash

################################################################################
# Script: check-updates.sh
# Descrição: Verifica atualizações disponíveis SEM executá-las
# Uso: Para testar antes de agendar o script principal
################################################################################

echo "================================================"
echo "Verificador de Atualizações Ubuntu"
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Execute como root: sudo $0"
    exit 1
fi

# Atualizar lista de pacotes
echo "📦 Atualizando lista de pacotes..."
apt-get update > /dev/null 2>&1
echo "✅ Lista atualizada"
echo ""

# Contar atualizações disponíveis
UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)

if [ "$UPDATES" -eq 0 ]; then
    echo "✅ Sistema está atualizado!"
    echo "   Nenhuma atualização disponível."
else
    echo "📊 Atualizações disponíveis: $UPDATES pacote(s)"
    echo ""
    echo "Pacotes que serão atualizados:"
    echo "----------------------------------------"
    apt list --upgradable 2>/dev/null | grep -v "Listing"
fi

echo ""
echo "================================================"

# Verificar atualizações de segurança
SECURITY_UPDATES=$(apt-get upgrade -s | grep -i security | wc -l)
if [ "$SECURITY_UPDATES" -gt 0 ]; then
    echo "🔒 Atualizações de segurança: $SECURITY_UPDATES"
fi

# Verificar se reboot é necessário
if [ -f /var/run/reboot-required ]; then
    echo "🔄 REBOOT NECESSÁRIO no momento"
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo ""
        echo "Pacotes que exigem reboot:"
        cat /var/run/reboot-required.pkgs | sed 's/^/   - /'
    fi
else
    echo "✅ Reboot não é necessário no momento"
fi

echo "================================================"
echo ""

# Informações do sistema
echo "ℹ️  Informações do Sistema:"
echo "   Versão Ubuntu: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p)"
echo ""
echo "================================================"

exit 0
