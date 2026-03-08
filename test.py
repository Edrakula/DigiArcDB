from db_wrapper import DigiArcDB
import unittest


class TestDigiArcDB(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Connect to test database
        cls.db = DigiArcDB(password="")

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def test_user_crud(self):
        # Create user
        self.db.create_user("alice", "alice@example.com")
        user = self.db.get_user_from_name("alice")
        self.assertIsNotNone(user)
        self.assertEqual(user["username"], "alice")

        # Get user by ID
        user_by_id = self.db.get_user_from_id(user["user_id"])
        self.assertEqual(user_by_id["email"], "alice@example.com")

        # Get all users
        users = self.db.get_users()
        self.assertIn(user, users)

    def test_category_crud(self):
        self.db.create_user("category_test", "test@example.com")
        # Create category
        self.db.create_category("Tech", "Technology related docs")
        categories = self.db.get_categories()
        self.assertTrue(any(c["name"] == "Tech" for c in categories))

        # Attach/detach category
        self.db.create_document("Doc1", "Description", 1, "/tmp/doc1.txt", 1)
        docs = self.db.get_all_public_documents()
        doc_id = docs[0]["document_id"]

        self.db.attach_category(doc_id, 1)
        doc = self.db.get_document(doc_id)
        self.assertEqual(doc["category_id"], 1)

        self.db.detach_category(doc_id)
        doc = self.db.get_document(doc_id)
        self.assertIsNone(doc["category_id"])

        # Remove category
        self.db.remove_category(1)
        categories = self.db.get_categories()
        self.assertFalse(any(c["name"] == "Tech" for c in categories))

    def test_tag_crud(self):
        self.db.create_user("tag_test", "tag@example.com")
        # Create tag
        self.db.create_tag("Important")
        tags = self.db.get_tags()
        self.assertTrue(any(t["name"] == "Important" for t in tags))

        # Attach/detach tag
        self.db.create_document("Doc2", "Description2",
                                1, "/tmp/doc2.txt", None)
        doc_id = self.db.get_all_public_documents()[0]["document_id"]

        self.db.attach_tag(doc_id, 1)
        self.db.detach_tag(doc_id, 1)

        # Remove tag
        self.db.remove_tag(1)
        tags = self.db.get_tags()
        self.assertFalse(any(t["name"] == "Important" for t in tags))

    def test_document_access_and_logging(self):
        self.db.create_user("access", "tet@example.com")
        # Create a document
        self.db.create_document("Secure Doc", "Secret",
                                1, "/tmp/secure.txt", None, restricted=True)
        doc = self.db.get_all_public_documents()[0]
        doc_id = doc["document_id"]

        # Initially, user 1 cannot access (restricted)
        access_info = self.db.get_document_access_info(doc_id, 2)
        self.assertEqual(access_info, [])

        # Grant access
        self.db.create_document_access(2, doc_id, "view")
        access_info = self.db.get_document_access_info(doc_id, 2)
        self.assertTrue(len(access_info) > 0)

        # Remove access
        self.db.remove_document_access(2, doc_id, "view")
        access_info = self.db.get_document_access_info(doc_id, 2)
        self.assertEqual(access_info, [])

        # Logging
        self.db.log_access(1, doc_id, 1, "download")
        logs = self.db.get_access_logs_of_document(doc_id)
        self.assertTrue(len(logs) > 0)

        user_logs = self.db.get_user_activity(1)
        self.assertTrue(len(user_logs) > 0)

    def test_search_and_download(self):
        self.db.create_user("search", "te@example.com")
        # Search document
        self.db.create_document(
            "Python Guide", "Learn Python", 1, "/tmp/python.txt", None)
        results = self.db.search_documents("Python")
        self.assertTrue(any("Python" in r["title"] for r in results))

        # Download document
        doc_id = results[0]["document_id"]
        file_path = self.db.download_document(doc_id, user_id=1)
        self.assertIsNotNone(file_path)

    def test_document_versions_and_total_downloads(self):
        self.db.create_user("ver", "ver@example.com")
        self.db.create_document(
            "Versioned Doc", "Test Versions", 1, "/tmp/v1.txt", None)
        doc_id = self.db.get_all_public_documents()[0]["document_id"]

        versions = self.db.get_document_versions(doc_id, user_id=1)
        self.assertIsInstance(versions, list)

        downloads = self.db.total_downloads(doc_id, user_id=1)
        self.assertIsInstance(downloads, int)


if __name__ == "__main__":
    unittest.main()
