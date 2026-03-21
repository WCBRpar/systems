# Gerenciamento de Chaves SSH Host - Solução Completa

## Problema Resolvido

O problema do "ovo e a galinha" ao gerenciar chaves SSH de hosts múltiplos com agenix:
- Com `generateHostKeys = false`, o NixOS não gera chaves automaticamente
- O agenix precisa descriptografar a chave privada, mas o SSH precisa da chave pública correspondente
- Em um deploy novo, não há chave pública inicial, causando falha na descriptografia

## Solução Implementada (Duas Fases)

### Fase 1: Curto Prazo (Bootstrap Manual) ✅ IMPLEMENTADO

**Arquivo modificado:** `networking/default.nix`

Adicionado serviço systemd `ssh-host-key-bootstrap` que:
1. Roda APÓS o agenix instalar a chave privada
2. Roda ANTES do sshd iniciar
3. Gera a chave pública a partir da privada SE ela não existir
4. É idempotente (não faz nada se a chave pública já existir)

```nix
systemd.services.ssh-host-key-bootstrap = {
  description = "Generate SSH host public key from private key if missing";
  before = [ "sshd.service" ];
  after = [ "agenix.service" ];
  wantedBy = [ "multi-user.target" ];
  # ... script que usa ssh-keygen -y para derivar a pública
};
```

**Como usar:**
```bash
# No primeiro deploy de um host novo:
sudo nixos-rebuild switch --flake .#pegasus --impure

# O script vai:
# 1. Agenix instala a chave privada em /etc/ssh/ssh_host_ed25519_key
# 2. Script detecta que não há chave pública
# 3. Gera a pública a partir da privada
# 4. SSHD inicia normalmente
```

### Fase 2: Médio Prazo (Rekey Automático) ✅ IMPLEMENTADO

**Novas dependências:** `agenix-rekey` do oddlama

**Arquivos adicionados:**
- `flake.nix`: Input e módulo do agenix-rekey
- `secrets/rekey.nix`: Definição das chaves públicas para rekey
- `rekey.sh`: Script utilitário para re-encryptação

**Como usar:**
```bash
# Quando uma chave de host mudar (ex: pegasus foi reinstalado):
./rekey.sh pegasus

# Ou para todos os hosts:
./rekey.sh

# Verificar mudanças:
git diff secrets/*.age

# Commit e deploy:
git add secrets/*.age && git commit -m "chore: rekey secrets for pegasus"
git push

# No próximo deploy, o comin vai sincronizar automaticamente
```

## Fluxo Completo de Deploy

### Cenário 1: Host Existente (Chave Não Mudou)
```
1. nixos-rebuild switch --flake .#pegasus
2. Agenix descriptografa host-pegasus-key.age ✓
3. Instala chave privada em /etc/ssh/ssh_host_ed25519_key
4. Script bootstrap vê que chave pública já existe → skip
5. SSHD inicia com chaves corretas ✓
```

### Cenário 2: Host Novo ou Reinstalado (Chave Nova)
```
1. Admin gera nova chave no host (ou primeira instalação)
2. Executa: ./rekey.sh pegasus
3. agenix-rekey atualiza secrets/host-pegasus-key.age com nova chave
4. Commit e push das mudanças
5. nixos-rebuild switch --flake .#pegasus
6. Agenix descriptografa com nova chave ✓
7. Script bootstrap gera pública a partir da privada ✓
8. SSHD inicia ✓
```

### Cenário 3: Deploy Remoto (Primeira Vez)
```
1. nixos-rebuild switch --target-host user@pegasus.wcbrpar.com --flake .#pegasus
2. Conexão SSH usa known_hosts (chave pública do hosts/default.nix)
3. Build ocorre na máquina local
4. Configuração é enviada para o host
5. Agenix descriptografa (chave do admin está no recipients) ✓
6. Script bootstrap gera pública ✓
7. SSHD reinicia com chaves corretas ✓
```

## Arquivos Modificados/Criados

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `networking/default.nix` | Modificado | Adiciona serviço systemd de bootstrap |
| `flake.nix` | Modificado | Adiciona input e módulo agenix-rekey |
| `secrets/rekey.nix` | Criado | Definição de keys para rekey automático |
| `rekey.sh` | Criado | Script utilitário para re-encryptação |

## Comandos Úteis

```bash
# Rekey de um host específico
./rekey.sh pegasus

# Rekey de todos os hosts
./rekey.sh

# Testar configuração sem aplicar
nix flake check

# Build remoto
sudo nixos-rebuild switch --upgrade --show-trace --sudo \
  --target-host wjjunyor@pegasus.wcbrpar.com \
  --flake .#pegasus --impure

# Build local (se estiver no host)
sudo nixos-rebuild switch --flake .#pegasus --impure

# Verificar status do serviço de bootstrap
systemctl status ssh-host-key-bootstrap

# Logs do bootstrap
journalctl -u ssh-host-key-bootstrap -f
```

## Notas Importantes

1. **Chave Deploy**: A `deployKey` em `secrets/secrets.nix` permite o primeiro bootstrap
   antes da chave do host estar disponível.

2. **Recipients**: As secrets de host são acessíveis por:
   - Admins (primary, devops)
   - Deploy Key (bootstrap)
   - Todos os hosts (para futuros rekeys automáticos)

3. **Idempotência**: O script de bootstrap é seguro para rodar múltiplas vezes
   - Só gera a chave pública se ela não existir
   - Não sobrescreve chaves existentes

4. **Segurança**: 
   - Chaves privadas sempre criptografadas com age
   - Múltiplos recipients permitem recuperação
   - Known hosts atualizados automaticamente via `programs.ssh.knownHosts`

## Troubleshooting

### Erro: "Private key not found"
```bash
# Verifique se o secret foi descriptografado
ls -la /etc/ssh/ssh_host_ed25519_key

# Se não existir, verifique logs do agenix
journalctl -u agenix -f

# Verifique se a chave do host está nos recipients
cat secrets/secrets.nix | grep -A 5 "host-pegasus"
```

### Erro: "Public key mismatch"
```bash
# Compare a chave pública instalada com a esperada
cat /etc/ssh/ssh_host_ed25519_key.pub
cat hosts/default.nix | grep sshPublicKey

# Se diferente, execute rekey
./rekey.sh pegasus
git add secrets/*.age && git commit -m "chore: rekey pegasus"
git push
```

### Serviço não roda
```bash
# Verifique dependências do systemd
systemctl list-dependencies ssh-host-key-bootstrap

# Force o reload
systemctl daemon-reload
systemctl restart ssh-host-key-bootstrap
```

## Referências

- [agenix](https://github.com/ryantm/agenix) - Gerenciamento de secrets
- [agenix-rekey](https://github.com/oddlama/agenix-rekey) - Re-encryptação automática
- [nix-config (oddlama)](https://github.com/oddlama/nix-config) - Inspiração para fallback de chaves
