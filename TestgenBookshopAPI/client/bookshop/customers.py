# Create Customer objects

import re
import string

import names

NONALPHA_RE = re.compile('[^A-Za-z]')


def make_username(name):
    username = NONALPHA_RE.sub('', name).lower()
    return username or 'x'


def make_password(config):
    n = 7 + config.random_int(5)
    password = ''.join([config.random.choice(list(string.ascii_letters)) for _ in range(n)])
    password += config.random.choice(list(string.digits))
    return password


def make_phone_number(config):
    code = ''.join([config.random.choice(list(string.digits)) for _ in range(4)])
    number = ''.join([config.random.choice(list(string.digits)) for _ in range(6)])
    return '0{0} {1}'.format(code, number)


def make_customer(config):
    first_name = names.get_first_name()
    last_name = names.get_last_name()

    username_first = make_username(first_name)
    username_last = make_username(last_name)
    username = '{0}{1}'.format(username_first[0], username_last)
    email = '{0}.{1}@freemail.com'.format(username_first, username_last)
    password = make_password(config)
    phone = make_phone_number(config)

    customer = {
        'username': username,
        'first_name': first_name,
        'last_name': last_name,
        'email': email,
        'password': password,
        'phone': phone
    }

    return customer


def customer_generator(config):
    """ Generates an infinite sequence of customers
        with randomly generated names
    """
    while True:
        yield make_customer(config)
