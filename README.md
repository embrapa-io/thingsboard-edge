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

No Windows com Docker Desktop, use o bootstrap equivalente em PowerShell:

```powershell
.\bootstrap.ps1
```

O script cria a rede e os volumes externos e configura `TB_SERVER=thingsboard`
para alcançar diretamente o serviço da Central pela rede Docker compartilhada
`io_thingsboard` (sem depender de DNS do host). Depois de cadastrar o Edge na
Central e preencher `TB_EDGE_KEY` e `TB_EDGE_SECRET` no `.env`, suba a stack
com:

```powershell
.\bootstrap.ps1 -Start
```

As portas UDP do CoAP do Edge sao remapeadas para `6583-6588`, pois a Central local ja utiliza `5683-5688`. MQTT fica disponivel em `localhost:9883`, MQTTS em `localhost:9884` e a interface web em `http://localhost:9190`.

O listener MQTTS do Edge usa, por padrão no ambiente local, os certificados de
desenvolvimento montados da Central (`../thingsboard/certs/server.pem` e
`server_key.pem`) como somente leitura. Em uma implantação real, defina
`MQTT_SSL_CERT_FILE` e `MQTT_SSL_KEY_FILE` para um certificado próprio cujo SAN
contenha o hostname público do Edge. Esse TLS é independente de
`CLOUD_RPC_SSL_ENABLED`, que protege o canal Edge–Central.

Ao cadastrar os atributos de conectividade do Edge na Central, use o endereço
que os devices realmente alcançarão e as portas externas:

```text
mqttHost=<hostname-publico-ou-ip-do-edge>
mqttEnabled=true|false
mqttPort=9883
mqttsEnabled=true
mqttsPort=9884
```

O dashboard recomenda MQTTS e só habilita MQTT simples quando
`mqttEnabled=true` e o endpoint estiver publicado.

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
