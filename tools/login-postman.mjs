import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const apiRoot = resolve(root, '../api_lixocerto');
const proto = resolve(apiRoot, 'contratos/lixo_certo/v1/servico_autenticacao.proto');
const definicao = protoLoader.loadSync(proto, {
  includeDirs: [resolve(apiRoot, 'contratos/lixo_certo/v1')],
  keepCase: false,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});
const pacote = grpc.loadPackageDefinition(definicao);
const Cliente = pacote?.lixo_certo?.v1?.ServicoAutenticacao;
if (!Cliente) throw new Error('ServicoAutenticacao não encontrado');

const email = process.env.LCR_LOGIN_EMAIL?.trim();
const senha = process.env.LCR_LOGIN_PASSWORD;
const host = process.env.GRPC_SMOKE_HOST ?? '127.0.0.1:50051';
const timeoutMs = Number(process.env.GRPC_SMOKE_TIMEOUT ?? '15000');
if (!email || !senha) throw new Error('LCR_LOGIN_EMAIL e LCR_LOGIN_PASSWORD são obrigatórios');

const cliente = new Cliente(host, grpc.credentials.createInsecure());
const metodo = typeof cliente.entrar === 'function' ? 'entrar' : 'Entrar';
cliente[metodo]({ emailUsuario: email, senhaUsuario: senha }, new grpc.Metadata(), { deadline: new Date(Date.now() + timeoutMs) }, (erro, resposta) => {
  cliente.close();
  if (erro) {
    console.error(`${erro.code ?? 'UNKNOWN'}: ${erro.details ?? erro.message}`);
    process.exitCode = 1;
    return;
  }
  if (!resposta?.tokenAcesso || !resposta?.tokenAtualizacao) {
    console.error('Login não retornou os tokens esperados');
    process.exitCode = 1;
    return;
  }
  process.stdout.write(JSON.stringify({ tokenAcesso: resposta.tokenAcesso, tokenAtualizacao: resposta.tokenAtualizacao }));
});
