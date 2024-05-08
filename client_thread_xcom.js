require('mysqlx');
var config = JSON.parse(os.loadTextFile("./js_test_config.json"));
var session = mysqlx.getSession(config.connectionOpts);
var collection = session.getSchema(config.schema).getCollection(config.collection);

var testParams = JSON.parse(sys.argv[1]);

function logMessage(message, threadId) {
    var d = new Date();
    println("["+d.toISOString()+"][client "+threadId+"] "+message);    
}


function logRowCountToDb(rowCount) {
    try {
        session.getSchema('test').getCollection('benchmark').add({"_id": testParams.testId, "val": rowCount });
    } catch (e) {
        // we assume we failed the add() because row was already there.. TODO: we should check the error code to be sure.
        session.getSchema('test').getCollection('benchmark').modify("_id="+ testParams.testId).set("val", mysqlx.expr("val + "+rowCount));
    }
}


var tests = [];
tests['insert_ordered'] = function (testParams) {
    var statementCnt=0;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount);
    var r = null;
    
    for (batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.rawChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".json";
        if (testParams.commitFrequency > 0 && statementCnt == 0) {
            // logMessage("Starting transaction...", testParams.threadId);
            session.startTransaction();
        }
        try {
            r = collection.add(JSON.parse("[" + os.loadTextFile(batchFile).replaceAll("\n", ",").slice(0,-1) + "]"));
            r.execute();
            statementCnt++;
        } catch (error) {
            logMessage("Failed adding to the collection ("+testParams.testMode+" mode): ("+error.type+": "+error.message+")", testParams.threadId);            
            if (testParams.commitFrequency > 0) {
                session.rollback();
            }
        }

        if (testParams.commitFrequency > 0 && statementCnt == testParams.commitFrequency) {
            // logMessage("Running COMMIT.", testParams.threadId);
            session.commit();
            statementCnt=0;
        }
    }

    if (testParams.commitFrequency > 0) {logMessage("Running catch-all COMMIT.", testParams.threadId);
        session.commit();
    }
};


tests['_update'] = function (testParams, lookupAttribute) {
    var statementCnt=0;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount);     
    var r = null;    
    for (batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.lookupChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".dat";
        
        if (testParams.commitFrequency > 0 && statementCnt == 0) {
            session.startTransaction();
        }

        try {
            r = collection.modify(lookupAttribute + ' IN (' + os.loadTextFile(batchFile).replaceAll("\n", ",").slice(0,-1) + ')').set("crunchBaseRank", mysqlx.expr("crunchBaseRank + 12345")); 
            r.execute();
            statementCnt++;
        } catch (error) {
            logMessage("Failed updating the collection ("+testParams.testMode+" mode): ("+error.type+": "+error.message+")", testParams.threadId);            
            if (testParams.commitFrequency > 0) {
                session.rollback();
            }            
        }

        if (testParams.commitFrequency > 0 && statementCnt == testParams.commitFrequency) {
            session.commit();
            statementCnt=0;
        }
    }

    if (testParams.commitFrequency > 0) {logMessage("Running catch-all COMMIT.", testParams.threadId);
        session.commit();
    }
};

tests['update_pk_lookup'] = function (testParams) {
    tests['_update'](testParams, '_id');
};

tests['update_sk_lookup'] = function (testParams) {
    tests['_update'](testParams, 'valuation');
};

tests['_read'] = function(testParams, lookupAttribute) {
    var statementCnt=0;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount);     
    var r;
    for (var batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.lookupChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".dat";

        try {
            /*
            Doing "IN" for anything but the PK results in table scan, and using a series OR'ed k/v (like: k=v OR k=v1 OR k=v2 etc..) results in hitting https://bugs.mysql.com/bug.php?id=106688
            */
            if (testParams.testMode == 'pk_lookup') {
                r = collection.find(lookupAttribute + ' IN (' + os.loadTextFile(batchFile).replaceAll("\n", ",").slice(0,-1) + ')').execute(); 
            } else {
                var queryStr = lookupAttribute+'=' + os.loadTextFile(batchFile).replaceAll("\n", " OR "+lookupAttribute+"=").slice(0, (lookupAttribute.length + 4) * -1);  
                r = collection.find(queryStr).execute(); 
            }
            statementCnt++;
        } catch (error) {
            logMessage("Failed find() ("+testParams.testMode+" read): ("+error.type+": "+error.message+")", testParams.threadId);
        }
    }

}

tests['read_pk_lookup'] = function (testParams) {
    tests['_read'](testParams, '_id');
};

tests['read_sk_lookup'] = function (testParams) {
    tests['_read'](testParams, 'valuation');
};

logMessage("Processing "+ testParams.batchCount + " batches (mode: "+testParams.testMode+")", testParams.threadId);
tests[testParams.testType + '_' + testParams.testMode](testParams);
logMessage("Completed "+ testParams.batchCount + " batches (mode: "+testParams.testMode+")", testParams.threadId);

session.close();
