# ThingsBoard Edge for Embrapa I/O

Configuração de deploy do [ThingsBoard Edge](https://thingsboard.io/docs/edge/) no ecossistema do Embrapa I/O.

Baseado na [configuração de _deploy_ do ThingsBoard Edge usando Docker](https://thingsboard.io/docs/user-guide/install/edge/docker/).

## Deploy

```
docker volume create thingsboard_edge_db
docker volume create thingsboard_edge_pgadmin
docker volume create --driver local --opt type=none --opt device=$(pwd)/data --opt o=bind thingsboard_edge_data
docker volume create --driver local --opt type=none --opt device=$(pwd)/log --opt o=bind thingsboard_edge_log
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind thingsboard_edge_backup

cp .env.example .env

docker-compose up --force-recreate --build --remove-orphans --wait
```

## Configuração

Usuários e senhas padrões:

- System Administrator: sysadmin@thingsboard.org / sysadmin
- Tenant Administrator: tenant@thingsboard.org / tenant
- Customer User: customer@thingsboard.org / customer

## Update

Alterar abaixo o valor '3.6.4' pela versão atual (que será substituída pela nova versão):

```
docker-compose stop && docker-compose pull && docker-compose up -d db
echo '3.6.4' > $(pwd)/data/.upgradeversion
docker run -it --rm \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/thingsboard \
  -e SPRING_DATASOURCE_USERNAME=thingsboard \
  -e SPRING_DATASOURCE_PASSWORD=secret \
  thingsboard/tb-postgres upgrade-tb.sh
docker compose rm thingsboard
docker-compose up --force-recreate --build --remove-orphans --wait
```
