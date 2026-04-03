# Integração Kanidm + Traefik para Autenticação Web

## Visão Geral

Esta documentação descreve a implementação de autenticação via Kanidm (IdP) para aplicações web protegidas pelo Traefik usando o plugin `traefik-oidc-auth`.

## Arquitetura

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Usuário   │────▶│   Traefik   │────▶│  Aplicação  │
│             │     │  (Reverse   │     │  Backend    │
│             │◀────│   Proxy)    │◀────│             │
└─────────────┘     └──────┬──────┘     └─────────────┘
                           │
                           │ OIDC
                           ▼
                    ┌─────────────┐
                    │   Kanidm    │
                    │   (IdP)     │
                    └─────────────┘
```

## Componentes Principais

### 1. Módulo IAM (`modules/iam/default.nix`)

Configura o servidor Kanidm com:
- **Servidor OAuth2/OpenID Connect** rodando em `127.0.0.1:8443` (sem TLS direto)
- **Proxy reverso via Traefik** para expor `iam.wcbrpar.com` com TLS
- **Cliente OAuth2 "traefik-dashboard"** para autenticação do dashboard
- **Grupo "traefik_dashboard_access"** para controle de acesso baseado em grupos

#### Mudanças Importantes:
- ✅ Bind em localhost apenas (segurança)
- ✅ TLS gerenciado pelo Traefik (não pelo Kanidm)
- ✅ Cliente OAuth2 confidencial (requer client secret)
- ✅ Mapeamento de grupos para autorização

### 2. Módulo Reverse Proxy (`modules/reverse-proxy/default.nix`)

Configura o Traefik com:
- **Plugin traefik-oidc-auth** v0.18.0 para autenticação OIDC
- **Middleware oidc-auth** aplicando autenticação ao dashboard
- **Validação de grupo** exigindo pertencimento ao grupo `traefik_dashboard_access`
- **Injeção de headers** com informações do usuário autenticado

#### Configuração do Middleware OIDC:
```nix
"oidc-auth" = {
  plugin = {
    "traefik-oidc-auth" = {
      SessionCookieName = "_oauth2_proxy";
      OauthStartPath = "/oauth2/start";
      OauthCallbackPath = "/oauth2/callback";
      
      Scopes = [ "openid" "profile" "email" "groups" ];
      
      Provider = {
        Url = "https://iam.wcbrpar.com/oauth2/openid/traefik-dashboard/.well-known/openid-configuration";
        ClientId = "traefik-dashboard";
        UsePkce = false; # Cliente confidencial não precisa PKCE
      };
      
      Authorization = {
        Groups = [ "traefik_dashboard_access" ];
      };
    };
  };
};
```

## Fluxo de Autenticação

1. **Acesso Inicial**: Usuário acessa `https://traefik.wcbrpar.com`
2. **Redirecionamento**: Traefik detecta ausência de sessão e redireciona para `/oauth2/start`
3. **Auth Request**: Plugin redireciona para Kanidm com parâmetros OAuth2
4. **Login**: Usuário autentica no Kanidm (via proxy Traefik em `iam.wcbrpar.com`)
5. **Callback**: Kanidm redireciona para `/oauth2/callback` com authorization code
6. **Token Exchange**: Plugin troca code por tokens (usando client secret)
7. **Validação**: Plugin valida ID token e verifica grupos do usuário
8. **Acesso Concedido**: Se usuário pertence ao grupo `traefik_dashboard_access`, acesso é liberado

## Segredos Necessários

### 1. Cloudflare API Key
```
secrets/cloudflareApiKey.age
```
Usado para emissão de certificados TLS via DNS challenge.

### 2. Kanidm Client Secret
```
secrets/kanidmTraefikSecret.age
```
Client secret do OAuth2 para o cliente `traefik-dashboard`.

**Como gerar:**
```bash
# Após provisionar o Kanidm, gere o secret:
kanidm system oauth2 show-secret traefik-dashboard -D admin

# Crie o segredo age:
echo "<client-secret>" | age -o secrets/kanidmTraefikSecret.age -R recipients.age
```

## Passos de Implementação

### Fase 1: Preparação
1. [ ] Criar arquivo de segredo `secrets/kanidmTraefikSecret.age`
2. [ ] Garantir que ambos módulos estão incluídos na configuração do sistema
3. [ ] Verificar se hostname é `galactica` (condicional dos módulos)

### Fase 2: Provisionamento Inicial
1. [ ] Aplicar configuração NixOS (`sudo nixos-rebuild switch`)
2. [ ] Aguardar Kanidm iniciar e ser provisionado
3. [ ] Extrair client secret do OAuth2
4. [ ] Criar segredo age com o client secret
5. [ ] Rebuild para injetar o segredo no Traefik

### Fase 3: Validação
1. [ ] Acessar `https://iam.wcbrpar.com` - deve mostrar login do Kanidm
2. [ ] Acessar `https://traefik.wcbrpar.com` - deve redirecionar para login
3. [ ] Logar com usuário `wjjunyor` - deve acessar dashboard
4. [ ] Verificar logs do Traefik para debug se necessário

## Troubleshooting

### Problema: Erro "Client authentication failed"
**Causa**: Client secret incorreto ou não injetado
**Solução**: 
```bash
# Verificar se segredo existe
sudo cat /run/secrets.d/kanidm-traefik-secret

# Verificar variável de ambiente no processo Traefik
sudo systemctl status traefik
```

### Problema: Redirect loop
**Causa**: Callback URL incorreta no cliente OAuth2
**Solução**: Verificar se `redirect_uris` no Kanidm corresponde a `https://traefik.wcbrpar.com/oauth2/callback`

### Problema: "Access denied - Group membership check failed"
**Causa**: Usuário não pertence ao grupo `traefik_dashboard_access`
**Solução**:
```bash
kanidm group list-members traefik_dashboard_access -D admin
kanidm group add-members traefik_dashboard_access <username> -D admin
```

### Problema: Certificado TLS não é emitido
**Causa**: API key do Cloudflare inválida ou DNS não propagado
**Solução**:
```bash
# Verificar logs do Traefik
sudo tail -f /var/log/traefik/traefik.log | grep -i acme

# Testar resolução DNS
dig iam.wcbrpar.com
dig traefik.wcbrpar.com
```

## Próximos Passos (Futuras Aplicações)

Para adicionar autenticação a outras aplicações:

1. **Criar novo cliente OAuth2 no Kanidm**:
```nix
systems = {
  oauth2 = {
    "minha-aplicacao" = {
      displayName = "Minha Aplicação";
      origin = "https://app.wcbrpar.com";
      public = false;
      redirect_uris = [ "https://app.wcbrpar.com/oauth2/callback" ];
      scope_maps = { ... };
    };
  };
};
```

2. **Adicionar middleware específico no Traefik**:
```nix
middlewares = {
  "oidc-minha-aplicacao" = {
    plugin = {
      "traefik-oidc-auth" = {
        Provider = {
          Url = "https://iam.wcbrpar.com/oauth2/openid/minha-aplicacao/.well-known/openid-configuration";
          ClientId = "minha-aplicacao";
        };
        # ... configuração específica
      };
    };
  };
};
```

3. **Aplicar middleware ao router da aplicação**:
```nix
routers = {
  minha-app = {
    rule = "Host(`app.wcbrpar.com`)";
    service = "minha-app-service";
    middlewares = [ "oidc-minha-aplicacao" ];
  };
};
```

## Referências

- [Documentação do Kanidm](https://kanidm.github.io/kanidm/stable/)
- [Plugin traefik-oidc-auth](https://github.com/sevensolutions/traefik-oidc-auth)
- [Traefik Middleware](https://doc.traefik.io/traefik/middlewares/http/overview/)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
