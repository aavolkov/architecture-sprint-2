@echo off

docker compose up -d

echo Waiting for mongos to starting ...
timeout /t 20

echo Initializing config server...
docker compose exec -T configsrv mongosh --port 27019 --quiet --eval "rs.initiate({_id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'configsrv:27019' }]})"

echo Setting up shard1 replication...
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "rs.initiate({_id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1:27018' }]})"

echo Setting up shard2 replication...
docker compose exec -T shard2 mongosh --port 27020 --quiet --eval "rs.initiate({_id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2:27020' }]})"

echo Waiting for mongos to initialize...
timeout /t 20

echo Adding shards to mongos...
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1:27018')"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard2ReplSet/shard2:27020')"

echo Creating database and collection...
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.createCollection('helloDoc')"


echo Inserting documents into 'helloDoc' collection...
docker compose exec -T mongos mongosh --quiet --eval "for(var i = 0; i < 1000; i++) { db.helloDoc.insertOne({age: i, name: 'ly' + i}); }"

echo Counting documents in the 'helloDoc' collection on shard1...
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.helloDoc.countDocuments()"

echo Counting documents in the 'helloDoc' collection on shard2...
docker compose exec -T shard2 mongosh --port 27020 --quiet --eval "db.helloDoc.countDocuments()"

echo Initialization complete.