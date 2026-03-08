import mysql.connector
import json


class DigiArcDB:
    def __init__(self, host="localhost", user="root", password="", database="digi_arc"):
        self.conn = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            database=database
        )
        self.cursor = self.conn.cursor(dictionary=True)
        return

    def close(self):
        self.cursor.close()
        self.conn.close()
        return

    # ----------------------------- SIMPLE QUORIES -------------------------------

    def get_user_from_name(self, name):
        self.cursor.execute(
            "SELECT user_id, username, email, created_at FROM Users WHERE username = %s",
            (name,))
        return self.cursor.fetchone()

    def get_user_from_id(self, user_id):
        self.cursor.execute(
            "SELECT user_id, username, email, created_at FROM Users WHERE user_id = %s",
            (user_id,))
        return self.cursor.fetchone()

    def create_user(self, username, email):
        self.cursor.execute(
            """
                INSERT INTO Users(username, email)
                VALUES(%s, %s)
            """,
            (username, email)
        )
        self.conn.commit()
        return

    def get_categories(self):
        self.cursor.execute(
            "SELECT category_id, name, description FROM Categories ORDER BY name"
        )
        return self.cursor.fetchall()

    def create_category(self, name, description):
        self.cursor.execute(
            """
                INSERT INTO Categories(name, description)
                VALUES(%s, %s)
            """,
            (name, description)
        )
        self.conn.commit()
        return

    def remove_category(self, category_id):
        self.cursor.execute(
            """
                DELETE FROM Categories
                WHERE category_id = %s
            """,
            (category_id,)
        )
        self.conn.commit()
        return

    def attach_category(self, document_id, category_id):
        self.cursor.execute(
            """
                UPDATE Documents
                SET category_id = %s
                WHERE document_id = %s
            """,
            (category_id, document_id)
        )
        self.conn.commit()
        return

    def detach_category(self, document_id):
        self.cursor.execute(
            """
                UPDATE Documents
                SET category_id = NULL
                WHERE document_id = %s
            """,
            (document_id,)
        )
        self.conn.commit()
        return

    def get_users(self):
        self.cursor.execute(
            "SELECT user_id, username, email, created_at FROM Users")
        return self.cursor.fetchall()

    def get_all_public_documents(self):
        self.cursor.execute("SELECT * FROM Public_Documents")
        return self.cursor.fetchall()

    def get_document(self, document_id, user_id=None):
        self.cursor.execute("SELECT * From Documents WHERE document_id = %s",
                            (document_id,)
                            )
        document = self.cursor.fetchone()
        if not document:
            return None
        if not document["restricted"]:
            return document

        access_level = self.get_document_access_info(
            document_id, user_id)
        if access_level.__len__() == 0:
            return None
        return document

    def get_document_access_info(self, document_id, user_id):
        self.cursor.execute("SELECT access_level FROM Document_Access WHERE document_id = %s AND user_id = %s",
                            (document_id, user_id)
                            )
        access_level = self.cursor.fetchall()
        return access_level

    def create_document_access(self, user_id, document_id, access_level):
        self.cursor.execute(
            """
                INSERT INTO Document_Access(user_id, document_id, access_level)
                VALUES(%s, %s, %s)
            """,
            (user_id, document_id, access_level)
        )
        self.conn.commit()
        return

    def remove_document_access(self, user_id, document_id, access_level):
        self.cursor.execute(
            """
                DELETE FROM Document_Access
                WHERE user_id = %s AND document_id = %s AND access_level = %s
            """,
            (user_id, document_id, access_level)
        )
        self.conn.commit()
        return

    def get_tags(self):
        self.cursor.execute(
            "SELECT tag_id, name FROM Tags ORDER BY name"
        )
        return self.cursor.fetchall()

    def create_tag(self, name):
        self.cursor.execute(
            """
                INSERT INTO Tags(name)
                VALUES(%s)
            """,
            (name,)
        )
        self.conn.commit()
        return

    def remove_tag(self, tag_id):
        self.cursor.execute(
            """
                DELETE FROM Tags
                WHERE tag_id = %s
            """,
            (tag_id,)
        )
        self.conn.commit()
        return

    def attach_tag(self, document_id, tag_id):
        self.cursor.execute(
            """
                INSERT INTO Document_Tags(document_id, tag_id)
                VALUES(%s, %s)
            """,
            (document_id, tag_id)
        )
        self.conn.commit()
        return

    def detach_tag(self, document_id, tag_id):
        self.cursor.execute(
            """
                DELETE FROM Document_Tags
                WHERE document_id = %s AND tag_id = %s
            """,
            (document_id, tag_id)
        )
        self.conn.commit()
        return

    def get_access_logs_of_document(self, document_id):
        self.cursor.execute("""
            SELECT  al.log_id,
                    al.user_id,
                    u.username,
                    al.document_id,
                    d.title,
                    al.version_id,
                    v.version_number,
                    al.access_type,
                    al.access_time
                FROM Access_log al
                    LEFT JOIN Users u ON al.user_id = u.user_id
                    LEFT JOIN Documents d ON al.document_id = d.document_id
                    LEFT JOIN Versions v ON al.version_id = v.version_id
                WHERE al.document_id = %s
                ORDER BY al.access_time DESC
            """, (document_id, )
        )
        return self.cursor.fetchall()

    def get_user_activity(self, user_id):
        self.cursor.execute("""
            SELECT  al.log_id,
                    al.user_id,
                    u.username,
                    al.document_id,
                    d.title,
                    al.version_id,
                    v.version_number,
                    al.access_type,
                    al.access_time
                FROM Access_log al
                    LEFT JOIN Users u ON al.user_id = u.user_id
                    LEFT JOIN Documents d ON al.document_id = d.document_id
                    LEFT JOIN Versions v ON al.version_id = v.version_id
                WHERE al.user_id = %s
                ORDER BY al.access_time DESC
            """, (user_id, )
        )
        return self.cursor.fetchall()

    def search_documents(self, keyword):
        pattern = f"%{keyword}%"

        self.cursor.execute("""
            SELECT document_id, title, description, category_id, restricted
                FROM Documents
                WHERE title LIKE %s
                OR description LIKE %s
            """, (pattern, pattern,)
        )
        return self.cursor.fetchall()

    # ----------------------------- Procedures -------------------------------

    def create_document(self, title, description, user_id, filepath, category, restricted=False, contributors=None):
        if contributors is None:
            contributors = []
        self.cursor.callproc("Create_Document", (
            title,
            description,
            user_id,
            filepath,
            category,
            restricted,
            json.dumps(contributors)
        ))

        self.conn.commit()
        return

    def update_document(self, document_id, user_id, filepath, restricted=False, contributors=None):
        if contributors is None:
            contributors = []
        self.cursor.callproc("Update_Document", (
            document_id,
            user_id,
            filepath,
            restricted,
            json.dumps(contributors)
        ))

        self.conn.commit()
        return

    def get_document_versions(self, document_id, user_id=None):
        self.cursor.callproc("Get_All_Document_Versions",
                             (document_id, user_id)
                             )

        for result in self.cursor.stored_results():
            return result.fetchall()

        return []

    # ----------------------------- Functions -------------------------------

    def total_downloads(self, document_id, user_id=None):
        self.cursor.execute(
            "SELECT total_downloads(%s, %s) AS downloads", (document_id, user_id))

        return self.cursor.fetchone()["downloads"]

    # ----------------------------- logging -------------------------------

    def log_access(self, user_id, document_id, version_id, access_type):
        self.cursor.execute("""
            INSERT INTO Access_log (user_id, document_id, version_id, access_type)
            VALUES (%s, %s, %s, %s)
            """, (user_id, document_id, version_id, access_type))

        self.conn.commit()
        return

    # ----------------------------- Python Logic -------------------------------

    def download_document(self, document_id, version_number=None, user_id=None):
        if version_number is None:
            self.cursor.execute("""
                                SELECT version_id, file_path, restricted
                                FROM Versions
                                WHERE document_id = %s
                                ORDER BY version_number DESC
                                LIMIT 1
                                """, (document_id, ))
        else:
            self.cursor.execute("""
                                SELECT version_id, file_path, restricted
                                FROM Versions
                                WHERE document_id = %s AND version_number = %s
                                """, (document_id, version_number))

        version = self.cursor.fetchone()

        if not version:
            return None

        if version["restricted"]:
            if not user_id:
                return None
            access = self.get_document_access_info(document_id, user_id)
            if not access:
                return None

        self.log_access(user_id, document_id,
                        version["version_id"], "download")

        return version["file_path"]
