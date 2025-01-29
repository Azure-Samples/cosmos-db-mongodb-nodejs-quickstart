import { Collection, Db, Filter, FindCursor, MongoClient, UpdateFilter, UpdateOptions, UpdateResult, WithId } from 'mongodb';

import { Emit, Product } from './types'

export class DataClient {

    async start(emit: Emit) {
        const client: MongoClient = await this.createClient(emit);

        emit('Current Status:\tStarting...');

        const container: Collection<Product> = await this.createCollection(emit, client);

        await this.createItemVerbose(emit, container);

        await this.createItemConcise(emit, container);

        await this.readItem(emit, container);

        await this.queryItems(emit, container);

        emit('Current Status:\tFinalizing...');
    }

    async createClient(emit: Emit): Promise<MongoClient> {
        // <create_client>
        const connectionString: string = process.env.CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING!

        if (connectionString.includes('<user>')) {
            connectionString.replace('<user>', encodeURIComponent(process.env.CONFIGURATION__AZURECOSMOSDB__ADMINLOGIN!));
        }

        if (connectionString.includes('<password>')) {
            connectionString.replace('<password>', encodeURIComponent(process.env.CONFIGURATION__AZURECOSMOSDB__ADMINPASSWORD!));
        }

        const client = new MongoClient(connectionString);
        // </create_client>

        var host = client.options.hosts[0];
        if (host) {
            console.log(`ENDPOINT:\t${host.host}:${host.port}`);
        }

        return client;
    }

    async createCollection(emit: Emit, client: MongoClient): Promise<Collection<Product>> {
        const databaseName: string = process.env.CONFIGURATION__AZURECOSMOSDB__DATABASENAME ?? 'cosmicworks';
        const database: Db = client.db(databaseName);

        emit(`Get database:\t${database.databaseName}`);

        const collectionName: string = process.env.CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME ?? 'products';
        const collection: Collection<Product> = database.collection<Product>(collectionName);

        emit(`Get collection:\t${collection.collectionName}`);

        return collection;
    }

    async createItemVerbose(emit: Emit, collection: Collection<Product>) {
        var document: Product = {
            'id': 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
            'category': 'gear-surf-surfboards',
            'name': 'Yamba Surfboard',
            'quantity': 12,
            'price': 850.00,
            'clearance': false
        };
        
        var query: Filter<Product> = {
            id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb',
            category: 'gear-surf-surfboards'
        };
        var payload: UpdateFilter<Product> = {
            $set: document
        };
        var options: UpdateOptions = {
            upsert: true
        };
        var response: UpdateResult<Product> = await collection.updateOne(query, payload, options);

        if (response.acknowledged) {
            emit(`Upserted item:\t${JSON.stringify(document)}`);
        }
    }

    async createItemConcise(emit: Emit, collection: Collection<Product>) {
        var document: Product = {
            'id': 'bbbbbbbb-1111-2222-3333-cccccccccccc',
            'category': 'gear-surf-surfboards',
            'name': 'Kiama Classic Surfboard',
            'quantity': 25,
            'price': 790.00,
            'clearance': true
        };
        
        var query: Filter<Product> = { 
            id: 'bbbbbbbb-1111-2222-3333-cccccccccccc', 
            category: 'gear-surf-surfboards' 
        };
        var payload: UpdateFilter<Product> = {
            $set: document
        };
        var options: UpdateOptions = { 
            upsert: true 
        };
        var response: UpdateResult<Product> = await collection.updateOne(query, payload, options);

        if (response.acknowledged) {
            emit(`Upserted item:\t${JSON.stringify(document)}`);
        }
    }

    async readItem(emit: Emit, collection: Collection<Product>) {
        var query: Filter<Product> = { 
            id: 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb', 
            category: 'gear-surf-surfboards' 
        };

        var response: WithId<Product> | null = await collection.findOne(query);
        var read_item: Product = response as Product;

        emit(`Read item id:\t${read_item.id}`);
        emit(`Read item:\t${JSON.stringify(read_item)}`);
    }

    async queryItems(emit: Emit, collection: Collection<Product>) {
        var query: Filter<Product> = { 
            category: 'gear-surf-surfboards' 
        };

        var response: FindCursor<WithId<Product>> = await collection.find(query);

        for await (const item of response) {
            emit(`Found item:\t${item.name}\t${item.id}`);
        }
    }
}