import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const [arquivoEntrada, arquivoSaida] = process.argv.slice(2);
if (!arquivoEntrada || !arquivoSaida) {
  throw new Error('Uso: node tools/gerar-catalogo-postman.mjs <colecao-legada> <catalogo-saida>');
}

const colecao = JSON.parse(await readFile(resolve(arquivoEntrada), 'utf8'));
const metodos = [];

function visitarItens(itens, servico = null) {
  for (const item of itens ?? []) {
    if (Array.isArray(item.item)) {
      visitarItens(item.item, item.name);
      continue;
    }

    const requisicao = item.request;
    const url = requisicao?.url?.raw;
    if (!url || !url.startsWith('grpc://')) continue;

    const partes = url.replace(/^grpc:\/\//, '').split('/');
    const nomeServico = partes.at(-2);
    const nomeMetodo = partes.at(-1);
    const metadados = (requisicao.header ?? [])
      .filter(cabecalho => !cabecalho.disabled && cabecalho.key !== 'Content-Type')
      .map(cabecalho => ({ nome: cabecalho.key, valor: cabecalho.value }));

    metodos.push({
      ordem: metodos.length + 1,
      grupo: servico,
      servico: nomeServico,
      metodo: nomeMetodo,
      caminhoRpc: `/${nomeServico}/${nomeMetodo}`,
      url: 'grpc://{{grpc_host}}',
      mensagem: JSON.parse(requisicao.body?.raw ?? '{}'),
      metadados,
      autenticacao: metadados.some(item => item.nome.toLowerCase() === 'authorization') ? 'Bearer JWT' : 'Nenhuma',
      instrucoes: 'Criar como requisição New > gRPC e salvar em uma coleção nativa; não importar este catálogo como collection JSON.',
    });
  }
}

visitarItens(colecao.item);

const documento = {
  tipo: 'catalogo-de-configuracao-postman-grpc-nativo',
  versao: 1,
  importavelComoCollectionJson: false,
  motivo: 'O Postman não expõe no formato Collection v2.1 um schema público e confiável para serializar requests gRPC nativos.',
  fonte: 'Lixo-Certo-API.legado-http.postman_collection.json',
  endpoint: 'grpc://{{grpc_host}}',
  definicaoServico: 'Lixo-Certo-API.postman.proto',
  quantidadeMetodos: metodos.length,
  metodos,
};

await writeFile(resolve(arquivoSaida), `${JSON.stringify(documento, null, 2)}\n`, 'utf8');
console.log(`Catálogo Postman gRPC: ${metodos.length} métodos`);
