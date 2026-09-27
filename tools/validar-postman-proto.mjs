import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadSync } from '@grpc/proto-loader';

const raizInfra = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const argumento = process.argv.slice(2).find((valor) => valor !== '--');
const arquivo = resolve(
  argumento ?? resolve(raizInfra, '../api_lixocerto/docs/postman/Lixo-Certo-API.postman.proto'),
);
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
