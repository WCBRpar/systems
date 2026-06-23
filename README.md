# WCBRpar Systems - NixOS Configuration Repository

## 📋 Visão Geral

Este repositório contém a configuração completa de infraestrutura NixOS da WCBRpar, gerenciando servidores e workstations através de **Nix Flakes** com implantação automática via **Comin**. A infraestrutura atual é composta por três servidores hospedados na vpsfree.cz, além de estações de trabalho e dispositivos móveis.

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
│   ├── t800.nix
│   ├── t101.nix
│   └── redpad002.nix      # Configuração Nix-on-Droid
├── modules/               # Módulos NixOS reutilizáveis
│   ├── acme/              # Certificados SSL/TLS (via Traefik)
│   ├── agenix/            # Gerenciamento de secrets
│   ├── crm/               # Sistema CRM (Odoo)
│   ├── dns/               # Servidor DNS
│   ├── editor/            # Editores de texto
│   ├── filesharing/       # Compartilhamento NFS
│   ├── home-manager/      # Gestão de ambientes usuário
│   ├── iam/               # Identity & Access Management (Kanidm)
│   ├── llm/               # Large Language Models
│   ├── mail/              # Servidor de e-mail e agenda (Radicale)
│   ├── monitoring/        # Monitoramento (Grafana, Prometheus, Loki)
│   ├── reverse-proxy/     # Proxy reverso (Traefik)
│   ├── terminal/          # Configurações de terminal
│   ├── webserving/        # Servidores web (Nginx)
│   └── websites/          # Sites hospedados e rotas Traefik
├── networking/            # Configurações de rede (ZeroTier, Firewall, SSH)
├── storage/               # Configurações de armazenamento (NFS)
├── users/                 # Gestão de usuários
├── secrets/               # Secrets criptografadas com age
│   ├── secrets.nix        # Definição de recipients por secret
│   ├── rekey.nix          # Configuração para rekey automático
│   └── *.age              # Secrets criptografadas
├── npins/                 # Pinning de dependências externas
└── rekey.sh               # Script de re-criptografia de secrets
```

## 🖥️ Hosts Configurados

Os nomes dos hosts seguem o esquema **Battlestar Galactica** [1].

### Servidores (vpsfree.cz)

| Host | Função | IP Interno (ZeroTier) | IP Externo | HostID | VPS ID |
|------|--------|-----------------------|------------|--------|--------|
| **galactica** | Servidor principal (IAM, Proxy, Mail, Monitoramento) | 192.168.13.10 | 37.205.8.86 | 13960a97 | 27116 |
| **pegasus** | Servidor secundário (Websites, CRM) | 192.168.13.20 | 37.205.14.63 | 8bf0dda5 | 27447 |
| **yashuman** | Servidor terciário (NFS Server) | 192.168.13.130 | 37.205.14.75 | e491eb5c | 27687 |

### Workstations e Dispositivos

| Host | Tipo | Usuário | Status |
|------|------|---------|--------|
| **t800** | Workstation | caroles | ✅ Ativo |
| **t101** | Workstation | - | ⏳ Em configuração |
| **redpad002** | Nix-on-Droid | wjjunyor | ✅ Ativo |

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
  --target-host root@<hostname>.wcbrpar.com \
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

As secrets são criptografadas usando **age** e gerenciadas pelo **agenix** com suporte a rekey automático via **agenix-rekey**.

### Estrutura de Secrets

```
secrets/
├── default.age                    # Secret padrão
├── cloudflareApiKey.age           # API Key para DNS Challenge (Traefik)
├── kanidmIdmAdminPassword.age     # Senha admin do Kanidm
├── grafanaSecurityKey.age         # Chave de segurança do Grafana
├── odooDatabaseKey.age            # Chave do banco de dados Odoo
├── mailWalterPassword.age         # Senha do e-mail principal
└── host-{hostname}-key.age        # Chaves privadas SSH de cada host
```

### Rekey de Hosts

Quando um host é reinstalado ou sua chave SSH muda:

```bash
# Rekey de um host específico
./rekey.sh pegasus

# Rekey de todos os hosts
./rekey.sh

# Commit e deploy
git add secrets/*.age
git commit -m "chore: rekey secrets"
git push
```

## 📦 Módulos Ativos

A infraestrutura é composta por diversos módulos, sendo os principais:

| Módulo | Descrição | Localização |
|--------|-----------|-------------|
| **iam** | Identity & Access Management via Kanidm (SSO, LDAP) | `modules/iam/` |
| **reverse-proxy** | Traefik com integração OIDC (Kanidm) e Cloudflare ACME | `modules/reverse-proxy/` |
| **monitoring** | Grafana, Prometheus e Loki com SSO | `modules/monitoring/` |
| **mail** | Servidor de e-mail completo (Postfix/Dovecot) e Agenda (Radicale) | `modules/mail/` |
| **filesharing** | Servidor e cliente NFS | `modules/filesharing/` |
| **crm** | Sistema CRM baseado em Odoo | `modules/crm/` |
| **websites** | Sites e aplicações web roteados via Traefik | `modules/websites/` |

*Nota: Módulos como `gitsync`, `meeting`, `n8n` e `office` estão presentes no repositório, mas atualmente desativados.*

## 🌐 Rede e Armazenamento

### Networking

Configurações de rede centralizadas em `networking/default.nix`:
- **ZeroTier**: Rede privada virtual (192.168.13.0/24) interligando todos os hosts.
- **Firewall**: Regras restritivas confiando na interface ZeroTier (`ztc25hlssg`) e `venet0`.
- **SSH**: Escuta restrita ao IP interno ZeroTier, com chaves de host gerenciadas via agenix.

### Storage

Configurações de armazenamento em `storage/default.nix` e `modules/filesharing/default.nix`:
- **NFS**: O host `yashuman` atua como servidor NFS, exportando `/nas-data/home` e `/nas-data/shared` para a rede ZeroTier.

## 👥 Usuários e Autenticação

A gestão de usuários é híbrida:
- **Local**: Definidos em `users/default.nix` (root, wjjunyor, caroles).
- **Centralizada (IAM)**: O Kanidm (`galactica`) provê autenticação SSO (OIDC) para serviços web (Traefik Dashboard, Grafana, Radicale) e LDAP para o servidor de e-mail.

## 🔄 Fluxo de Trabalho CI/CD

1. **Desenvolvimento Local**: Teste mudanças com `nix flake check`.
2. **Commit e Push**: Envie as alterações para a branch `main`.
3. **Sincronização Automática**: O Comin detecta as mudanças e aplica via `nixos-rebuild switch` em cada host.

## 📚 Referências

1. [Naming Schemes - Battlestar Galactica](https://namingschemes.com/Battlestar_Galactica)
2. [NixOS Manual](https://nixos.org/manual/nixos/stable/)
3. [Agenix](https://github.com/ryantm/agenix)
4. [Comin](https://github.com/nlewo/comin)

---

**Última atualização**: Junho de 2026
**Maintainers**: WCBRpar DevOps Team (Walter Queiroz)
