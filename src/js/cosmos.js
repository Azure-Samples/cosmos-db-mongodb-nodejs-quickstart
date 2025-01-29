import { MongoClient } from 'mongodb';

export async function start(emit) {
    // <create_client>
    
    const connectionString = process.env.CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING

    if (connectionString.includes('<user>')) {
        connectionString.replace('<user>', encodeURIComponent(process.env.CONFIGURATION__AZURECOSMOSDB__ADMINLOGIN));
    }

    if (connectionString.includes('<password>')) {
        connectionString.replace('<password>', encodeURIComponent(process.env.CONFIGURATION__AZURECOSMOSDB__ADMINPASSWORD));
    }

    const client = new MongoClient(connectionString);
    // </create_client>

    var host = client.options.hosts[0];
    if (host) {
        console.log(`ENDPOINT:\t${host.host}:${host.port}`);
    }

    emit('Current Status:\tStarting...');

    const databaseName = process.env.CONFIGURATION__AZURECOSMOSDB__DATABASENAME ?? 'cosmicworks';
    const database = client.db(databaseName);

    emit(`Get database:\t${database.id}`);

    const collectionName = process.env.CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME ?? 'products';
    const collection = database.collection(collectionName);

    emit(`Get collection:\t${collection.collectionName}`);

    {
        var document = {
            'id': 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
            'category': 'gear-surf-surfboards',
            'name': 'Yamba Surfboard',
            'quantity': 12,
            'price': 850.00,
            'clearance': false
        };

        const query = {
            id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
            category: 'gear-surf-surfboards'
        };
        const payload = {
            $set: document
        };
        const options = {
            upsert: true,
            new: true
        };
        var response = await collection.updateOne(query, payload, options);

        if (response.acknowledged) {
            emit(`Upserted item:\t${JSON.stringify(document)}`);
        }   
    }

    {
        var item = {
            'id': 'bbbbbbbb-1111-2222-3333-cccccccccccc',
            'category': 'gear-surf-surfboards',
            'name': 'Kiama Classic Surfboard',
            'quantity': 25,
            'price': 790.00,
            'clearance': true
        };

        const query = {
            id: 'bbbbbbbb-1111-2222-3333-cccccccccccc',
            category: 'gear-surf-surfboards'
        };
        const payload = {
            $set: document
        };
        const options = {
            upsert: true,
            new: true
        };
        var response = await collection.updateOne(query, payload, options);

        if (response.acknowledged) {
            emit(`Upserted item:\t${JSON.stringify(document)}`);
        }   
    }

    {
        var query = { 
            id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb', 
            category: 'gear-surf-surfboards' 
        };

        var response = await collection.findOne(query);
        var read_item = response;

        emit(`Read item id:\t${read_item.id}`);
        emit(`Read item:\t${JSON.stringify(read_item)}`);
    }

	{
        var query = { 
            category: 'gear-surf-surfboards' 
        };

        var response = await collection.find(query);

        for await (const item of response) {
            emit(`Found item:\t${item.name}\t${item.id}`);
        }
    }

    emit('Current Status:\tFinalizing...');
}