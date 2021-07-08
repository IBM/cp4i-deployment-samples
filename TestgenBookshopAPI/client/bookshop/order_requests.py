# Requests on the Order resource

import uuid

from .orders import order_generator
from .request import Request


def make_customer_id(config, err, customer_id=None):
    id = str(uuid.uuid4()) if not customer_id else customer_id
    if err == 'invalid_url':
        # make the UUID invalid
        return id.replace('-', '.')
    elif err == 'customer_not_found':
        return id
    else:
        return config.customers_database.get_random_key() if not customer_id else id


def make_order_id(config, err, order_id=None):
    id = str(uuid.uuid4()) if not order_id else order_id
    if err == 'invalid_url':
        # make the UUID invalid
        return id.replace('-', '.')
    elif err == 'order_not_found':
        return id
    else:
        return config.orders_database.get_random_key() if not order_id else order_id


def make_status(config):
    if config.random_int(2) == 0:
        status = 'approved'
    else:
        status = 'delivered'
    return status


def clean_order(order):
    """Ensure that an order has no error markers"""
    # quantity divisible by 5 implies that the book is out if stock
    if order['quantity'] % 5 == 0 and order['quantity']:
        order['quantity'] -= 1


def set_book_not_found(config, order):
    index = config.random_int(len(order['book_ids']))
    order['book_ids'][index] = str(uuid.uuid4())


def set_invalid_input(order):
    del order['quantity']


def set_out_of_stock(order):
    order['quantity'] = 5


def gen_post(config, orders):
    err = config.random_error('orders', 'post')

    order = next(orders)

    customer_id = make_customer_id(config, err, customer_id=order['customer_id'])
    url = '{0}/{1}/orders'.format(config.customers_url, customer_id)
    user = Request.make_user(True, err)

    clean_order(order)

    # customer ID must match
    order['customer_id'] = customer_id

    # add errors according to the configuration
    if err == 'book_not_found':
        set_book_not_found(config, order)
    elif err == 'invalid_input':
        set_invalid_input(order)

    req = Request('POST', url, user, json=order)
    return req


def gen_get(config):
    err = config.random_error('orders', 'get')

    customer_id = make_customer_id(config, err)
    order_id = make_order_id(config, err)
    url = '{0}/{1}/orders/{2}'.format(config.customers_url, customer_id, order_id)
    user = Request.make_user(False, err)

    req = Request('GET', url, user)
    return req


def gen_put(config):
    err = config.random_error('orders', 'put')
    order_id, order_data = config.orders_database.get_random_row()

    customer_id = make_customer_id(config, err, order_data['customer_id'])
    order_id = make_order_id(config, err, order_id)
    url = '{0}/{1}/orders/{2}'.format(config.customers_url, customer_id, order_id)
    user = Request.make_user(True, err)
    clean_order(order_data)

    order_data['status'] = make_status(config)
    if order_data['status'] == 'delivered':
        order_data['ship_date'] = '2020-11-02'

    # add errors according to the configuration
    if err == 'book_not_found':
        set_book_not_found(config, order_data)
    elif err == 'invalid_input':
        set_invalid_input(order_data)
    elif err == 'out_of_stock':
        set_out_of_stock(order_data)

    req = Request('PUT', url, user, json=order_data)
    return req


def gen_delete(config):
    err = config.random_error('orders', 'delete')

    customer_id = make_customer_id(config, err)
    order_id = make_order_id(config, err)
    url = '{0}/{1}/orders/{2}'.format(config.customers_url, customer_id, order_id)
    user = Request.make_user(True, err)
    req = Request('DELETE', url, user)
    config.orders_database.remove(order_id)
    return req


def gen_request(config, orders):
    method = config.random_method('orders')
    if not config.customers_database or not config.books_database:
        return None
    if not config.orders_database:
        return gen_post(config, orders)
    if method == 'get':
        return gen_get(config)
    elif method == 'post':
        return gen_post(config, orders)
    elif method == 'put':
        return gen_put(config)
    else:
        return gen_delete(config)


def order_request_generator(config):
    orders = order_generator(config)
    if not config.customers_database or not config.books_database:
        yield None
    while True:
        yield gen_request(config, orders)
