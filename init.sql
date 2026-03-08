DROP DATABASE digi_arc;
CREATE DATABASE digi_arc;
USE digi_arc;

CREATE TABLE Users (
	user_id SERIAL PRIMARY KEY,
    username VARCHAR(64) UNIQUE NOT NULL,
    email VARCHAR(128) UNIQUE NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Categories (
	category_id SERIAL PRIMARY KEY,
	name VARCHAR(64) UNIQUE NOT NULL,
	description TEXT
);

CREATE TABLE Documents (
	document_id SERIAL PRIMARY KEY,
	title VARCHAR(64) NOT NULL,
    description TEXT,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED,
    
    restricted BOOL NOT NULL DEFAULT FALSE,
    
    downloads INT UNSIGNED DEFAULT 0,
    
    FOREIGN KEY (uploaded_by) REFERENCES Users(user_id)
		ON DELETE CASCADE,
        
	FOREIGN KEY (category_id) REFERENCES Categories(category_id)
		ON DELETE SET NULL
);


CREATE TABLE Document_Access (
	user_id BIGINT UNSIGNED NOT NULL,
    document_id BIGINT UNSIGNED NOT NULL,
    access_level VARCHAR(20) NOT NULL CHECK(access_level IN ('view', 'edit')),
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
		ON DELETE CASCADE,

	FOREIGN KEY (document_id) REFERENCES Documents(document_id)
		ON DELETE CASCADE,
    
    PRIMARY KEY (user_id, document_id, access_level)
);

CREATE TABLE Tags (
	tag_id SERIAL PRIMARY KEY,
	name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE Document_Tags (
	document_id BIGINT UNSIGNED NOT NULL,
    tag_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (document_id, tag_id),
    
    FOREIGN KEY (document_id) REFERENCES Documents(document_id)
		ON DELETE CASCADE,
    
    FOREIGN KEY (tag_id) REFERENCES Tags(tag_id)
		ON DELETE CASCADE
);

CREATE TABLE Versions (
	version_id SERIAL PRIMARY KEY,
    version_number INT NOT NULL,
    document_id BIGINT UNSIGNED NOT NULL,
    file_path TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    uploaded_by_user_id BIGINT UNSIGNED NOT NULL,
    
    FOREIGN KEY (uploaded_by_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
    
    restricted BOOL NOT NULL DEFAULT FALSE,
    
    FOREIGN KEY (document_id) REFERENCES Documents(document_id)
		ON DELETE CASCADE,
     
	UNIQUE(document_id, version_number)
);

CREATE TABLE Contributors (
	contributor_id SERIAL PRIMARY KEY,
	user_id BIGINT UNSIGNED NOT NULL,
    document_id BIGINT UNSIGNED NOT NULL,
    version_id BIGINT UNSIGNED NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
		ON DELETE CASCADE,

	FOREIGN KEY (document_id) REFERENCES Documents(document_id)
		ON DELETE CASCADE,
        
	FOREIGN KEY (version_id) REFERENCES Versions(version_id)
		ON DELETE CASCADE,
        
	UNIQUE (user_id, document_id, version_id)
    
);

CREATE TABLE Access_Log (
	log_id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    document_id BIGINT UNSIGNED NOT NULL,
    version_id BIGINT UNSIGNED NOT NULL,
    
    access_type VARCHAR(32) NOT NULL CHECK(access_type IN ('download', 'created')),
    
    access_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,

	FOREIGN KEY (document_id) REFERENCES Documents(document_id)
		ON DELETE RESTRICT,
        
	FOREIGN KEY (version_id) REFERENCES Versions(version_id)
		ON DELETE RESTRICT
);


CREATE VIEW Public_Documents AS
	SELECT 	d.document_id,
			d.title,
            d.description,
            d.upload_date,
            d.uploaded_by,
            c.name as category_name,
            c.description as category_description,
            d.downloads,
            GROUP_CONCAT(t.name) as tags
    FROM Documents d
    LEFT JOIN Categories c ON d.category_id = c.category_id
    LEFT JOIN Document_Tags dt ON d.document_id = dt.document_id
    LEFT JOIN Tags t ON dt.tag_id = t.tag_id
    WHERE NOT restricted
    GROUP BY 
		d.document_id,
		d.title,
		d.description,
		d.upload_date,
		d.uploaded_by,
		c.name,
		c.description,
		d.downloads;


DELIMITER //
CREATE TRIGGER update_total_downloads
BEFORE INSERT ON Access_Log
FOR EACH ROW
BEGIN
	IF NEW.access_type = 'download' THEN
		UPDATE Documents SET downloads = downloads + 1 WHERE document_id = NEW.document_id;
    END IF;
END//
DELIMITER ;



DELIMITER //
CREATE FUNCTION total_downloads(p_doc_id BIGINT UNSIGNED, p_user_id BIGINT UNSIGNED)
RETURNS INT
READS SQL DATA
BEGIN
	IF (SELECT restricted from Documents WHERE document_id = p_doc_id) = 0 THEN
		RETURN (SELECT COUNT(*) FROM Access_Log WHERE document_id = p_doc_id AND access_type = 'download');
    END IF;
    IF (SELECT COUNT(*) FROM Document_Access WHERE user_id = p_user_id AND document_id = p_doc_id) = 0 THEN
		return 0;
    END IF;
    RETURN (SELECT COUNT(*) FROM Access_Log WHERE document_id = p_doc_id AND access_type = 'download');
END //
DELIMITER ;



# can create concurrency problem, but only side effect is one upload fails, and can be tried again after
# since the use case the likelihood is low, and you can just try the insert again
DELIMITER //
CREATE TRIGGER auto_increment_version
BEFORE INSERT ON Versions
FOR EACH ROW
BEGIN
	SET NEW.version_number = (SELECT IFNULL(MAX(version_number), 0) + 1 FROM Versions WHERE document_id = NEW.document_id);
END//
DELIMITER ;



DELIMITER //
CREATE TRIGGER Log_Version_Creation
AFTER INSERT ON Versions
FOR EACH ROW
BEGIN
    INSERT INTO Access_log(user_id, document_id, version_id, access_type)
		VALUES(NEW.uploaded_by_user_id, NEW.document_id, NEW.version_id, 'created');
END//
DELIMITER ;



DELIMITER //
CREATE PROCEDURE Create_Document(
	p_title VARCHAR(64),
	p_description TEXT,
    p_user BIGINT UNSIGNED,
    p_filepath TEXT,
    p_category BIGINT UNSIGNED,
    p_restricted BOOL,
    IN p_contributors JSON
)
BEGIN
	DECLARE new_doc_id BIGINT UNSIGNED;
    DECLARE new_ver_id BIGINT UNSIGNED;
	DECLARE n INT;
    DECLARE i INT DEFAULT 0;
    DECLARE current_id BIGINT UNSIGNED;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
        RESIGNAL;
	END;
    START TRANSACTION;
    

    INSERT INTO Documents(title, description, uploaded_by, category_id, restricted)
		VALUES(p_title, p_description, p_user, p_category, p_restricted);
	SET new_doc_id = LAST_INSERT_ID();
        
	INSERT INTO Versions(document_id, file_path, uploaded_by_user_id, restricted)
		VALUES(new_doc_id, p_filepath, p_user, p_restricted);
	SET new_ver_id = LAST_INSERT_ID();
    
	SET n = IFNULL(JSON_LENGTH(p_contributors), 0);
    WHILE i < n DO
		SET current_id = 
			CAST(JSON_UNQUOTE(JSON_EXTRACT(p_contributors, CONCAT('$[', i, ']'))) AS UNSIGNED);
            
        INSERT INTO Contributors(user_id, document_id, version_id)
			VALUES (current_id, new_doc_id, new_ver_id);
        SET i = i + 1;
    END WHILE;
	
    COMMIT;
    
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE Update_Document(
	IN p_document_id BIGINT UNSIGNED,
    IN p_user BIGINT UNSIGNED,
    IN p_filepath TEXT,
    IN p_restricted BOOL,
    IN p_contributors JSON
)
proc: BEGIN
	DECLARE new_ver_id BIGINT UNSIGNED;
	DECLARE n INT;
    DECLARE i INT DEFAULT 0;
    DECLARE current_id BIGINT UNSIGNED;
    DECLARE v_restricted BOOL;
    DECLARE has_edit_access BOOL;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
        RESIGNAL;
	END;
	START TRANSACTION;

	SELECT restricted
		INTO v_restricted
		FROM Documents
		WHERE document_id = p_document_id;

	SELECT EXISTS(
			SELECT 1
				FROM Document_Access
				WHERE document_id = p_document_id
				AND user_id = p_user
				AND access_level = 'edit'
		)
		INTO has_edit_access;

	IF v_restricted AND NOT has_edit_access THEN
		ROLLBACK;
		LEAVE proc;
	END IF;


	INSERT INTO Versions(document_id, file_path, uploaded_by_user_id, restricted)
		VALUES(p_document_id, p_filepath, p_user, p_restricted);
	SET new_ver_id = LAST_INSERT_ID();
        
    SET n = IFNULL(JSON_LENGTH(p_contributors), 0);
    WHILE i < n DO
		SET current_id = 
			CAST(JSON_UNQUOTE(JSON_EXTRACT(p_contributors, CONCAT('$[', i, ']'))) AS UNSIGNED);
            
        INSERT INTO Contributors(user_id, document_id, version_id)
			VALUES (current_id, p_document_id, new_ver_id);
        SET i = i + 1;
    END WHILE;
    
    
    COMMIT;
	
END proc //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE Get_All_Document_Versions(
	IN p_document_id BIGINT UNSIGNED,
    IN p_user_id BIGINT UNSIGNED
)
BEGIN
	SELECT v.version_number AS version_number, v.file_path AS file_path, DATE_FORMAT(v.created_at, '%Y-%m-%d %H:%i:%s') AS creation_time , uu.username AS uploader, GROUP_CONCAT(u.username SEPARATOR ', ') AS contributors, COUNT(u.user_id) AS contributor_count
    FROM Versions v 
    LEFT JOIN Contributors c ON v.version_id = c.version_id
    LEFT JOIN Users u ON c.user_id = u.user_id
    LEFT JOIN Users uu ON v.uploaded_by_user_id = uu.user_id
    WHERE 
		v.document_id = p_document_id 
        AND (
			v.restricted = 0 OR (
				p_user_id IS NOT NULL
                AND EXISTS (
					SELECT 1 FROM Document_Access da
                    WHERE da.document_id = v.document_id
                    AND da.user_id = p_user_id
                )
            )
        )
    GROUP BY v.version_id
    ORDER BY version_number DESC;
    
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE Get_All_Restricted_Documents_With_Access(
    IN p_user_id BIGINT UNSIGNED
)
BEGIN
	SELECT 	d.document_id,
			d.title,
            d.description,
            d.upload_date,
            d.uploaded_by,
            c.name as category_name,
            c.description as category_description,
            d.downloads,
            GROUP_CONCAT(DISTINCT t.name) as tags,
            GROUP_CONCAT(DISTINCT da.access_level) as access_level
    FROM Documents d
    LEFT JOIN Categories c ON d.category_id = c.category_id
    LEFT JOIN Document_Tags dt ON d.document_id = dt.document_id
    LEFT JOIN Tags t ON dt.tag_id = t.tag_id
    JOIN Document_Access da ON da.document_id = d.document_id
    WHERE restricted AND da.user_id = p_user_id
    GROUP BY 
		d.document_id,
		d.title,
		d.description,
		d.upload_date,
		d.uploaded_by,
		c.name,
		c.description,
		d.downloads;
    
END //
DELIMITER ;

