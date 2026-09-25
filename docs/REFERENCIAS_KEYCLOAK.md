# Referências Keycloak — desenvolvimento local

## Decisão técnica

O ambiente local usa o container oficial do Keycloak em modo `start-dev` somente para desenvolvimento. O realm `lixo-certo` é importado na inicialização pelo diretório `/opt/keycloak/data/import` e pela opção `--import-realm`. O acesso publicado fica restrito a `127.0.0.1:8081`.

O frontend usa Authorization Code com PKCE. O Postman usa um cliente público separado com Direct Access Grants apenas para obter um token de desenvolvimento sem colocar senha na linha de comando. Em produção, esse cliente e o modo `start-dev` não devem ser usados.

O realm local habilita autorregistro, confirmação de e-mail e recuperação de senha. O Keycloak entrega esses fluxos em suas telas hospedadas; o React só inicia uma requisição OIDC com PKCE e recebe a resposta em `/callback`. Mailpit fornece SMTP e caixa de inspeção exclusivamente locais, sem entrega externa.

O login social Google é configurado por script somente com Client ID e Client Secret reais fornecidos no computador local. O Client Secret não é gravado em `.env`, não é incluído em `VITE_*` e não é versionado. A URI de retorno que o Google deve autorizar é a do broker do Keycloak: `http://localhost:8081/realms/lixo-certo/broker/google/endpoint` no desenvolvimento local.

No Compose local, o issuer permanece `http://localhost:8081/realms/lixo-certo` para o navegador e para os tokens. O Keycloak usa backchannel dinâmico para que a API consulte o JWKS por `http://keycloak:8080`, sem trocar o issuer público nem expor a rede interna.

A API valida `iss`, `aud`, assinatura e expiração do access token usando o endpoint JWKS interno do serviço Keycloak. Os papéis realm `usuario`, `pesquisador`, `revisor` e `administrador` são filtrados pela API antes de serem sincronizados nas tabelas LCR.

## Fontes oficiais

[1]: https://www.keycloak.org/server/containers "Keycloak — Running Keycloak in a container"
[2]: https://www.keycloak.org/server/importExport "Keycloak — Importing and exporting realms"
[3]: https://www.keycloak.org/securing-apps/oidc-layers "Keycloak — OpenID Connect layers"
[4]: https://www.keycloak.org/securing-apps/javascript-adapter "Keycloak — JavaScript adapter"
[5]: https://www.keycloak.org/docs/latest/server_admin/ "Keycloak — Server Administration Guide"
[6]: https://developers.google.com/identity/openid-connect/openid-connect "Google Identity — OpenID Connect"
[7]: https://mailpit.axllent.org/docs/install/docker/ "Mailpit — Docker installation"
