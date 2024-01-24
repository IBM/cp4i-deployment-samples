# Requests on the Customer resource

import uuid

from .customers import customer_generator
from .request import Request


def make_customer_id(config, err=None):
    id = str(uuid.uuid4())
    if err == 'invalid_input':
        # make the UUID invalid
        id = id.replace('-', '.')
    elif err == 'not_found':
        return id
    else:
        id = config.customers_database.get_random_key()
    return id


def clean_customer(customer):
    """Ensure that a customer has no error markers"""

    # Username starting 'rob' is assumed to be already taken
    if customer['username'].startswith('rob'):
        customer['username'] = 'x' + customer['username']

    # Username starting 'james' is assumed to be a change
    if customer['username'].startswith('james'):
        customer['username'] = 'x' + customer['username']

    pass


def set_invalid_input(customer):
    customer['email'] = customer['email'].replace('@', '.')


def set_exists(customer):
    customer['username'] = 'rob' + customer['username'][1:]


def set_invalid_update(customer):
    customer['username'] = 'james' + customer['username'][1:]


def gen_post(config, customers):
    err = config.random_error('customers', 'post')

    url = config.customers_url
    user = Request.make_user(True, err)
    customer = next(customers)

    # add errors according to the configuration
    if err == 'invalid_input':
        set_invalid_input(customer)
    elif err == 'exists':
        set_exists(customer)

    req = Request('POST', url, user, json=customer)
    return req


def gen_get(config):
    err = config.random_error('customers', 'get')

    customer_id = make_customer_id(config, err)
    url = '{0}/{1}'.format(config.customers_url, customer_id)
    user = Request.make_user(False, err)

    req = Request('GET', url, user)
    return req


def gen_put(config):
    err = config.random_error('customers', 'put')

    customer_id = make_customer_id(config, err)
    url = '{0}/{1}'.format(config.customers_url, customer_id)
    user = Request.make_user(True, err)
    customer, customer_data = config.customers_database.get_random_row()
    customer_data['customer_id'] = customer_id
    clean_customer(customer_data)

    # add errors according to the configuration
    if err == 'invalid_update':
        set_invalid_update(customer_data)

    req = Request('PUT', url, user, json=customer_data)
    return req


def gen_delete(config):
    err = config.random_error('customers', 'delete')

    customer_id = make_customer_id(config, err)
    config.customers_database.remove(customer_id)
    url = '{0}/{1}'.format(config.customers_url, customer_id)
    user = Request.make_user(True, err)

    req = Request('DELETE', url, user)
    return req


def gen_request(config, customers):
    method = config.random_method('customers')
    if not config.customers_database:
        return gen_post(config, customers)
    if method == 'get':
        return gen_get(config)
    elif method == 'post':
        return gen_post(config, customers)
    elif method == 'put':
        return gen_put(config)
    else:
        return gen_delete(config)


def customer_request_generator(config):
    customers = customer_generator(config)
    # do an initial POST to be sure there's at least one customer
    yield gen_post(config, customers)
    while True:
        yield gen_request(config, customers)
