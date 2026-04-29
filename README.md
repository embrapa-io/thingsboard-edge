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

## Deploy

Antes de subir a stack, defina no `.env` os parâmetros de conexão com o ThingsBoard Server (`TB_SERVER`, `TB_EDGE_KEY`, `TB_EDGE_SECRET`), obtidos no cadastro do Edge no _server_.

```sh
./bootstrap.sh
docker compose up -d --wait
```

O `bootstrap.sh` é idempotente: gera `.env` (com segredos aleatórios para `DB_PASSWORD` e `PGADMIN_PASSWORD`), cria a rede externa `io_thingsboard_edge`, provisiona os volumes Docker e instala o _schema_ do Edge no PostgreSQL na primeira execução.

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
