package com.erp.approval.service;

import org.springframework.data.mongodb.core.MongoOperations;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import static org.springframework.data.mongodb.core.FindAndModifyOptions.options;
import static org.springframework.data.mongodb.core.query.Criteria.where;
import static org.springframework.data.mongodb.core.query.Query.query;

@Service
public class SequenceGeneratorService {
    
    private final MongoOperations mongoOperations;
    
    public SequenceGeneratorService(MongoOperations mongoOperations) {
        this.mongoOperations = mongoOperations;
    }
    
    public int generateSequence(String seqName) {
        DatabaseSequence counter = mongoOperations.findAndModify(
                query(where("_id").is(seqName)),
                new Update().inc("seq", 1),
                options().returnNew(true).upsert(true),
                DatabaseSequence.class);
        
        // upsert 시 seq가 null이면 1 반환 (첫 생성)
        if (counter == null || counter.getSeq() == 0) {
            // 명시적으로 1로 설정
            mongoOperations.findAndModify(
                    query(where("_id").is(seqName)),
                    new Update().set("seq", 1),
                    options().returnNew(true).upsert(true),
                    DatabaseSequence.class);
            return 1;
        }
        
        return counter.getSeq();
    }
    
    public static class DatabaseSequence {
        private String id;
        private int seq;
        
        public String getId() { return id; }
        public void setId(String id) { this.id = id; }
        public int getSeq() { return seq; }
        public void setSeq(int seq) { this.seq = seq; }
    }
}
