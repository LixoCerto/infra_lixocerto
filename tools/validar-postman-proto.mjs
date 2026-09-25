import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { loadSync } from '@grpc/proto-loader';

const arquivo = resolve(process.argv[2] ?? '../api-lixo-certo/docs/postman/Lixo-Certo-API.postman.proto');
const raizContratos = resolve(dirname(arquivo), '..', '..', 'contratos');

if (!existsSync(arquivo)) {
  throw new Error(`Definição Postman não encontrada: ${arquivo}`);
}

const definicao = loadSync(arquivo, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
  includeDirs: [resolve(raizContratos, '..')],
});

const simbolos = Object.keys(definicao);
const servicos = simbolos.filter(nome => /^lixo_certo\.v1\.Servico[A-Z]/.test(nome));
if (servicos.length !== 13) {
  throw new Error(`A definição raiz deveria expor 13 serviços; encontrados: ${servicos.length}`);
}

console.log(`Definição Protobuf Postman válida: ${servicos.length} serviços, ${simbolos.length} símbolos`);
