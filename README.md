# WCBRpar Systems - NixOS Configuration Repository

## 📋 Visão Geral

Este repositório contém a configuração completa de infraestrutura NixOS da WCBRpar, gerenciando servidores e workstations através de **Nix Flakes** com implantação automática via **Comin**.

### Arquitetura

```
systems/
├── flake.nix              # Entry point - Define inputs e outputs
├── configuration.nix      # Configuração base comum a todos os sistemas
├── vpsadminos.nix         # Compatibilidade com containers vpsAdminOS
├── hosts/                 # Configurações específicas de servidores
│   ├── default.nix        # Definição dos hosts (galactica, pegasus, yashuman)
│   ├── galactica.nix
│   ├── pegasus.nix
│   └── yashuman.nix
├── workstations/          # Configurações de estações de trabalho
│   ├── common.nix
│   ├── default.nix
│   └── t800.nix
├── modules/               # Módulos NixOS reutilizáveis
│   ├── acme/              # Certificados SSL/TLS
│   ├── agenix/            # Gerenciamento de secrets
│   ├── crm/               # Sistema CRM (Odoo)
│   ├── dns/               # Servidor DNS
│   ├── editor/            # Editores de texto
│   ├── home-manager/      # Gestão de ambientes usuário
│   ├── iam/               # Identity & Access Management (Kanidm)
│   ├── llm/               # Large Language Models
│   ├── monitoring/        # Monitoramento (Grafana, Prometheus)
│   ├── reverse-proxy/     # Proxy reverso (Caddy/Nginx)
│   ├── terminal/          # Configurações de terminal
│   ├── webserving/        # Servidores web
│   └── websites/          # Sites hospedados
├── networking/            # Configurações de rede
├── storage/               # Configurações de armazenamento
├── users/                 # Gestão de usuários
├── secrets/               # Secrets criptografadas com age
│   ├── secrets.nix        # Definição de recipients por secret
│   ├── rekey.nix          # Configuração para rekey automático
│   └── *.age              # Secrets criptografadas
├── npins/                 # Pinning de dependências externas
│   ├── sources.json
│   └── npins/
└── rekey.sh               # Script de re-criptografia de secrets
```

## 🖥️ Hosts Configurados

### Servidores

| Host | Função | IP Interno | Status |
|------|--------|------------|--------|
| **galactica** | Servidor principal | 192.168.13.10 | ✅ Ativo |
| **pegasus** | Servidor secundário | 192.168.13.20 | ✅ Ativo |
| **yashuman** | Servidor terciário | 192.168.13.130 | ✅ Ativo |

### Workstations

| Host | Hardware | Usuário | Status |
|------|----------|---------|--------|
| **t800** | Lenovo IdeaPad S145-15API | caroles | ✅ Ativo |

## 🚀 Quick Start

### Pré-requisitos

- NixOS com flakes habilitados
- Chave SSH registrada nos recipients das secrets
- Acesso ao repositório GitHub: `WCBRpar/systems`

### Primeiro Deploy

```bash
# Clonar o repositório
git clone git@github.com:WCBRpar/systems.git
cd systems

# Build e deploy local (se estiver no host)
sudo nixos-rebuild switch --flake .#<hostname> --impure

# Build e deploy remoto
sudo nixos-rebuild switch \
  --target-host user@<hostname>.wcbrpar.com \
  --flake .#<hostname> \
  --impure
```

### Deploy com Comin (Automático)

O Comin está configurado para sincronizar automaticamente a cada 60 segundos:

```bash
# Verificar status do Comin
systemctl status comin

# Logs do Comin
journalctl -u comin -f

# Forçar sync manual
comin pull
```

## 🔐 Gerenciamento de Secrets

### Estrutura de Secrets

As secrets são criptografadas usando **age** e gerenciadas pelo **agenix**:

```
secrets/
├── default.age                    # Secret padrão
├── ssh-key.age                    # Chaves SSH
├── onlyofficeDocumentServerKey.age
├── odooDatabaseKey.age
├── grafanaSecurityKey.age
├── openrouterApiKey.age
├── deepseekApiKey.age
├── telegramBotKey.age
└── host-{hostname}-key.age        # Chaves privadas de cada host
```

### Recipients

As secrets são acessíveis por:

- **Administradores**: `primary`, `devops`
- **Deploy Key**: Usada para bootstrap inicial
- **Hosts**: Cada host pode acessar suas próprias chaves

### Adicionar Nova Secret

```bash
# 1. Criar arquivo de secret
echo "valor-da-secret" > secrets/minha-secret.age

# 2. Editar secrets/secrets.nix adicionando os recipients
# "minha-secret.age".publicKeys = [ admin1 admin2 ];

# 3. Criptografar com agenix
nix run github:ryantm/agenix -- --secrets-file secrets/secrets.nix -e secrets/minha-secret.age
```

### Rekey de Hosts

Quando um host é reinstalado ou sua chave SSH muda:

```bash
# Rekey de um host específico
./rekey.sh pegasus

# Rekey de todos os hosts
./rekey.sh

# Verificar mudanças
git diff secrets/*.age

# Commit e deploy
git add secrets/*.age
git commit -m "chore: rekey secrets for pegasus"
git push
```

## 📦 Módulos Disponíveis

### Módulos Ativos

| Módulo | Descrição | Localização |
|--------|-----------|-------------|
| **acme** | Certificados SSL/TLS automáticos | `modules/acme/` |
| **agenix** | Gerenciamento seguro de secrets | `modules/agenix/` |
| **crm** | Sistema CRM baseado em Odoo | `modules/crm/` |
| **dns** | Servidor DNS | `modules/dns/` |
| **editor** | Editores (Neovim, VSCode) | `modules/editor/` |
| **home-manager** | Gestão de dotfiles por usuário | `modules/home-manager/` |
| **iam** | Identity & Access Management (Kanidm) | `modules/iam/` |
| **llm** | Integração com LLMs | `modules/llm/` |
| **monitoring** | Grafana + Prometheus | `modules/monitoring/` |
| **reverse-proxy** | Proxy reverso | `modules/reverse-proxy/` |
| **terminal** | Configurações de terminal | `modules/terminal/` |
| **webserving** | Servidores web | `modules/webserving/` |
| **websites** | Sites e aplicações web | `modules/websites/` |

### Módulos Desativados (Comentados)

- `filesharing` - Compartilhamento de arquivos
- `gitsync` - Sincronização Git (precisa reformar)
- `mail` - Servidor de e-mail
- `meeting` - Sistema de videoconferência (Jitsi)
- `n8n` - Automação de workflows
- `office` - Suite Office (OnlyOffice)

## 🔧 Comandos Úteis

### Build e Deploy

```bash
# Verificar configuração sem aplicar
nix flake check

# Build local
sudo nixos-rebuild build --flake .#<hostname>

# Switch local
sudo nixos-rebuild switch --flake .#<hostname> --impure

# Switch remoto
sudo nixos-rebuild switch \
  --target-host user@host.wcbrpar.com \
  --flake .#hostname \
  --impure

# Upgrade de pacotes
sudo nixos-rebuild switch --upgrade --flake .#<hostname>
```

### Debugging

```bash
# Listar configurações disponíveis
nix flake show

# Ver árvore de dependências
nix-store --query --tree $(which nixos-rebuild)

# Verificar secrets
nix run github:ryantm/agenix -- --secrets-file secrets/secrets.nix --check

# Logs do agenix
journalctl -u agenix -f

# Status do serviço de bootstrap SSH
systemctl status ssh-host-key-bootstrap
journalctl -u ssh-host-key-bootstrap -f
```

### Gerenciamento de Dependências

```bash
# Atualizar pins com npins
cd npins
npins update

# Atualizar inputs do flake
nix flake update

# Garbage collection
sudo nix-collect-garbage -d
```

## 🌐 Rede e Armazenamento

### Networking

Configurações de rede estão em `networking/default.nix`:

- Interface de rede principal
- Firewall (iptables/nftables)
- SSH hardening
- Bootstrap automático de chaves SSH

### Storage

Configurações de armazenamento em `storage/default.nix`:

- Filesystems persistentes
- Impermanence (opcional)
- Backups automáticos

## 👥 Usuários

Gestão de usuários em `users/default.nix`:

- Usuários locais
- Integração LDAP/Kanidm
- Home-manager por usuário

## 🔄 Fluxo de Trabalho CI/CD

### Pipeline de Deploy

1. **Desenvolvimento Local**
   ```bash
   # Testar mudanças
   nix flake check
   
   # Build de teste
   sudo nixos-rebuild build --flake .#<hostname>
   ```

2. **Commit e Push**
   ```bash
   git add .
   git commit -m "feat: descrição da mudança"
   git push origin main
   ```

3. **Sincronização Automática (Comin)**
   - Comin detecta mudanças no GitHub (polling a cada 60s)
   - Pull automático das mudanças
   - Executa `nixos-rebuild switch`

4. **Verificação**
   ```bash
   # Verificar status
   systemctl status comin
   
   # Ver logs
   journalctl -u comin -f
   ```

## 🛠️ Troubleshooting

### Erros Comuns

#### "Private key not found"

```bash
# Verificar se a secret foi descriptografada
ls -la /etc/ssh/ssh_host_ed25519_key

# Ver logs do agenix
journalctl -u agenix -f

# Verificar recipients
cat secrets/secrets.nix | grep -A 5 "host-<hostname>"
```

#### "Public key mismatch"

```bash
# Comparar chaves
cat /etc/ssh/ssh_host_ed25519_key.pub
cat hosts/default.nix | grep sshPublicKey

# Se diferente, executar rekey
./rekey.sh <hostname>
```

#### Falha no Comin

```bash
# Reiniciar serviço
sudo systemctl restart comin

# Verificar permissões SSH
sudo -u comin ssh -T git@github.com

# Verificar configuração
cat /etc/nixos/comin.toml
```

#### Build falha com "permittedInsecurePackages"

```bash
# Adicionar pacote em configuration.nix ou flake.nix:
nixpkgs.config.permittedInsecurePackages = [
  "nome-do-pacote-inseguro"
];
```

## 📚 Referências

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://wiki.nixos.org/wiki/Flakes)
- [Agenix](https://github.com/ryantm/agenix) - Gerenciamento de secrets
- [Agenix-Rekey](https://github.com/oddlama/agenix-rekey) - Re-criptografia automática
- [Comin](https://github.com/nlewo/comin) - GitOps para NixOS
- [Home Manager](https://github.com/nix-community/home-manager)
- [vpsAdminOS](https://github.com/vpsfreecz/vpsadminos) - Containers NixOS

## 📝 Convenções de Nomenclatura

Os nomes dos hosts seguem o esquema **Battlestar Galactica**:

- [Naming Schemes - Battlestar Galactica](https://namingschemes.com/Battlestar_Galactica)

## 🔒 Segurança

### Best Practices Implementadas

1. **Secrets Criptografadas**: Todas as secrets usam age encryption
2. **Múltiplos Recipients**: Redundância de acesso às secrets
3. **SSH Hardening**: Configurações seguras de SSH
4. **Firewall**: Regras de firewall restritivas
5. **Auto Updates**: Atualizações automáticas de segurança habilitadas
6. **Garbage Collection**: Limpeza semanal de pacotes antigos

### Chaves SSH

- Chaves de host gerenciadas via agenix
- Bootstrap automático de chaves públicas
- Rekey automatizado quando chaves mudam

## 🤝 Contribuição

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Teste localmente com `nix flake check`
4. Commit suas mudanças (`git commit -m 'feat: nova feature'`)
5. Push para a branch (`git push origin feature/nova-feature`)
6. Abra um Pull Request

## 📄 Licença

Proprietário - WCBRpar

---

**Última atualização**: 2024
**Maintainers**: WCBRpar DevOps Team
