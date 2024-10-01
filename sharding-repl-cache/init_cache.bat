
@echo off

docker compose up -d

echo Waiting for services to start...
timeout /t 30

echo Initializing config server...
docker compose exec -T configsrv mongosh --port 27019 --quiet --eval "rs.initiate({_id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsrv:27019' }]})"

echo Setting up shard1 replication...
docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "rs.initiate({_id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1-primary:27018' }, { _id: 1, host: 'shard1-secondary1:27028' }, { _id: 2, host: 'shard1-secondary2:27038' }]})"

echo Setting up shard2 replication...
docker compose exec -T shard2-primary mongosh --port 27020 --quiet --eval "rs.initiate({_id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2-primary:27020' }, { _id: 1, host: 'shard2-secondary1:27029' }, { _id: 2, host: 'shard2-secondary2:27039' }]})"

echo Waiting for mongos to initialize...
timeout /t 30

echo Adding shards to mongos...
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1-primary:27018')"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard2ReplSet/shard2-primary:27020')"

echo Creating database and collection...
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.getSiblingDB('db').createCollection('helloDoc')"

echo Inserting documents into 'helloDoc' collection...
docker compose exec -T mongos mongosh --quiet --eval "db.getSiblingDB('db').helloDoc.insertMany([...Array(1000).keys()].map(i => ({ age: i, name: 'ly' + i })))"

echo Counting documents in the 'helloDoc' collection on shard1...
docker compose exec -T shard1-primary mongosh --port 27018 --quiet --eval "db.getSiblingDB('db').helloDoc.countDocuments()"

echo Counting documents in the 'helloDoc' collection on shard2...
docker compose exec -T shard2-primary mongosh --port 27020 --quiet --eval "db.getSiblingDB('db').helloDoc.countDocuments()"

echo Initialization complete.
pause
