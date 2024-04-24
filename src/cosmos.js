import { MongoClient, ObjectId } from 'mongodb';
import 'dotenv/config'

const random = Math.floor(Math.random() * 100);

// Use official mongodb driver to connect to the server
// const { MongoClient, ObjectId } = require('mongodb');

const url = process.env.COSMOS_CONNECTION_STRING;

// New instance of MongoClient with connection string
// for Cosmos 
const client = new MongoClient(url);

export async function main(emit) {

    // Use connect method to connect to the server
    await client.connect();

    // Database reference with creation if it does not already exist
    const db = client.db(`adventureworks`);
    emit(`New database:\t${db.databaseName}\n`);

    // Collection reference with creation if it does not already exist
    const collection = db.collection('products');
    emit(`New collection:\t${collection.collectionName}\n`);

    // create index to sort by name
    const indexResult = await collection.createIndex({ name: 1 });
    emit(`indexResult: ${JSON.stringify(indexResult)}\n`);

    // Create new doc and upsert (create or replace) to collection
    const product = {
        category: "gear-surf-surfboards",
        name: `Yamba Surfboard-${random}`,
        quantity: 12,
        sale: false
    };
    const query = { name: product.name };
    const update = { $set: product };
    const options = { upsert: true, new: true };

    // Insert via upsert (create or replace) doc to collection directly
    const upsertResult1 = await collection.updateOne(query, update, options);
    emit(`upsertResult1: ${JSON.stringify(upsertResult1)}\n`);

    // Update via upsert on chained instance
    const query2 = { _id: new ObjectId(upsertResult1.upsertedId) };
    const update2 = { $set: { quantity: 20 } };
    const upsertResult2 = await client.db(`adventureworks`).collection('products').updateOne(query2, update2, options);
    emit(`upsertResult2: ${JSON.stringify(upsertResult2)}\n`);

    // Point read doc from collection:
    // - without sharding, should use {_id}
    // - with sharding,    should use {_id, partitionKey }, ex: {_id, category}
    const foundProduct = await collection.findOne({
        _id: new ObjectId(upsertResult2.upsertedId)
    });
    emit(`foundProduct: ${JSON.stringify(foundProduct)}\n`);

    // select all from product category
    const allProductsQuery = {
        category: "gear-surf-surfboards"
    };

    // get all documents, sorted by name, convert cursor into array
    const products = await collection.find(allProductsQuery).sort({ name: 1 }).toArray();
    products.map((product, i) => emit(`${++i} ${JSON.stringify(product)}`));
}
