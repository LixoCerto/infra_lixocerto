import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const apiRoot = resolve(root, '../api_lixocerto');
const protoDir = resolve(apiRoot, 'contratos/lixo_certo/v1');
const host = process.env.GRPC_SMOKE_HOST ?? '127.0.0.1:50051';
const timeoutMs = Number(process.env.GRPC_SMOKE_TIMEOUT ?? '15000');

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

function chamar({ arquivo, servico, metodo, requisicao, token }) {
  return new Promise((resolvePromise, rejectPromise) => {
    const Cliente = carregarServico(arquivo, servico);
    const cliente = new Cliente(host, grpc.credentials.createInsecure());
    const metadados = new grpc.Metadata();
    if (token) metadados.set('authorization', `Bearer ${token}`);
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

const email = process.env.GRPC_SMOKE_EMAIL?.trim();
const senha = process.env.GRPC_SMOKE_PASSWORD;
if (!email || !senha) {
  console.error('Smoke gRPC autenticado exige GRPC_SMOKE_EMAIL e GRPC_SMOKE_PASSWORD no ambiente do processo.');
  process.exitCode = 2;
} else {
  try {
    const entrada = await chamar({
      arquivo: 'servico_autenticacao.proto',
      servico: 'ServicoAutenticacao',
      metodo: 'Entrar',
      requisicao: { emailUsuario: email, senhaUsuario: senha },
    });
    if (!entrada.tokenAcesso || !entrada.tokenAtualizacao) throw new Error('Login não retornou os tokens esperados');

    const identidade = await chamar({
      arquivo: 'servico_autenticacao.proto',
      servico: 'ServicoAutenticacao',
      metodo: 'ObterIdentidadeAtual',
      requisicao: {},
      token: entrada.tokenAcesso,
    });
    const resumo = await chamar({
      arquivo: 'servico_administracao.proto',
      servico: 'ServicoAdministracao',
      metodo: 'ObterResumoAdministrativo',
      requisicao: {},
      token: entrada.tokenAcesso,
    });
    if (!identidade.idUsuario || !identidade.emailUsuario) throw new Error('Identidade autenticada incompleta');
    if (typeof resumo.quantidadeUsuarios !== 'number') throw new Error('Resposta administrativa inválida');
    console.log(`Smoke gRPC autenticado: 3/3 aprovados para ${identidade.emailUsuario}`);
    console.log('[OK] ServicoAutenticacao/Entrar');
    console.log('[OK] ServicoAutenticacao/ObterIdentidadeAtual');
    console.log('[OK] ServicoAdministracao/ObterResumoAdministrativo');
  } catch (erro) {
    console.error(`Smoke gRPC autenticado: FALHA — ${erro instanceof Error ? erro.message : String(erro)}`);
    process.exitCode = 1;
  }
}
