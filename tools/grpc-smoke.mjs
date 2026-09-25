import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function argument(name, fallback = undefined) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] ?? fallback : fallback;
}

if (process.argv.includes("--help")) {
  console.log(`Uso: node tools/grpc-smoke.mjs [opções]

Opções:
  --host HOST:PORT       Endereço gRPC (padrão: 127.0.0.1:50051)
  --proto-dir DIRETÓRIO  Diretório dos contratos .proto
  --timeout MILIS        Timeout de cada chamada (padrão: 15000)
  --report ARQUIVO       Salva relatório JSON
  --format json          Imprime somente o relatório JSON
`);
  process.exit(0);
}

const host = argument("--host", process.env.GRPC_SMOKE_HOST ?? "127.0.0.1:50051");
const timeoutMs = Number(argument("--timeout", process.env.GRPC_SMOKE_TIMEOUT ?? "15000"));
const configuredProtoDir = argument(
  "--proto-dir",
  process.env.GRPC_PROTO_DIR ?? resolve(root, "../api_lixocerto/contratos/lixo_certo/v1"),
);
const protoDir = isAbsolute(configuredProtoDir) ? configuredProtoDir : resolve(root, configuredProtoDir);
const reportPath = argument("--report", "");
const jsonOnly = argument("--format", "") === "json";

function proto(name) {
  return resolve(protoDir, name);
}

function carregarServico(protoFile, serviceName) {
  const definition = protoLoader.loadSync(protoFile, {
    includeDirs: [protoDir],
    keepCase: false,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });
  const pacote = grpc.loadPackageDefinition(definition);
  const servico = pacote?.lixo_certo?.v1?.[serviceName];
  if (!servico) {
    throw new Error(`Serviço ${serviceName} não encontrado em ${protoFile}`);
  }
  return servico;
}

function nomeMetodo(client, nome) {
  const candidatos = [nome, nome.charAt(0).toLowerCase() + nome.slice(1)];
  const encontrado = candidatos.find((candidato) => typeof client[candidato] === "function");
  if (!encontrado) throw new Error(`Método ${nome} não encontrado no cliente gRPC`);
  return encontrado;
}

function metadataBase() {
  const metadata = new grpc.Metadata();
  const token = process.env.GRPC_JWT_TOKEN?.trim();
  const usuario = process.env.GRPC_ID_USUARIO_EXTERNO?.trim();
  if (token) metadata.set("authorization", `Bearer ${token}`);
  if (usuario) metadata.set("x-id-usuario-externo", usuario);
  return metadata;
}

function chamar({ protoFile, serviceName, methodName, request, resumo }) {
  return new Promise((resolvePromise, rejectPromise) => {
    const startedAt = Date.now();
    try {
      const Service = carregarServico(protoFile, serviceName);
      const client = new Service(host, grpc.credentials.createInsecure());
      const method = nomeMetodo(client, methodName);
      const deadline = new Date(Date.now() + timeoutMs);
      client[method](request, metadataBase(), { deadline }, (error, response) => {
        const duracao = Date.now() - startedAt;
        client.close();
        if (error) {
          rejectPromise({
            ok: false,
            service: serviceName,
            method: methodName,
            durationMs: duracao,
            error: `${error.code ?? "UNKNOWN"}: ${error.details ?? error.message}`,
          });
          return;
        }
        resolvePromise({
          ok: true,
          service: serviceName,
          method: methodName,
          durationMs: duracao,
          response: resumo(response),
        });
      });
    } catch (error) {
      rejectPromise({
        ok: false,
        service: serviceName,
        method: methodName,
        durationMs: Date.now() - startedAt,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  });
}

const casos = [
  {
    protoFile: proto("servico_saude.proto"),
    serviceName: "ServicoSaude",
    methodName: "Verificar",
    request: {},
    resumo: (response) => ({
      statusServico: response.statusServico,
      statusBanco: response.statusBanco,
      statusRedis: response.statusRedis,
      versaoApi: response.versaoApi,
    }),
  },
  {
    protoFile: proto("servico_materiais.proto"),
    serviceName: "ServicoMateriais",
    methodName: "ListarMateriais",
    request: { numeroPagina: 1, tamanhoPagina: 20 },
    resumo: (response) => ({
      quantidadeTotal: response.quantidadeTotal,
      itensRetornados: response.materiais?.length ?? 0,
    }),
  },
  {
    protoFile: proto("servico_pontos_coleta.proto"),
    serviceName: "ServicoPontosColeta",
    methodName: "ListarPontosColeta",
    request: {},
    resumo: (response) => ({
      itensRetornados: response.pontosColeta?.length ?? 0,
    }),
  },
  {
    protoFile: proto("servico_questionarios.proto"),
    serviceName: "ServicoQuestionarios",
    methodName: "ListarQuestoes",
    request: { numeroPagina: 1, tamanhoPagina: 20 },
    resumo: (response) => ({
      itensRetornados: response.questoes?.length ?? 0,
    }),
  },
  {
    protoFile: proto("servico_gamificacao.proto"),
    serviceName: "ServicoGamificacao",
    methodName: "ObterRanking",
    request: { limiteResultado: 10 },
    resumo: (response) => ({
      itensRetornados: response.itensRanking?.length ?? 0,
    }),
  },
];

const startedAt = new Date().toISOString();
const resultados = [];
for (const caso of casos) {
  try {
    const resultado = await chamar(caso);
    if (caso.methodName === "Verificar") {
      const saudavel = resultado.response?.statusServico === "saudavel";
      const bancoDisponivel = resultado.response?.statusBanco === "disponivel";
      const redisDisponivel = resultado.response?.statusRedis === "disponivel";
      resultado.ok = resultado.ok && saudavel && bancoDisponivel && redisDisponivel;
      if (!resultado.ok) resultado.error = "Health check retornou dependência indisponível";
    }
    resultados.push(resultado);
  } catch (resultado) {
    resultados.push(resultado);
  }
}

const report = {
  startedAt,
  finishedAt: new Date().toISOString(),
  host,
  protoDir,
  total: resultados.length,
  aprovados: resultados.filter((resultado) => resultado.ok).length,
  falhas: resultados.filter((resultado) => !resultado.ok).length,
  resultados,
};

if (reportPath) {
  const absoluteReport = isAbsolute(reportPath) ? reportPath : resolve(root, reportPath);
  mkdirSync(dirname(absoluteReport), { recursive: true });
  writeFileSync(absoluteReport, `${JSON.stringify(report, null, 2)}\n`, "utf8");
}

if (jsonOnly) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`Smoke gRPC: ${report.aprovados}/${report.total} aprovados em ${host}`);
  for (const resultado of resultados) {
    const marcador = resultado.ok ? "OK" : "FALHA";
    console.log(`[${marcador}] ${resultado.service}/${resultado.method} (${resultado.durationMs} ms)`);
    if (!resultado.ok) console.log(`       ${resultado.error}`);
  }
  if (reportPath) console.log(`Relatório: ${reportPath}`);
}

process.exitCode = report.falhas === 0 ? 0 : 1;
