# Common Request model

import base64
import uuid

ADMIN_AUTH = base64.b64encode(bytes('admin:{0}'.format(uuid.uuid4()), 'utf-8')).decode('utf-8')
USER_AUTH = base64.b64encode(bytes('alex:{0}'.format(uuid.uuid4()), 'utf-8')).decode('utf-8')


class Request:

    def __init__(self, method, url, user, params=None, json=None, auth=None):
        if params is None:
            params = {}
        self.method = method
        self.url = url
        self.params = params
        self.json = json
        self.auth = auth
        self.headers = Request.make_headers(user)

    @staticmethod
    def make_user(admin, err=None):
        if err == 'not_authenticated':
            user = None
        elif admin and err != 'not_authorized':
            user = 'admin'
        else:
            user = 'alex'
        return user

    @staticmethod
    def make_headers(user):
        headers = {}
        if user == 'admin':
            headers['Authorization'] = ADMIN_AUTH
        elif user:
            headers['Authorization'] = USER_AUTH
        headers['Accept'] = 'application/json'
        return headers
