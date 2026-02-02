# Copyright 2024 Google LLC
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file or at
# https://developers.google.com/open-source/licenses/bsd

from django.contrib.auth.models import Group
from django.test import TransactionTestCase

class SecondaryDBAutoFieldTest(TransactionTestCase):
    # Only use 'other' database (SQLite) for this test to avoid Spanner connection attempts
    # while 'default' remains configured as Spanner (in settings.py).
    databases = {'other'}
    
    @classmethod
    def _fixture_setup(cls):
        # Override to skip the default database flush.
        # Since we are using an isolated secondary database ('other') without running global migrations,
        # standard Django flushing would fail with "CommandError: Database :memory: couldn't be flushed"
        # because the expected tables do not exist yet.
        pass

    @classmethod
    def _fixture_teardown(cls):
        # Skip flush for the same reason as _fixture_setup.
        pass

    def test_autofield_population_on_secondary_db(self):
        """
        Ensure that saving a model with AutoField/BigAutoField to a secondary (non-Spanner) database
        populates the primary key correctly, even when Spanner is the default DB.
        """
        from django.db import models
        from django.db import connections

        # Define a model dynamically to match the issue reproduction (BigAutoField)
        class TestModel(models.Model):
            id = models.BigAutoField(primary_key=True)
            name = models.CharField(max_length=100)
            class Meta:
                app_label = 'django_spanner' # reuse an existing app label

        # Manually create table in 'other' DB
        with connections['other'].schema_editor() as editor:
            editor.create_model(TestModel)

        # Create instance on 'other' database
        instance = TestModel(name='test_instance')
        instance.save(using='other')

        # The ID should be populated
        self.assertIsNotNone(instance.id, "Instance ID should be populated after save on secondary DB")
        # Additionally, verify it was saved
        self.assertTrue(TestModel.objects.using('other').filter(pk=instance.id).exists())
