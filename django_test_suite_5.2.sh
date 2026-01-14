#!/bin/sh

# Copyright (c) 2020 Google LLC. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -ex

if [ -n "$CI" ]; then
    sudo -E apt-get update -y
    sudo -E apt-get install -y libmemcached-dev
fi

# Disable buffering, so that the logs stream through.
export PYTHONUNBUFFERED=1

export DJANGO_TESTS_DIR="django_tests_dir"
mkdir -p $DJANGO_TESTS_DIR

if [ $SPANNER_EMULATOR_HOST != 0 ]
then
    pip3 install --upgrade pip setuptools
    pip3 install . --no-build-isolation
    if [ ! -d "$DJANGO_TESTS_DIR/django5.2" ]; then
        git clone --depth 1 --single-branch --branch "stable/5.2.x" https://github.com/django/django.git $DJANGO_TESTS_DIR/django5.2
    fi
fi

# Install dependencies for Django tests.
if [ -n "$CI" ]; then
    sudo -E apt-get update
    sudo -E apt-get install -y libffi-dev libjpeg-dev zlib1g-dev
fi

cd $DJANGO_TESTS_DIR/django5.2
pip3 install -e . --no-build-isolation
# Ignore dependency failures for now (pylibmc) and ensure we return to root
pip3 install -r tests/requirements/py3.txt || true
cd ../../

python3 create_test_instance.py

# If no SPANNER_TEST_DB is set, generate a unique one
# so that we can have multiple tests running without
# conflicting which changes and constraints. We'll always
# cleanup the created database.
TEST_DBNAME=${SPANNER_TEST_DB:-$(python3 -c 'import os, time; print(chr(ord("a") + time.time_ns() % 26)+os.urandom(10).hex())')}
TEST_DBNAME_OTHER="$TEST_DBNAME-ot"
INSTANCE=${SPANNER_TEST_INSTANCE:-django-tests}
PROJECT=${PROJECT_ID}
SETTINGS_FILE="$TEST_DBNAME-settings"
TESTS_DIR=${DJANGO_TESTS_DIR:-django_tests}

create_settings() {
    cat << ! > "$SETTINGS_FILE.py"
import django_spanner
from django.utils.translation import gettext_lazy as _
DATABASES = {
   'default': {
       'ENGINE': 'django_spanner',
       'PROJECT': "$PROJECT",
       'INSTANCE': "$INSTANCE",
       'NAME': "$TEST_DBNAME",
       'OPTIONS': {'use_native_uuid': True},
   },
   'other': {
       'ENGINE': 'django_spanner',
       'PROJECT': "$PROJECT",
       'INSTANCE': "$INSTANCE",
       'NAME': "$TEST_DBNAME_OTHER",
       'OPTIONS': {'use_native_uuid': True},
   },

}
DEBUG = True
USE_TZ = False
SECRET_KEY = 'spanner_tests_secret_key'
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]
DEFAULT_AUTO_FIELD = 'django.db.models.AutoField'
!
}

cd $TESTS_DIR/django5.2/tests
create_settings

EXIT_STATUS=0
for DJANGO_TEST_APP in $DJANGO_TEST_APPS
do
   python3 runtests.py $DJANGO_TEST_APP --verbosity=3 --noinput --settings $SETTINGS_FILE || EXIT_STATUS=$?
done
exit $EXIT_STATUS
