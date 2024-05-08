var global = 1234;

function myfun() {
    for (i=0;i<1000;i++) {
        print(i+" ");
    }
}

myfun();



s = shell.getSession();
collection = s.getSchema('test').createCollection('companies', {reuseExistingObject:1});

conds='valuation=40652448 OR valuation=40652553 OR valuation=40652566 OR valuation=40652622 OR valuation=40652707 OR valuation=40652820 OR valuation=40652831 OR valuation=40652849 OR valuation=40652880 OR valuation=40652926 OR valuation=40652946 OR valuation=40653129 OR valuation=40653201 OR valuation=40653213 OR valuation=40653373 OR valuation=40653468 OR valuation=40652448 OR valuation=40652553 OR valuation=40652566 OR valuation=40652622 OR valuation=40652707 OR valuation=40652820 OR valuation=40652831 OR valuation=40652849 OR valuation=40652880 OR valuation=40652926 OR valuation=40652946 OR valuation=40653129 OR valuation=40653201 OR valuation=40653213 OR valuation=40653373 OR valuation=40653468 OR valuation=40652448 OR valuation=40652553 OR valuation=40652566 OR valuation=40652622 OR valuation=40652707 OR valuation=40652820 OR valuation=40652831 OR valuation=40652849 OR valuation=40652880 OR valuation=40652926 OR valuation=40652946 OR valuation=40653129 OR valuation=40653201 OR valuation=40653213 OR valuation=40653373 OR valuation=40653468 ';

collection.find('valuation IN (40652448,40652553,40652566,40652622,40652707,40652820,40652831,40652849,40652880,40652926,40652946,40653129,40653201,40653213,40653373,40653468)').fields("_id")
collection.find(conds).fields("_id")



db.companies.find({$and:[{"valuation":{ $gt: 12804681 , $lt: 12804683}}]})

