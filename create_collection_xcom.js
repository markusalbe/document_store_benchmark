require('mysqlx');
var config = JSON.parse(os.loadTextFile("js_test_config.json"));
var session = mysqlx.getSession(config.connectionOpts);

println("Creating collection...");
try {
    var db = session.getSchema(config.schema);
} catch (e) {
    var db = session.createSchema(config.schema);
};

db.dropCollection(config.collection);

var collection = db.createCollection(config.collection);
collection.add(JSON.parse(os.loadTextFile(config.dataDir+"/singleDocumentSample.json")));
collection.createIndex("valuation", {fields:[{"field": "$.valuation", "type":"INT", required:true}]});
// session.sql('ALTER TABLE test.companies ADD INDEX valuation_json (( CAST(doc->>"$.valuation" as CHAR(32)) ))').execute();
session.sql('ALTER TABLE test.companies ADD INDEX valuation_json (( CAST(doc->>"$.valuation" as UNSIGNED) ))').execute();
println("Created collection "+collection.getName()+" and added "+collection.count()+" document(s).")    
