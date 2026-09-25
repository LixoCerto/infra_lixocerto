import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const apiRoot = resolve(root, '../api_lixocerto');
const protoDir = resolve(apiRoot, 'contratos/lixo_certo/v1');
const host = process.env.GRPC_SMOKE_HOST ?? '127.0.0.1:50051';
const timeoutMs = Number(process.env.GRPC_SMOKE_TIMEOUT ?? '8000');

function lerAmbiente() {
  const caminho = resolve(root, '.env');
  const ambiente = {};
  for (const linha of readFileSync(caminho, 'utf8').split(/\r?\n/)) {
    const correspondencia = linha.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!correspondencia) continue;
    ambiente[correspondencia[1]] = correspondencia[2].trim().replace(/^['"]|['"]$/g, '');
  }
  return ambiente;
}

function carregarServico(arquivo, nomeServico) {
  const definicao = protoLoader.loadSync(resolve(protoDir, arquivo), {
    includeDirs: [protoDir],
    keepCase: false,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });
  const pacote = grpc.loadPackageDefinition(definicao);
  const servico = pacote?.lixo_certo?.v1?.[nomeServico];
  if (!servico) throw new Error(`Serviço ${nomeServico} não encontrado`);
  return servico;
}

function nomeMetodo(cliente, nome) {
  const candidatos = [nome, nome.charAt(0).toLowerCase() + nome.slice(1)];
  const encontrado = candidatos.find(candidato => typeof cliente[candidato] === 'function');
  if (!encontrado) throw new Error(`Método ${nome} não encontrado`);
  return encontrado;
}

async function obterToken(ambiente) {
  const porta = ambiente.KEYCLOAK_PORT ?? '8081';
  const endpoint = `http://127.0.0.1:${porta}/realms/lixo-certo/protocol/openid-connect/token`;
  const resposta = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'password',
      client_id: 'lixo-certo-postman',
      username: ambiente.KEYCLOAK_DEV_ADMIN_USERNAME ?? 'administrador',
      password: ambiente.KEYCLOAK_DEV_ADMIN_PASSWORD ?? '',
      scope: 'openid profile email',
    }),
  });
  if (!resposta.ok) throw new Error(`Keycloak não emitiu token (HTTP ${resposta.status})`);
  const corpo = await resposta.json();
  if (typeof corpo.access_token !== 'string' || !corpo.access_token) throw new Error('Resposta do Keycloak sem access_token');
  return corpo.access_token;
}

function chamar({ arquivo, servico, metodo, requisicao, token }) {
  return new Promise((resolvePromise, rejectPromise) => {
    const Cliente = carregarServico(arquivo, servico);
    const cliente = new Cliente(host, grpc.credentials.createInsecure());
    const metadados = new grpc.Metadata();
    metadados.set('authorization', `Bearer ${token}`);
    const deadline = new Date(Date.now() + timeoutMs);
    const nome = nomeMetodo(cliente, metodo);
    cliente[nome](requisicao, metadados, { deadline }, (erro, resposta) => {
      cliente.close();
      if (erro) {
        rejectPromise(new Error(`${erro.code ?? 'UNKNOWN'}: ${erro.details ?? erro.message}`));
        return;
      }
      resolvePromise(resposta);
    });
  });
}

try {
  const ambiente = lerAmbiente();
  const token = await obterToken(ambiente);
  const identidade = await chamar({
    arquivo: 'servico_autenticacao.proto',
    servico: 'ServicoAutenticacao',
    metodo: 'ObterIdentidadeAtual',
    requisicao: {},
    token,
  });
  const resumo = await chamar({
    arquivo: 'servico_administracao.proto',
    servico: 'ServicoAdministracao',
    metodo: 'ObterResumoAdministrativo',
    requisicao: {},
    token,
  });
  if (!identidade.idUsuario || !identidade.emailUsuario) throw new Error('Identidade autenticada incompleta');
  if (typeof resumo.quantidadeUsuarios !== 'number') throw new Error('Resposta administrativa inválida');
  console.log(`Smoke gRPC autenticado: 2/2 aprovados para ${identidade.emailUsuario}`);
  console.log('[OK] ServicoAutenticacao/ObterIdentidadeAtual');
  console.log('[OK] ServicoAdministracao/ObterResumoAdministrativo');
} catch (erro) {
  console.error(`Smoke gRPC autenticado: FALHA — ${erro instanceof Error ? erro.message : String(erro)}`);
  process.exitCode = 1;
}
