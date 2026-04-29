# ThingsBoard Edge for Embrapa I/O

Configuração de _deploy_ do [ThingsBoard Edge](https://thingsboard.io/docs/edge/) no ecossistema do Embrapa I/O.

Baseado na [configuração de _deploy_ do ThingsBoard Edge usando Docker](https://thingsboard.io/docs/user-guide/install/edge/docker/), e atua em conjunto com a stack do [ThingsBoard CE Server](../thingsboard).

## Pilha tecnológica

Imagens fixadas na **macro-versão** de cada componente, recebendo apenas _patches_ de segurança/_bugfix_ (sem _breaking changes_):

| Componente | Imagem | Versão |
|---|---|---|
| ThingsBoard Edge CE | `thingsboard/tb-edge` | `4.3.1EDGE-latest` |
| PostgreSQL | `postgres` | `17` |
| pgAdmin 4 | `dpage/pgadmin4` | `9` |
| Backup do Postgres | `prodrigestivill/postgres-backup-local` | `17` |

## Pré-requisito: cadastro do Edge no ThingsBoard Server

Antes de configurar/subir esta stack, o Edge precisa estar **cadastrado no ThingsBoard Server** da plataforma Embrapa I/O em [https://iot.embrapa.io](https://iot.embrapa.io). É o cadastro que gera os valores de `TB_EDGE_KEY` e `TB_EDGE_SECRET` exigidos pelo `.env`.

Quem faz o cadastro: um **administrador do _tenant_ da Unidade** da pessoa. Se a Unidade ainda não tiver _tenant_ provisionado, é necessário solicitar à **equipe de suporte da plataforma Embrapa I/O** a criação do _tenant_ antes de cadastrar o Edge.

## Deploy

Com o Edge já cadastrado no _server_, defina no `.env` os parâmetros de conexão (`TB_SERVER`, `TB_EDGE_KEY`, `TB_EDGE_SECRET`) obtidos no cadastro.

```sh
./bootstrap.sh
docker compose up -d --wait
```

O `bootstrap.sh` é idempotente e voltado para uso local/dev: gera `.env` (com segredos aleatórios para `DB_PASSWORD` e `PGADMIN_PASSWORD`), cria a rede externa `io_thingsboard_edge` e provisiona os volumes Docker (incluindo bind-mounts de `log/` e `backup/`).

A **instalação do schema** do Edge no PostgreSQL é feita automaticamente pelo próprio _entrypoint_ da imagem `thingsboard/tb-edge` no primeiro launch (controlada pelo marker `/data/.firstlaunch` no volume `tb_data`) — então não depende do `bootstrap.sh`. Isso permite que a plataforma de _deploy_ do Embrapa I/O (que provisiona volumes/`.env` por conta própria) suba a stack apenas com `docker compose up -d --wait`.

## Configuração

Usuário padrão do Edge após o _sync_ inicial com o _server_:

- Tenant Administrator: `tenant@thingsboard.org` / `tenant`

## Update

Para subir a versão do ThingsBoard Edge, ajuste a tag em `docker-compose.yml` (linha do serviço `edge`) e execute o procedimento oficial de _upgrade_:

```sh
docker compose stop && docker compose pull && docker compose up -d db
echo '4.3.1.1' > $(pwd)/log/.upgradeversion
docker run -it --rm \
  --network "$(docker compose ps --format '{{.Service}} {{.Network}}' db | awk '{print $2}')" \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/edge \
  -e SPRING_DATASOURCE_USERNAME="$(grep ^DB_USER= .env | cut -d= -f2)" \
  -e SPRING_DATASOURCE_PASSWORD="$(grep ^DB_PASSWORD= .env | cut -d= -f2)" \
  thingsboard/tb-edge:4.3.1EDGE-latest upgrade-tb-edge.sh
docker compose rm edge
docker compose up -d --force-recreate --wait
```

Substitua `'4.3.1.1'` pela versão **atual** instalada (que será sobrescrita pela nova).
