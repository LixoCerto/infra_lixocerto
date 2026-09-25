# Referências Postman — gRPC nativo

## Decisão técnica

O cliente Postman possui uma interface gRPC própria. Uma requisição nativa é criada por **New > gRPC**, recebe uma URL `grpc://`, uma definição de serviço e um método selecionado; depois pode ser salva em uma coleção pelo comando **Save As**. Quando a chamada é unary, a ação de execução aparece como **Invoke**. Um item Collection JSON v2.1 com `method: POST`, mesmo que contenha uma URL `grpc://`, é tratado como uma requisição HTTP genérica e não é uma representação confiável da interface gRPC.

O repositório, portanto, não chama o arquivo HTTP histórico de “coleção gRPC”. Ele o mantém em `api_lixo_certo/docs/postman/legado/` apenas para auditoria, não o copia para o diretório de trabalho do Postman e entrega um catálogo explicitamente marcado como `importavelComoCollectionJson: false`. A preparação automatiza os contratos, a definição raiz, o ambiente, a descoberta por server reflection e os 22 payloads/metadados. O salvamento da coleção nativa é feito pelo cliente Postman, que é o componente que conhece o modelo interno dessa requisição.

## Fontes oficiais

A documentação [The gRPC client interface](https://learning.postman.com/docs/use/send-requests/protocols/grpc/grpc-request-interface) descreve a criação de uma nova requisição gRPC, a URL `grpc://`, a seleção de método, a ação **Save As**, o botão **Invoke** e a impossibilidade de trocar o protocolo depois que uma requisição é salva.

A documentação [Manage service definitions for gRPC requests](https://learning.postman.com/docs/use/send-requests/protocols/grpc/using-service-definition) confirma duas formas de carregar o contrato: server reflection ou uma API Protobuf. Também confirma o suporte a esquemas Protobuf com múltiplos arquivos e o diretório de trabalho do Postman (`%USERPROFILE%\\Postman\\files` no Windows).

A documentação [Save, edit, and share gRPC request-response examples](https://learning.postman.com/docs/use/send-requests/protocols/grpc/using-grpc-examples) confirma que requisições gRPC podem ser salvas em coleções pelo cliente Postman e que exemplos dependem de uma requisição gRPC já pertencente a uma coleção.

A [issue oficial #13181](https://github.com/postmanlabs/postman-app-support/issues/13181) registra casos em que a exportação de dados do Postman omite coleções que contêm requisições gRPC. A [issue oficial #11252](https://github.com/postmanlabs/postman-app-support/issues/11252) registra a solicitação de exportação de coleções com WebSocket e gRPC. A [issue oficial #11590](https://github.com/postmanlabs/postman-app-support/issues/11590) registra a solicitação de gerar automaticamente uma coleção com uma requisição por método a partir de uma API Protobuf; essa é exatamente a automação que seria necessária para uma importação completa e não deve ser simulada por itens HTTP.

O artigo [Latest advancements to Postman’s gRPC support](https://blog.postman.com/latest-advancements-to-postmans-grpc-support/) descreve o salvamento de requisições gRPC em coleções, o compartilhamento por workspace e link, e a detecção automática de contratos quando server reflection está habilitado.
