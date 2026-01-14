# Copyright 2025 Google LLC All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import tests.mockserver_tests.spanner_instance_admin_pb2_grpc as instance_admin_grpc
from google.cloud.spanner_admin_instance_v1 import Instance

class InstanceAdminServicer(instance_admin_grpc.InstanceAdminServicer):
    def __init__(self):
        self._requests = []

    @property
    def requests(self):
        return self._requests

    def clear_requests(self):
        self._requests = []

    def GetInstance(self, request, context):
        self._requests.append(request)
        return Instance(name=request.name)
