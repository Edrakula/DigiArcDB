
INSERT INTO Users (username, email) VALUES
('alice', 'alice@test.com'),
('bob', 'bob@test.com'),
('charlie', 'charlie@test.com'),
('diana', 'diana@test.com'),
('erik', 'erik@test.com'),
('fatima', 'fatima@test.com'),
('gabriel', 'gabriel@test.com'),
('hana', 'hana@test.com');


INSERT INTO Categories (name, description) VALUES
('Research', 'Academic research papers'),
('Reports', 'Internal company reports'),
('Manuals', 'Instruction manuals'),
('Legal', 'Legal documentation'),
('Media', 'Images, videos and multimedia');


INSERT INTO Tags (name) VALUES
('AI'),
('Database'),
('Security'),
('Finance'),
('Machine Learning'),
('Internal');


CALL Create_Document(
'AI Whitepaper',
'Research paper on AI advancements',
1,
'/files/ai_whitepaper_v1.pdf',
1,
FALSE,
'[2,3]'
);



CALL Create_Document(
'Company Financial Report 2025',
'Annual financial report',
2,
'/files/finance_report_v1.pdf',
2,
TRUE,
'[1,4]'
);


CALL Create_Document(
'Database Optimization Guide',
'Guide for database performance tuning',
3,
'/files/db_guide_v1.pdf',
3,
FALSE,
'[2,5]'
);


CALL Create_Document(
'Security Policy',
'Internal security guidelines',
4,
'/files/security_policy_v1.pdf',
4,
TRUE,
'[1,6]'
);



CALL Create_Document(
'ML Model Documentation',
'Documentation for ML model architecture',
5,
'/files/ml_docs_v1.pdf',
1,
FALSE,
'[3,7]'
);

CALL Update_Document(
1,
3,
'/files/ai_whitepaper_v2.pdf',
FALSE,
'[1,2,3]'
);

CALL Update_Document(
3,
5,
'/files/db_guide_v2.pdf',
FALSE,
'[2,3,5]'
);


CALL Update_Document(
5,
7,
'/files/ml_docs_v2.pdf',
FALSE,
'[3,5,7]'
);

INSERT INTO Document_Tags VALUES
(1,1),
(1,5),
(2,4),
(3,2),
(3,6),
(4,3),
(5,1),
(5,5);

INSERT INTO Document_Access VALUES
(1,2,'view'),
(4,2,'edit'),
(3,4,'view'),
(6,4,'view'),
(5,1,'edit'),
(2,3,'view');


INSERT INTO Access_Log (user_id, document_id, version_id, access_type) VALUES
(2,1,1,'download'),
(3,1,2,'download'),
(5,3,4,'download'),
(7,5,6,'download'),
(1,3,4,'download'),
(1,2,1,'download'),
(2,5,6,'download');


INSERT INTO Document_Access VALUES(4,7, 'edit');

CALL Update_Document(
4,
6,
'/files/ml_docs_v2.pdf',
FALSE,
'[3,5,7]'
);

SELECT * FROM Document_Access WHERE document_id = 4;

CALL Get_All_Document_Versions(4,6);

SELECT * FROM Access_log;

SELECT * FROM Public_Documents;

CALL Get_All_Document_Versions(1, NULL);
CALL Get_All_Restricted_Documents_With_Access(1);


SELECT total_downloads(3, NULL);

SELECT d.title, t.name
FROM Documents d
JOIN Document_Tags dt ON d.document_id = dt.document_id
JOIN Tags t ON dt.tag_id = t.tag_id;