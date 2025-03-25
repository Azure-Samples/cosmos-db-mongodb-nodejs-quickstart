import { MongoClient } from 'mongodb';

export async function start(emit) {
    
    // <create_client>    
    const connectionString = process.env.CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING;
    const client = new MongoClient(connectionString);
    // </create_client>

    var host = client.options.hosts[0];
    if (host) {
        console.log(`ENDPOINT:\t${host.host}:${host.port}`);
    }

    emit('Current Status:\tStarting...');

    const databaseName = process.env.CONFIGURATION__AZURECOSMOSDB__DATABASENAME ?? 'cosmicworks';
    const database = client.db(databaseName);

    emit(`Get database:\t${database.databaseName}`);

    const collectionName = process.env.CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME ?? 'products';
    const collection = database.collection(collectionName);

    emit(`Get collection:\t${collection.collectionName}`);

    {
        var document = {
            _id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
            category: 'gear-surf-surfboards',
            name: 'Yamba Surfboard',
            quantity: 12,
            price: 850.00,
            clearance: false
        };

        const query = {
            _id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
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
            emit(`Upserted document:\t${JSON.stringify(document)}`);
        }   
    }

    {
        var document = {
            _id: 'bbbbbbbb-1111-2222-3333-cccccccccccc',
            category: 'gear-surf-surfboards',
            name: 'Kiama Classic Surfboard',
            quantity: 25,
            price: 790.00,
            clearance: true
        };

        const query = {
            _id: 'bbbbbbbb-1111-2222-3333-cccccccccccc',
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
            emit(`Upserted document:\t${JSON.stringify(document)}`);
        }   
    }

    {
        var query = { 
            _id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb', 
            category: 'gear-surf-surfboards' 
        };

        var response = await collection.findOne(query);
        var read_item = response;

        emit(`Read document _id:\t${read_item._id}`);
        emit(`Read document:\t${JSON.stringify(read_item)}`);
    }

	{
        var query = { 
            category: 'gear-surf-surfboards' 
        };

        var response = await collection.find(query);

        for await (const item of response) {
            emit(`Found document:\t${item.name}\t${item._id}`);
        }
    }

    emit('Current Status:\tFinalizing...');
}
