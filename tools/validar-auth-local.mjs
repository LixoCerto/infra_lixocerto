import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const raiz = resolve(import.meta.dirname, "..");
const compose = readFileSync(resolve(raiz, "compose.yml"), "utf8");
const ambiente = readFileSync(
  resolve(raiz, "../api_lixocerto/.env.exemplo"),
  "utf8",
);
const smoke = readFileSync(resolve(raiz, "tools/grpc-auth-smoke.mjs"), "utf8");
const login = readFileSync(resolve(raiz, "tools/login-postman.mjs"), "utf8");

function garantir(condicao, mensagem) {
  if (!condicao) throw new Error(mensagem);
}

garantir(
  compose.includes("../api_lixocerto/.env"),
  "Compose não carrega o .env da API.",
);
garantir(
  compose.includes("REDIS_HOST: cache"),
  "Compose não ajusta REDIS_HOST para o serviço cache.",
);
garantir(
  ambiente.includes("SEGREDO_JWT="),
  "../api_lixocerto/.env.exemplo não documenta SEGREDO_JWT.",
);
garantir(
  smoke.includes("metodo: 'Entrar'"),
  "Smoke autenticado não usa Entrar local.",
);
garantir(
  smoke.includes("metodo: 'ObterIdentidadeAtual'"),
  "Smoke autenticado não valida identidade.",
);
garantir(
  login.includes("ServicoAutenticacao"),
  "Cliente de login gRPC não está disponível.",
);
garantir(
  !compose.includes("ENDERECO_JWKS:"),
  "API ainda recebe ENDERECO_JWKS do Compose.",
);

garantir(
  !compose.includes("--env-file"),
  "Compose não deve exigir --env-file externo.",
);

garantir(
  !compose.includes("SEGREDO_JWT:"),
  "SEGREDO_JWT não deve ser duplicado no Compose.",
);

garantir(
  !compose.includes("VITE_API_BASE_URL:"),
  "VITE_API_BASE_URL deve vir do .env do frontend durante o build.",
);

console.log(
  "Autenticação local: Compose, env_file da API, JWT próprio, login gRPC e smoke autenticado validados.",
);
