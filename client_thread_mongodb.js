const { log } = require('console');
const fs = require('fs');
const { default: test } = require('node:test');
const sys = require('process');
var testParams = JSON.parse(sys.env['TEST_PARAMS']);
testParams.writeConcern = "majority";

session = db.getMongo().startSession( { readPreference: { mode: "primary" } } );

function logMessage(message, threadId) {
    var d = new Date();
    print("["+d.toISOString()+"][client "+threadId+"] "+message);    
}

var tests = [];
tests['insert_ordered'] = function (testParams) {
    var statementCnt=0;
    var rowCount=0;
    var r;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount); 

    for (var batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.rawChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".json";
        if (testParams.commitFrequency > 0 && statementCnt == 0) {
            // logMessage("Starting transaction...", testParams.threadId);
            session.startTransaction( { readConcern: { level: "local" }, writeConcern: { w: testParams.writeConcern } } );
        }
        try {
            r = db.companies.insertMany(JSON.parse("[" + fs.readFileSync(batchFile, 'utf8').replaceAll("\n", ",").slice(0,-1) + "]"), { writeConcern: { w: testParams.writeConcern } });
            rowCount+=Object.keys(r.insertedIds).length;
            statementCnt++;
        } catch (error) {
            logMessage("Aborting transaction! ("+error.toString()+")", testParams.threadId);
            statementCnt=0;
            if (testParams.commitFrequency > 0) {
                session.abortTransaction();
            }
            throw error;        
        }

        if (testParams.commitFrequency > 0 && statementCnt == testParams.commitFrequency) {
            // logMessage("Running COMMIT.", testParams.threadId);
            session.commitTransaction();
            statementCnt=0;
        }
    }

    if (testParams.commitFrequency > 0) {
        logMessage("Running catch-all COMMIT.", testParams.threadId);
        try {
            session.commitTransaction();
        } catch (error) {
            logMessage("Catch-all commit throw an exception: "+error.toString(), testParams.threadId);
        }
    }
    return rowCount;
};

tests['_update'] = function (testParams, lookupAttribute) {
    var statementCnt=0;
    var rowCount=0;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount); 

    for (var batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.lookupChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".dat";
        if (testParams.commitFrequency > 0 && statementCnt == 0) {
            // logMessage("Starting transaction...", testParams.threadId);
            session.startTransaction( { readConcern: { level: "local" }, writeConcern: { w: testParams.writeConcern } } );
        }
        try {
            var query = new Object();
            query[lookupAttribute] = { $in: eval("[" + fs.readFileSync(batchFile, 'utf8').replaceAll("\n", ",").slice(0,-1) + "]") };          
            r = db.companies.updateMany(
                query,
                { $inc: { crunchBaseRank: 12345 } /*, $set: { updatedBy: testParams.testId+"/thread_"+testParams.threadId }*/ }
            );
            rowCount += r.modifiedCount;
            statementCnt++;

            /*
            if (statementCnt % 64) {
                db.benchmark.update({_id: testParams.testId}, { $inc: { val: rowCount } }, {upsert:true});
                modifiedCount=0;
            }
            */
        } catch (error) {
            logMessage("Aborting transaction! ("+error.toString()+")", testParams.threadId);
            statementCnt=0;
            if (testParams.commitFrequency > 0) {
                session.abortTransaction();
            }
            throw error;        
        }

        if (testParams.commitFrequency > 0 && statementCnt == testParams.commitFrequency) {
            // logMessage("Running COMMIT.", testParams.threadId);
            session.commitTransaction();
            statementCnt=0;
        }      

    }

    if (testParams.commitFrequency > 0) {
        logMessage("Running catch-all COMMIT.", testParams.threadId);
        try {
            session.commitTransaction();
        } catch (error) {
            logMessage("Catch-all commit throw an exception: "+error.toString(), testParams.threadId);
        }
    }

    return rowCount;
};

tests['update_pk_lookup'] = function (testParams) {
    return tests['_update'](testParams, '_id');
}

tests['update_sk_lookup'] = function (testParams) {
    return tests['_update'](testParams, 'valuation');
}

tests['_read'] = function (testParams, lookupAttribute) {
    var statementCnt=0;
    var rowCount=0;
    var r;
    var batchOffset=((testParams.threadId-1) * testParams.batchCount);     
    for (var batchNum=0; batchNum < testParams.batchCount; batchNum++) {
        var batchFile = testParams.lookupChunksDataDir + "/chunk." + (batchOffset + batchNum).toString().padStart(9, '0') + ".dat";
        try {
            var query = new Object();
            query[lookupAttribute] = { $in: eval("[" + fs.readFileSync(batchFile, 'utf8').replaceAll("\n", ",").slice(0,-1) + "]") };            
            r = db.companies.find(query);
            rowCount+=r.count();
            statementCnt++;
        } catch (error) {
            logMessage("Aborted read! ("+error.toString()+")", testParams.threadId);
            throw error;        
        }
    }
    return rowCount;
}

tests['read_pk_lookup'] = function (testParams) {
    return tests['_read'](testParams, '_id');    
}

tests['read_sk_lookup'] = function (testParams) {
    return tests['_read'](testParams, 'valuation');
}


logMessage("Processing "+testParams.batchCount+" batches", testParams.threadId);
var rowCount = tests[testParams.testType + '_' + testParams.testMode](testParams);
logMessage("Completed "+testParams.batchCount+" batches ("+rowCount+" rows matched/affected)", testParams.threadId);
session.endSession();
