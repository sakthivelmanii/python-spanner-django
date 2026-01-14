#!/bin/sh
set -e

# Disable buffering
export PYTHONUNBUFFERED=1

# Install dependencies
pip install --upgrade pip setuptools
pip install . --no-build-isolation
pip install "django~=5.2"

# Create Spanner Instance and Database
python3 create_test_instance.py

python3 create_test_database.py




# Create Django Project
if [ -d "django_test" ]; then
    rm -rf django_test
fi

# Ensure cleanup on exit
trap "rm -rf django_test" EXIT

mkdir django_test
cd django_test

django-admin startproject foreign_keys
cd foreign_keys
python3 manage.py startapp applic

# Define Models
cat <<EOF > applic/models.py
from django.db import models

class Country(models.Model):
    name = models.CharField(max_length=32)

class City(models.Model):
    name = models.CharField(max_length=32)
    country = models.ForeignKey(Country, on_delete=models.DO_NOTHING)
EOF

# Define Tests
cat <<EOF > applic/tests.py
from django.test import TestCase
from .models import City, Country

class EnqueuedRoutesTest(TestCase):
    databases = {'default'} 
    
    def setUp(self):
        self.country = Country.objects.create(name='Country123')
        self.city = City.objects.create(name='City123', country=self.country)
    
    def test_foreign_key(self):
        city = City.objects.get(pk=self.city.pk)
        self.assertEqual(city.country, Country.objects.get(pk=self.country.pk))
EOF

# Configure Settings
cat <<EOF >> foreign_keys/settings.py

import os

INSTALLED_APPS.append('applic.apps.ApplicConfig')
INSTALLED_APPS.append('django_spanner')

# Spanner Settings
PROJECT = os.getenv('GOOGLE_CLOUD_PROJECT', 'emulator-test-project')
INSTANCE = os.getenv('SPANNER_TEST_INSTANCE', 'google-cloud-django-backend-tests')
DB_NAME = 'foreign_key_test_db'

DATABASES = {
    'default': {
        'ENGINE': 'django_spanner',
        'PROJECT': PROJECT,
        'INSTANCE': INSTANCE,
        'NAME': DB_NAME,
        'OPTIONS': {},
    }
}
EOF

# Run Migrations and Tests
python3 manage.py makemigrations
python3 manage.py test applic
