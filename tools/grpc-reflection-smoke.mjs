import { loadSync } from '@grpc/proto-loader';
import grpc from '@grpc/grpc-js';
import { resolve } from 'node:path';

const host = process.argv[2] ?? '127.0.0.1:50051';
const protoPath = resolve(process.argv[3] ?? '../api-lixo-certo/node_modules/@grpc/reflection/build/proto/grpc/reflection/v1alpha/reflection.proto');
const definition = loadSync(protoPath, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});
const pacote = grpc.loadPackageDefinition(definition);
const ClienteReflexao = pacote.grpc.reflection.v1alpha.ServerReflection;
const cliente = new ClienteReflexao(host, grpc.credentials.createInsecure());

const nomes = await new Promise((resolvePromise, rejectPromise) => {
  const fluxo = cliente.serverReflectionInfo();
  const temporizador = setTimeout(() => {
    fluxo.destroy();
    rejectPromise(new Error(`Timeout ao consultar server reflection em ${host}`));
  }, 5000);

  fluxo.once('error', erro => {
    clearTimeout(temporizador);
    rejectPromise(erro);
  });
  fluxo.on('data', resposta => {
    clearTimeout(temporizador);
    if (resposta.error_response) {
      rejectPromise(new Error(`${resposta.error_response.error_code}: ${resposta.error_response.error_message}`));
      fluxo.destroy();
      return;
    }
    const servicos = resposta.list_services_response?.service ?? [];
    if (servicos.length > 0) {
      resolvePromise(servicos.map(servico => servico.name).sort());
      fluxo.destroy();
    }
  });
  fluxo.write({ list_services: '' });
});

cliente.close();
const esperados = [
  'lixo_certo.v1.ServicoAdministracao',
  'lixo_certo.v1.ServicoAuditoria',
  'lixo_certo.v1.ServicoAutenticacao',
  'lixo_certo.v1.ServicoAvaliacaoUsabilidade',
  'lixo_certo.v1.ServicoDesafios',
  'lixo_certo.v1.ServicoGamificacao',
  'lixo_certo.v1.ServicoIdentidade',
  'lixo_certo.v1.ServicoMateriais',
  'lixo_certo.v1.ServicoPerfil',
  'lixo_certo.v1.ServicoPontosColeta',
  'lixo_certo.v1.ServicoQuestionarios',
  'lixo_certo.v1.ServicoSaude',
  'lixo_certo.v1.ServicoSessoes',
];

for (const servico of esperados) {
  if (!nomes.includes(servico)) throw new Error(`Serviço ausente na reflection: ${servico}`);
}
console.log(`Server reflection gRPC: ${nomes.length} serviços descobertos em ${host}`);
process.exit(0);
