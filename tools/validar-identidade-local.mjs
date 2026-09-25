import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const raiz = resolve(import.meta.dirname, "..");
const caminhos = {
  realm: resolve(raiz, "keycloak/lixo-certo-realm.json"),
  compose: resolve(raiz, "compose.yml"),
  tema: resolve(raiz, "keycloak/themes/lixo-certo/login/theme.properties"),
  cssTema: resolve(raiz, "keycloak/themes/lixo-certo/login/resources/css/lixo-certo.css"),
  configuradorGoogle: resolve(raiz, "scripts/configurar-google-keycloak.ps1"),
};

for (const [nome, caminho] of Object.entries(caminhos)) {
  if (!existsSync(caminho)) throw new Error(`Arquivo obrigatório ausente: ${nome}`);
}

const realm = JSON.parse(readFileSync(caminhos.realm, "utf8"));
const compose = readFileSync(caminhos.compose, "utf8");
const configuradorGoogle = readFileSync(caminhos.configuradorGoogle, "utf8");

const garantir = (condicao, mensagem) => {
  if (!condicao) throw new Error(mensagem);
};

garantir(realm.realm === "lixo-certo", "Realm incorreto.");
garantir(realm.registrationAllowed === true, "Autorregistro não está habilitado.");
garantir(realm.verifyEmail === true, "Verificação de e-mail não está habilitada.");
garantir(realm.resetPasswordAllowed === true, "Recuperação de senha não está habilitada.");
garantir(realm.loginTheme === "lixo-certo", "Tema de identidade não está selecionado.");
garantir(realm.smtpServer?.host === "${SMTP_HOST}", "SMTP deve ser parametrizado por ambiente.");
garantir(realm.smtpServer?.port === "${SMTP_PORT}", "Porta SMTP deve ser parametrizada por ambiente.");
garantir(compose.includes("axllent/mailpit:v1.31.2"), "Serviço Mailpit versionado não foi encontrado.");
garantir(compose.includes("SMTP_HOST: mailpit"), "Keycloak não está conectado ao Mailpit.");
garantir(compose.includes("./keycloak/themes:/opt/keycloak/themes:ro"), "Tema Keycloak não está montado somente para leitura.");
garantir(compose.includes("VITE_OIDC_GOOGLE_ENABLED"), "Flag pública de Google não chega ao frontend.");
garantir(!configuradorGoogle.includes("Set-EnvValue 'GOOGLE_CLIENT_SECRET'"), "Client Secret Google não pode ser gravado no .env.");
garantir(configuradorGoogle.includes("[Security.SecureString]"), "Client Secret Google deve ser recebido como SecureString.");

console.log("Identidade local: realm, Mailpit, tema e configuração Google validados.");
