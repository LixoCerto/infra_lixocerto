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

Confirme com `git log -1 --oneline` que os três clones estão na versão esperada da `main` e sem alterações locais pendentes. Não fixe SHAs antigos neste roteiro: registre os SHAs efetivamente obtidos após o pull. Se o `pull --ff-only` parar por divergência, não force; interrompa e investigue a branch local.

## 5. Build, migrations e subida seletiva

As migrations `029_adicionar_permissao_administrar_desafios`, `030_conceder_resposta_questionario_revisor`, `031_adicionar_permissao_gerenciar_acessos`, `032_adicionar_dados_atendimento_pontos_coleta` e `033_engajamento_quizzes_selos_desafios` devem estar aplicadas. Em bancos existentes, confira o status e aplique somente as pendentes. Depois, execute **apenas** os seeders idempotentes indicados abaixo; eles não apagam dados. **Não rode `db:seed:all`**. A migration 033 adiciona o agendamento de quizzes individuais, ledger de pontos, selos, registro validável de descarte e ciclos/critério de desafios. Os comandos abaixo fixam o entrypoint e chamam diretamente o Sequelize CLI. A configuração respeita `BANCO_DADOS_SSL` tal como a API e mantém `rejectUnauthorized: true` quando TLS está habilitado.

```powershell
Set-Location G:\LixoCerto\infra_lixocerto

# Rebuild sem cache somente das imagens de API e frontend
docker compose -f compose.yml --profile app build --no-cache api frontend

# Verificar o estado das migrations no banco configurado no .env da API
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:migrate:status `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Aplicar apenas migrations pendentes
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:migrate `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Repetir status; migrations 029 a 033 devem constar como aplicadas
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:migrate:status `
  --config configuracao_sequelize.cjs `
  --migrations-path banco/migracoes

# Atualizar somente a matriz RBAC base; não executar db:seed:all
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:seed `
    --seed 001_inserir_papeis_permissoes.cjs `
    --config configuracao_sequelize.cjs `
    --seeders-path banco/dados_iniciais

# Instalar a leva inicial de quizzes publicados (seis temas); idempotente
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:seed `
    --seed 004_inserir_quiz_ambiental_inicial.cjs `
    --config configuracao_sequelize.cjs `
    --seeders-path banco/dados_iniciais

# Instalar desafios diário, semanal e mensal; idempotente
docker compose -f compose.yml --profile app run --rm --no-deps --entrypoint node api `
  node_modules/sequelize-cli/lib/sequelize db:seed `
    --seed 005_inserir_desafios_recorrentes.cjs `
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
| `usuario` | Ler guia/pontos, responder quiz publicado, ler gamificação, participar de desafios e enviar avaliação de usabilidade; sem controles de gestão nem resultados agregados. |
| `pesquisador` | Ler guia/pontos e seu progresso; consultar somente resultados agregados da avaliação de usabilidade; sem quiz, participação em desafios, gestão ou auditoria. |

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
**Esperado:** usuário comum não vê **Gerenciar** e a chamada direta recebe erro de autorização; revisor/admin pode listar e operar a gestão de desafios/questionários. Confirmar que as migrations 029, 030, 031 e 032 estão aplicadas.

### AUTH-02 — Áreas visíveis para cada perfil-base

**Perfis:** uma conta de cada papel — `usuario`, `pesquisador`, `revisor` e `administrador`.
**Passos:** sair e entrar separadamente com cada conta; comparar o menu com a matriz em `api_lixocerto/docs/CONTAS_HOMOLOGACAO.md`; tentar abrir pela navegação direta uma área que não consta para aquele perfil. Para o pesquisador, conferir que não existe aba de participação em desafios; para o usuário, confirmar que Pesquisa mostra o formulário, mas não os resultados agregados.
**Esperado:** aparecem somente áreas autorizadas; navegação direta sem permissão retorna à Visão geral; a API não carrega os dados da área negada. Pesquisador vê apenas resultados agregados da avaliação de usabilidade, revisor vê gestão de desafios/questionários, e apenas o administrador vê governança/auditoria. Confirme também que a migration 033 está aplicada antes de testar quiz, pontos e selos.

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
| GAM-01 — quiz único e recompensa |  |  |  |
| GAM-02 — desafios por ciclo |  |  |  |
| GAM-03 — selos e origem dos pontos |  |  |  |
| GAM-04 — validação de descarte |  |  |  |

Anexe apenas capturas sem credenciais e saídas sanitizadas de `docker compose ps`. Para erro de API, registre horário, caso de teste e mensagem sem copiar cabeçalhos de autorização.

## 9. Critério de conclusão

A fase fica **homologada** quando os casos críticos (PRE-01, QST-01/03/04, DES-01/02/03, AUTH-01/02/03, ADM-01/02/03/04/05 e OPS-01) passarem, migrations 029–033 estiverem aplicadas, os seeders seletivos necessários tiverem sido executados e API/frontend permanecerem saudáveis após reinício. Os novos fluxos de recompensa precisam ser validados também pelos casos GAM-01 a GAM-04 ao fim deste roteiro. Falhas bloqueantes devem ser corrigidas antes de iniciar um piloto com participantes reais.


## 10. Melhorias de orientação e operação local

A versão atual inclui as migrations `032_adicionar_dados_atendimento_pontos_coleta.cjs` (horário, telefone e URL informativa opcionais) e `033_engajamento_quizzes_selos_desafios.cjs` (atribuições únicas de quiz, ledger de pontos, selos, descartes revisáveis e desafios por ciclo), além de atualizar os contratos protobuf. Antes do uso, consulte o estado das migrations e aplique somente pendências pelo procedimento PowerShell acima. A API valida links HTTP(S), limites de tamanho e formato do telefone; informações opcionais não confirmadas devem ficar vazias. O status verificado exibe a data registrada pela API.

O Guia de descarte é consulta a conteúdos publicados; a Central de revisão continua sendo o fluxo separado para editar e aprovar. O seeder `002_preparar_leva_inicial_guia.cjs` só prepara cinco registros como rascunhos, exige `AMBIENTE_EXECUCAO=desenvolvimento` e `LCR_PREPARAR_LEVA_GUIA_INICIAL=true` e nunca publica. A atualização reconhece o lote curado anterior somente pelo marcador/versionamento exatos e recusa registros publicados/editados fora do estado previsto. A aprovação continua individual, autenticada e auditada pela interface.

Para backups e privacidade, consulte `api_lixocerto/docs/OPERACAO_PRIVACIDADE_E_BACKUP.md`. O Compose deste projeto não inclui PostgreSQL; o volume Redis não é backup do banco. O dump/restore é manual, deve ser protegido e restaurado somente em base descartável. A geolocalização exige ação explícita, serve à busca por proximidade e não é guardada como perfil pela aplicação. Não compartilhe `.env`, tokens, dumps ou dados pessoais em anexos/logs.

## 11. Gamificação, quiz aleatório e ciclos de desafios

### Carga inicial e operação

Depois de aplicar a migration 033 e criar as tabelas, execute seletivamente os seeders `004_inserir_quiz_ambiental_inicial.cjs` (seis questões em temas variados, explicações com referências) e `005_inserir_desafios_recorrentes.cjs` (missões diária, semanal e mensal). Os comandos PowerShell estão na seção 5; ambos são idempotentes. **Não execute `db:seed:all`**. A proveniência editorial das questões está em `api_lixocerto/docs/REFERENCIAS_QUIZ_AMBIENTAL.md`.

### Regras funcionais esperadas

- Cada participante recebe no máximo uma questão ativa. A primeira e as seguintes são agendadas em intervalos aleatórios de 24–72 horas; a questão expira em 48 horas, e o tema tenta alternar em relação ao quiz anterior. A pontuação por acerto é sorteada entre 10 e o limite configurado (máximo 50). O gabarito fica oculto; após qualquer resposta registrada a questão sai da lista e a API bloqueia nova tentativa. Se a página do quiz estiver aberta, ela atualiza as atribuições a cada minuto.
- O sorteio atua dentro da aplicação/API — não envia e-mail, SMS ou push externo. O usuário vê a questão ao abrir ou manter aberta a tela **Quiz ambiental**.
- Desafios diários, semanais (semana ISO) e mensais usam o calendário `America/Sao_Paulo`. A participação é iniciada pelo usuário uma vez por desafio/ciclo; após completar, a missão deixa de aparecer para aquele ciclo e pode ser iniciada novamente no ciclo seguinte.
- Os critérios podem contar respostas corretas de quiz (opcionalmente por tema), descartes validados de uma categoria específica ou quantas categorias distintas foram descartadas. Somente eventos ocorridos durante o ciclo e após a participação contam. Os bônus de conclusão e pontos de quiz/descarte são idempotentes.
- Um descarte precisa apontar para ponto verificado e categoria aceita. O registro fica pendente; o revisor não pode aprovar o próprio envio e a pontuação (20 pontos) só entra após aprovação. A API limita a 10 registros por 24 horas e bloqueia repetição da mesma categoria no mesmo ponto nesse intervalo.
- Selos automáticos por pontos totais: **Broto consciente** (100), **Separador atento** (250), **Guardião circular** (500), **Agente transformador** (1.500) e **Embaixador LixoCerto** (4.000). Pontos legados continuam no total e podem desbloquear selos; o detalhamento por origem registra as recompensas validadas após a migration 033.

### GAM-01 — Resposta única e recompensa

**Perfil:** usuário comum.
**Passos:** abrir Quiz ambiental, conferir que há somente uma questão; responder corretamente e verificar os pontos sorteados e a explicação; tentar repetir a mesma questão via sessão/cliente autorizado de teste; quando houver outra atribuição futura, verificar se a nova questão não foi apresentada antes.
**Esperado:** uma única tentativa por questão para sempre; pontos uma única vez e na mesma transação da resposta; questão removida imediatamente após resposta; novos quizzes têm horário, tema e prêmio aleatórios, sem mais de uma questão ativa por usuário.

### GAM-02 — Desafio diário, semanal e mensal

**Perfil:** usuário comum.
**Passos:** participar de cada desafio inicial; obter um quiz correto e/ou enviar descartes em pontos verificados de categorias aceitas; aguardar revisão para descarte; acompanhar progresso e conclusão.
**Esperado:** ciclos e metas aparecem claramente; progresso de quiz conta após acerto e de descarte somente após aprovação; categorias distintas não contam duas vezes a mesma categoria; conclusão credita o bônus uma única vez e a missão não pode ser repetida no mesmo ciclo.

### GAM-03 — Selos e origem dos pontos

**Perfil:** usuário comum.
**Passos:** consultar o painel de gamificação antes e depois de uma recompensa; validar selo bloqueado/conquistado e o resumo por descarte, quiz e desafio.
**Esperado:** selo é concedido na primeira leitura/recompensa quando o total alcança o limiar, sem duplicação; o painel distingue o histórico legado do ledger detalhado iniciado na migration 033.

### GAM-04 — Validação do descarte

**Perfis:** usuário comum e revisor.
**Passos:** enviar descarte em ponto verificado e categoria aceita; tentar enviar a mesma categoria no mesmo ponto dentro de 24 horas; revisar como revisor (inclusive testar autoaprovação em ambiente de teste); aprovar outro registro e inspecionar pontos e desafio.
**Esperado:** repetição e autoaprovação são recusadas; o envio pendente não concede pontos; a aprovação válida concede 20 pontos uma única vez e atualiza o progresso de desafios relacionado.
