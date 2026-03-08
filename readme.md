## DigiArcDB Python Interface
DigiArcDB is a Python class that provides an easy-to-use interface for interacting with a MySQL database for document management, users, categories, tags, and access logging. It wraps SQL queries, stored procedures, and functions in Python methods, offering a high-level API for document archiving workflows.

for instalisaiton need to run
    pip install mysql-connector-python

# Database Setup

The repository includes an init.sql file to create the database and all required tables, functions, and stored procedures.

# Run the SQL file to initialize the database
mysql -u root -p < init.sql

This will create the digi_arc database with tables: Users, Documents, Categories, Tags, Document_Access, Access_log, Versions, Public_Documents.

It also creates stored procedures: Create_Document, Update_Document, Get_All_Document_Versions.

Functions like total_downloads are included.

Initialization
from digi_arc_db import DigiArcDB

# Connect to the database
db = DigiArcDB(
    host="localhost",
    user="root",
    password="password",
    database="digi_arc"
)

# Close the connection when done
db.close()
User Management
# Create a new user
db.create_user("alice", "alice@example.com")

# Get user by name
user = db.get_user_from_name("alice")

# Get user by ID
user = db.get_user_from_id(1)

# Get all users
users = db.get_users()
Category Management
# Create a category
db.create_category("Finance", "Documents related to finance")

# List all categories
categories = db.get_categories()

# Remove a category
db.remove_category(category_id=1)

# Attach/detach a category to/from a document
db.attach_category(document_id=2, category_id=1)
db.detach_category(document_id=2)
Tag Management
# Create a tag
db.create_tag("Important")

# List all tags
tags = db.get_tags()

# Remove a tag
db.remove_tag(tag_id=1)

# Attach/detach a tag to/from a document
db.attach_tag(document_id=2, tag_id=1)
db.detach_tag(document_id=2, tag_id=1)
Document Management
# Create a new document
db.create_document(
    title="Project Plan",
    description="Initial project plan",
    user_id=1,
    filepath="/docs/project_plan.pdf",
    category="Planning",
    restricted=False,
    contributors=[2, 3]
)

# Update an existing document
db.update_document(
    document_id=1,
    user_id=1,
    filepath="/docs/project_plan_v2.pdf",
    restricted=True,
    contributors=[2, 3]
)

# Get document details
document = db.get_document(document_id=1, user_id=1)

# Get all public documents
public_docs = db.get_all_public_documents()

# Get document versions
versions = db.get_document_versions(document_id=1, user_id=1)

# Download a document
file_path = db.download_document(document_id=1, version_number=2, user_id=1)
Access Control
# Grant access to a document
db.create_document_access(user_id=2, document_id=1, access_level="read")

# Remove access
db.remove_document_access(user_id=2, document_id=1, access_level="read")

# Get access info for a document
access_info = db.get_document_access_info(document_id=1, user_id=2)
Logging and Activity
# Log an access event manually
db.log_access(user_id=1, document_id=1, version_id=2, access_type="download")

# Get all access logs for a document
logs = db.get_access_logs_of_document(document_id=1)

# Get all activity for a user
activity = db.get_user_activity(user_id=1)
Search and Downloads
# Search documents by keyword
results = db.search_documents("budget")

# Get total downloads of a document
downloads = db.total_downloads(document_id=1, user_id=1)
Notes

Restricted documents require a valid user with the proper access level for viewing or downloading.

contributors are stored as JSON arrays in the database when creating/updating documents.

Stored procedures (Create_Document, Update_Document, Get_All_Document_Versions) are required for full functionality.

Access logs track user interactions with documents, including version downloads.