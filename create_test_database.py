from google.cloud import spanner
import os

project = os.getenv('GOOGLE_CLOUD_PROJECT', 'emulator-test-project')
instance_id = os.getenv('SPANNER_TEST_INSTANCE', 'google-cloud-django-backend-tests')
db_name = 'foreign_key_test_db'

client = spanner.Client(project=project)
instance = client.instance(instance_id)
database = instance.database(db_name)

if not database.exists():
    operation = database.create()
    operation.result(120)  # Wait for creation
