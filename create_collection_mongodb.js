/**
 * Drop the db and insert sample document
 */
var config = JSON.parse(fs.readFileSync("/home/marcos.albe/CS0042248/js_test_config.json", 'utf8'));
print("Creating collection...");
db.getSiblingDB(config.schema).dropDatabase();
db.createCollection(config.collection);
db.getCollection(config.collection).insertOne(JSON.parse(fs.readFileSync(config.dataDir+"/singleDocumentSample.json", 'utf8')));
db.getCollection(config.collection).createIndex({"valuation":1});
print("Created collection "+config.collection+" and added "+db.getCollection(config.collection).countDocuments()+" document(s).");
