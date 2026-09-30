# Homologação — Desafios, Questionários e Administração

**Projeto:** LixoCerto
**Escopo:** CRUD administrativo e jornada do usuário em Desafios e Quiz/Questionários, além da gestão de usuários, papéis, permissões e auditoria
**Ambiente-alvo:** notebook Windows com Docker Compose e banco de desenvolvimento
**Versões:** use `main` nos três repositórios e confira `git log -1 --oneline` em cada um após o pull. A API inclui o seeder separado de contas de homologação descrito em `docs/CONTAS_HOMOLOGACAO.md`.

## 1. Objetivo e limites

Validar, de ponta a ponta, que perfis autorizados conseguem criar, editar, publicar e arquivar desafios e questões; que usuários comuns conseguem participar/responder; que as regras de pontuação e preservação do histórico são respeitadas; e que o conteúdo administrativo não vaza para as consultas públicas.

**Não executar em produção.** Os cenários de criação deixam registros e eventos de auditoria no banco. Use títulos com prefixo `[HML]`; arquive os registros ao terminar em vez de apagá-los, para manter o histórico consistente.

Este roteiro não lê, altera nem pede para compartilhar `.env`, senhas ou tokens. Se uma etapa falhar por conexão/SSL, interrompa e diagnostique a configuração sem desabilitar TLS.

## 2. Bloqueio conhecido da automação

O script `infra_lixocerto/scripts/iniciar.ps1` chama `pnpm smoke:grpc`, `pnpm smoke:grpc:reflection` e, opcionalmente, `pnpm smoke:grpc:auth`. **Esses scripts não estão declarados no `api_lixocerto/package.json` nem há runner correspondente no repositório da API.** Portanto, não use `-SmokeTests` nem `-SmokeAutenticado` nesta versão: essa verificação automatizada está bloqueada. A homologação funcional abaixo é manual pela interface. A API já possui testes unitários, mas isso não substitui o teste no notebook.

## 3. Pré-requisitos

- Os três repositórios locais estão em `main`, sem alterações locais que precisem ser preservadas antes do pull.
- `.env` da API aponta para o **banco de desenvolvimento correto**; não imprimir nem compartilhar seu conteúdo.
- A API e o Sequelize CLI usam `BANCO_DADOS_SSL` de forma consistente: `true` ativa TLS com validação de certificado; ausente ou diferente de `true` não ativa TLS. Use o valor exigido pelo provedor/endpoint do banco; não desligue TLS em banco remoto que o exige.
- Contas de homologação: execute o seeder isolado `pnpm semear:homologacao` documentado em `api_lixocerto/docs/CONTAS_HOMOLOGACAO.md` para criar usuário, pesquisador e revisor; o seeder preserva as contas administrativas existentes.
- Redis, PostgreSQL, Docker Desktop e dependências da aplicação disponíveis.
- Acesso à interface em `http://localhost:3000`.

## 4. Atualizar código e validar versões

No PowerShell:

```powershell
Set-Location G:\LixoCerto

git -C .\api_lixocerto status --short
git -C .\frontend_lixocerto status --short
git -C .\infra_lixocerto status --short
```

Se algum repositório mostrar alterações locais, **pare antes do pull** e preserve-as. Não use `reset --hard`, `clean -fd` ou descarte alterações para fazer esta atualização.

```powershell
git -C .\api_lixocerto switch main
git -C .\api_lixocerto pull --ff-only origin main
git -C .\frontend_lixocerto switch main
git -C .\frontend_lixocerto pull --ff-only origin main
git -C .\infra_lixocerto switch main
git -C .\infra_lixocerto pull --ff-only origin main

git -C .\api_lixocerto log -1 --oneline
git -C .\frontend_lixocerto log -1 --oneline
```

Confirme que a API mostra o commit `0df2c37` e o frontend `4a98ea4`; a infraestrutura também deve estar atualizada na `main`. Se o `pull --ff-only` parar por divergência, não force; interrompa e investigue a branch local.

## 5. Build, migrations e subida seletiva

As migrations `029_adicionar_permissao_administrar_desafios`, `030_conceder_resposta_questionario_revisor` e `031_adicionar_permissao_gerenciar_acessos` devem estar aplicadas. Em bancos existentes, confira o status e aplique somente as pendentes. Depois, execute **apenas** o seed idempotente `001_inserir_papeis_permissoes.cjs` para acrescentar `gamificacao:participar` às relações-base; ele não apaga dados. **Não rode `db:seed:all`** para atualizar a matriz. A migration 031 alterada também permite instalação nova antes dos seeds. Os comandos abaixo fixam o entrypoint e chamam diretamente o Sequelize CLI. A configuração respeita `BANCO_DADOS_SSL` tal como a API e mantém `rejectUnauthorized: true` quando TLS está habilitado.

```powershell
Set-Location G:\LixoCerto\infra_lixocerto

# Rebuild sem cache somente das imagens de API e frontend
docker compose -f compose.yml --profile app build --no-cache api frontend

# Verificar o estado das migrations no banco configurado no .env da API
docker compose -f compose.yml --profile app run --rm --no-deps api `
  --entrypoint node api node_modules/sequelize-cli/lib/sequelize db:migrate:status `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Aplicar apenas migrations pendentes
docker compose -f compose.yml --profile app run --rm --no-deps api `
  --entrypoint node api node_modules/sequelize-cli/lib/sequelize db:migrate `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Repetir status; 029, 030 e 031 devem constar como aplicadas
docker compose -f compose.yml --profile app run --rm --no-deps api `
  --entrypoint node api node_modules/sequelize-cli/lib/sequelize db:migrate:status `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Atualizar somente a matriz RBAC base; não executar db:seed:all
docker compose -f compose.yml --profile app run --rm --no-deps api `
  --entrypoint node api node_modules/sequelize-cli/lib/sequelize db:seed `
    --seed 001_inserir_papeis_permissoes.cjs `
    --config configuracao_sequelize.cjs `
    --seeders-path banco/dados_iniciais

# Recriar apenas os serviços atualizados; dependências existentes permanecem ativas
docker compose -f compose.yml --profile app up -d --no-deps --force-recreate api frontend

docker compose -f compose.yml --profile app ps
curl.exe -I http://localhost:3000/
```

**Aceite operacional:** API `healthy`, frontend `healthy` e `http://localhost:3000/` responde `200 OK`. Se alguma migration falhar, não tente `undo` nem rode seeds em massa; preserve a saída do erro sem incluir valores de ambiente e interrompa a homologação.

## 6. Perfis e permissões esperadas

| Perfil | O que deve conseguir fazer |
|---|---|
| `administrador` | Acesso completo, incluindo gestão de acessos, papéis, permissões e auditoria; matriz protegida no backend. |
| `revisor` | Criar/aprovar materiais e pontos; gerir e responder quiz; gerir desafios sem participar; sem administração de acessos ou auditoria. |
| `usuario` | Ler guia/pontos, responder quiz publicado, ler gamificação, participar de desafios e enviar SUS; sem controles de gestão nem resultados agregados. |
| `pesquisador` | Ler guia/pontos e seu progresso; consultar somente resultados SUS agregados; sem quiz, participação em desafios, gestão ou auditoria. |

Uma área sem permissão não deve aparecer no menu e a navegação direta deve voltar à Visão geral. Ocultar um botão não basta para comprovar segurança: endpoints também precisam rejeitar a chamada na API. Não compartilhe JWTs ou capturas que os exponham. Após atualizar o seed, saia e entre novamente para renovar as permissões da sessão.

## 7. Casos de aceite funcionais

Use títulos inequívocos como `[HML] Questão fluxo completo 2026-09-29` e `[HML] Desafio fluxo completo 2026-09-29`.

### QST-01 — Criar, localizar e editar rascunho

**Perfil:** revisor ou administrador.
**Passos:** abrir **Quiz e questionários → Gerenciar questões**; criar questão com enunciado, explicação, pontuação e 2–6 alternativas distintas; marcar exatamente uma correta; salvar; localizar pelo filtro de busca/status; editar e salvar.
**Esperado:** registro criado como `rascunho`, aparece na gestão, busca/status funcionam e alterações persistem após recarregar a página. Não aparece no quiz público enquanto rascunho.

### QST-02 — Validação do gabarito

**Perfil:** revisor ou administrador.
**Passos:** tentar deixar texto de alternativa vazio; repetir alternativas; testar 1 alternativa e, quando possível por cliente gRPC de teste, 0 ou 2 respostas corretas.
**Esperado:** UI impede envios incompletos; API rejeita payloads inválidos. Uma questão só pode ser publicada com 2–6 alternativas válidas, sem duplicatas e exatamente uma correta.

### QST-03 — Publicação e privacidade do quiz

**Perfil:** revisor/admin publica; usuário comum consulta.
**Passos:** publicar a questão; entrar com usuário comum em **Quiz e questionários**; conferir questão e alternativas antes de responder; responder uma vez incorretamente e testar uma questão/conta com resposta correta.
**Esperado:** só questões `publicada` são exibidas; antes da resposta não aparecem alternativa correta nem explicação; resposta errada rende 0 ponto e feedback; acerto mostra explicação e pontuação configurada. A resposta pública `ListarQuestoes` não deve incluir campos `indica_correta` nem `explicacao_questao`.

### QST-04 — Recompensa única e preservação de versão

**Perfil:** usuário comum responde; revisor/admin gerencia.
**Passos:** após um acerto recompensado, tentar enviar novamente a mesma resposta para a mesma questão com a mesma conta (por nova sessão/cliente de teste); editar uma questão já publicada ou com tentativas; consultar gestão e quiz.
**Esperado:** a segunda tentativa correta não concede pontos novamente; editar questão publicada/respondida cria nova versão em rascunho e preserva a versão anterior/histórico; arquivar remove a questão do quiz público sem apagar tentativas.

### QST-05 — Arquivar e restaurar questão

**Perfil:** revisor ou administrador.
**Passos:** arquivar uma questão de teste e conferir o quiz; se disponível na interface, restaurar para rascunho e publicar novamente.
**Esperado:** questão arquivada deixa de ser servida ao público; restauração não a publica automaticamente.

### DES-01 — Criar e editar desafio em rascunho

**Perfil:** revisor ou administrador.
**Passos:** abrir **Desafios → Gerenciar**; criar desafio com nome/descrição `[HML]`, tipo de ação em minúsculas com `_` (por exemplo `separacao_residuos`), meta `2`, recompensa `40`, início atual e fim futuro; salvar; pesquisar/filtrar; editar e salvar.
**Esperado:** desafio nasce `rascunho`, datas e campos persistem, e só perfis autorizados veem gestão.

### DES-02 — Publicação, participação e progresso

**Perfil:** revisor/admin publica; usuário comum participa.
**Passos:** publicar; entrar como usuário comum; participar; registrar duas ações do tipo definido no desafio.
**Esperado:** desafio publicado e dentro da janela aparece ao cidadão; a primeira ação deixa progresso `1/2` sem recompensa; a segunda conclui em `2/2` e concede os pontos configurados uma única vez.

### DES-03 — Bloqueios e histórico

**Perfil:** usuário comum e revisor/admin.
**Passos:** tentar registrar ação sem participar, com outro tipo, após a data final ou após conclusão; tentar editar desafio que já tenha participação/ação; arquivar desafio com histórico.
**Esperado:** ações inválidas não pontuam; após conclusão não há nova recompensa; edição com histórico é recusada, orientando arquivar e criar outro; arquivamento preserva participações/ações e tira o desafio da lista pública.

### AUTH-01 — Separação de papéis

**Perfis:** administrador/revisor e usuário comum.
**Passos:** entrar em cada perfil e conferir abas/controles. Para validar proteção de backend, tentar chamar um RPC de gestão com a sessão de usuário comum em um cliente de teste, sem alterar conteúdo.
**Esperado:** usuário comum não vê **Gerenciar** e a chamada direta recebe erro de autorização; revisor/admin pode listar e operar a gestão de desafios/questionários. Confirmar que as migrations 029, 030 e 031 estão aplicadas.

### AUTH-02 — Áreas visíveis para cada perfil-base

**Perfis:** uma conta de cada papel — `usuario`, `pesquisador`, `revisor` e `administrador`.
**Passos:** sair e entrar separadamente com cada conta; comparar o menu com a matriz em `api_lixocerto/docs/CONTAS_HOMOLOGACAO.md`; tentar abrir pela navegação direta uma área que não consta para aquele perfil. Para o pesquisador, conferir que não existe aba de participação em desafios; para o usuário, confirmar que Pesquisa mostra o formulário, mas não os resultados agregados.
**Esperado:** aparecem somente áreas autorizadas; navegação direta sem permissão retorna à Visão geral; a API não carrega os dados da área negada. Pesquisador vê apenas agregados SUS, revisor vê gestão de desafios/questionários, e apenas o administrador vê governança/auditoria.

### AUTH-03 — Leitura e participação em desafios

**Perfis:** pesquisador, usuário e revisor.
**Passos:** usar uma sessão de pesquisador para tentar `ParticiparDesafio` e `RegistrarAcaoSustentavel` em um cliente gRPC de teste; em seguida, usar usuário para participar e registrar ação; no revisor, abrir gestão sem mostrar controles de participação.
**Esperado:** `gamificacao:ler` isolada não autoriza mutações; API exige `gamificacao:participar` além da leitura; usuário consegue participar, pesquisador não vê a área e revisor fica somente na gestão.

### ADM-01 — Criar e editar papel personalizado

**Perfil:** administrador.
**Passos:** em **Administração da plataforma → Papéis e permissões**, criar um papel de teste com identificador minúsculo em `snake_case`, descrição, algumas permissões ativas não exclusivas e justificativa; editar a descrição e a matriz; conferir filtros/estado. Não atribuir o papel a usuários de produção.
**Esperado:** papel criado ativo, matriz salva conforme seleção e alterações ficam registradas na auditoria; papéis com usuários não podem ser arquivados até que sejam reatribuídos.

### ADM-02 — Papel administrador protegido e permissão exclusiva

**Perfil:** administrador; teste negativo autorizado em cliente de API somente com conta de desenvolvimento.
**Passos:** abrir o papel `administrador` e tentar salvar uma alteração; tentar renomear/criar outro papel com nome reservado; em um papel personalizado, tentar conceder a permissão `administracao:gerenciar_acessos`; verificar também a restrição de arquivamento dos papéis base.
**Esperado:** matriz do administrador não pode ser alterada; nomes base não podem ser duplicados/renomeados; permissão exclusiva não pode ser atribuída a papel não administrador; papéis base não podem ser arquivados. A API deve rejeitar chamadas diretas inválidas mesmo que a interface seja contornada.

### ADM-03 — Usuários, bloqueio e proteção do último administrador

**Perfil:** administrador, usando contas secundárias de teste.
**Passos:** pesquisar e paginar usuários; ajustar os papéis de uma conta secundária; bloquear e reativar essa conta com justificativa; em base descartável ou com outro administrador ativo confirmado, testar a tentativa de bloquear/rebaixar o último administrador; tentar alterar o próprio status e os próprios papéis.
**Esperado:** filtros e paginação são consistentes; papéis aplicados persistem e as sessões associadas são revogadas; bloqueio encerra sessões; a própria conta não pode alterar o próprio acesso; o sistema impede deixar a plataforma sem administrador ativo. Não testar remoção do último administrador na conta real.

### ADM-04 — Revogação de sessões

**Perfil:** administrador e usuário de teste em duas sessões distintas.
**Passos:** iniciar sessão na conta secundária; revogar as sessões pela linha do usuário; tentar usar novamente a sessão secundária e entrar de novo, se a conta continuar ativa.
**Esperado:** a interface informa quantas sessões foram revogadas; a sessão antiga é recusada e a conta ativa pode autenticar novamente. Não registrar tokens nem cabeçalhos de autorização nas evidências.

### ADM-05 — Resumo e trilha de auditoria

**Perfil:** administrador.
**Passos:** conferir as métricas do resumo; abrir **Auditoria**, filtrar por tipo de evento e navegar entre páginas; executar uma mudança administrativa de teste e localizar o evento correspondente. Não inserir valores reais de segredos como dado de teste.
**Esperado:** totais são coerentes com a base; filtro e paginação mantêm ordem/contagem; eventos incluem ator, tipo, recurso e justificativa sem expor chaves com nomes como token, senha, segredo, credencial ou API key, que devem aparecer redigidas.

### OPS-01 — Reinício e persistência

**Passos:** depois dos testes, reiniciar somente API e frontend, sem apagar volumes (`docker compose ... restart api frontend`), entrar novamente e conferir registros de teste e status.
**Esperado:** conteúdo e resultados permanecem; serviço volta saudável. **Não** usar `down -v`, apagar volume, limpar banco ou executar migrations down.

## 8. Registro de execução

Preencha durante o teste; não inclua senhas, tokens, cookies ou `.env`.

| Caso | Resultado (PASS/FAIL/BLOCKED) | Evidência sem segredo | Observação/ID do defeito |
|---|---|---|---|
| PRE-01 — versões e saúde |  |  |  |
| QST-01 — CRUD de rascunho |  |  |  |
| QST-02 — validação |  |  |  |
| QST-03 — publicação/privacidade |  |  |  |
| QST-04 — recompensa/histórico |  |  |  |
| QST-05 — arquivamento/restauração |  |  |  |
| DES-01 — CRUD de rascunho |  |  |  |
| DES-02 — participação/pontuação |  |  |  |
| DES-03 — bloqueios/histórico |  |  |  |
| AUTH-01 — permissões |  |  |  |
| AUTH-02 — visibilidade por perfil |  |  |  |
| AUTH-03 — participação em desafios |  |  |  |
| ADM-01 — CRUD de papéis |  |  |  |
| ADM-02 — administrador protegido |  |  |  |
| ADM-03 — usuários/último administrador |  |  |  |
| ADM-04 — revogação de sessões |  |  |  |
| ADM-05 — resumo/auditoria |  |  |  |
| OPS-01 — persistência |  |  |  |

Anexe apenas capturas sem credenciais e saídas sanitizadas de `docker compose ps`. Para erro de API, registre horário, caso de teste e mensagem sem copiar cabeçalhos de autorização.

## 9. Critério de conclusão

A fase fica **homologada** quando os casos críticos (PRE-01, QST-01/03/04, DES-01/02/03, AUTH-01/02/03, ADM-01/02/03/04/05 e OPS-01) passarem, migrations 029/030/031 estiverem aplicadas, o seed de permissões tiver sido reaplicado para frente e API/frontend permanecerem saudáveis após reinício. Falhas bloqueantes devem ser corrigidas antes de iniciar um piloto com participantes reais.
