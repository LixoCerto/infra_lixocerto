import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const raiz = resolve(import.meta.dirname, '..');
const compose = readFileSync(resolve(raiz, 'compose.yml'), 'utf8');
const ambiente = readFileSync(resolve(raiz, '.env.exemplo'), 'utf8');
const smoke = readFileSync(resolve(raiz, 'tools/grpc-auth-smoke.mjs'), 'utf8');
const login = readFileSync(resolve(raiz, 'tools/login-postman.mjs'), 'utf8');

function garantir(condicao, mensagem) {
  if (!condicao) throw new Error(mensagem);
}

garantir(compose.includes('SEGREDO_JWT:'), 'Compose não passa SEGREDO_JWT para a API.');
garantir(compose.includes('EMISSOR_JWT:'), 'Compose não passa EMISSOR_JWT para a API.');
garantir(compose.includes('AUDIENCIA_JWT:'), 'Compose não passa AUDIENCIA_JWT para a API.');
garantir(ambiente.includes('SEGREDO_JWT='), '.env.exemplo não documenta SEGREDO_JWT.');
garantir(smoke.includes("metodo: 'Entrar'"), 'Smoke autenticado não usa Entrar local.');
garantir(smoke.includes("metodo: 'ObterIdentidadeAtual'"), 'Smoke autenticado não valida identidade.');
garantir(login.includes("ServicoAutenticacao"), 'Cliente de login gRPC não está disponível.');
garantir(!compose.includes('ENDERECO_JWKS:'), 'API ainda recebe ENDERECO_JWKS do Compose.');

console.log('Autenticação local: Compose, JWT próprio, login gRPC e smoke autenticado validados.');
