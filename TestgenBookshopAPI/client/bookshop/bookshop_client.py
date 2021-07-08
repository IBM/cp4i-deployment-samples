# Bookshop API V1 client

import argparse
import json
import requests
import sys
import urllib3


from .book_requests import book_request_generator
from .config import Config
from .customer_requests import customer_request_generator
from .order_requests import order_request_generator


def request_generator(config):
    books = book_request_generator(config)
    customers = customer_request_generator(config)
    orders = order_request_generator(config)
    # maximum number of requests to make (0 = unlimited)
    limit = max(config.request_count, 0)
    # number of requests we've made
    count = 0
    while not limit or count < limit:
        resource = config.random_resource()
        if resource == 'books':
            req = next(books)
        elif resource == 'customers':
            req = next(customers)
        elif resource == 'orders':
            req = next(orders)
            if req is None and not config.customers_database:
                req = next(customers)
                resource = 'customers'
            elif req is None:
                req = next(books)
                resource = 'books'
        else:
            raise Exception('Unsupported resource type: ' + resource)
        yield req, resource
        count += 1


def debug_request(config, req, resp=None):
    if resp is not None:
        if config.verbose:
            print(req.method, req.url, resp.status_code)
        if config.debug:
            headers = {}
            headers.update(resp.headers)
            print(json.dumps(headers, indent=2))
            if resp.text:
                try:
                    print(json.dumps(resp.json(), indent=2))
                except:
                    print(resp.text)
    else:
        if config.debug:
            print(json.dumps(req.headers, indent=2))
            if req.json:
                print(json.dumps(req.json, indent=2))


def send_requests(config):
    generator = request_generator(config)
    for req, res_type in generator:
        debug_request(config, req)
        req.headers['X-Bookshop-Async'] = str(config.async_api)
        if config.client_id:
            req.headers['X-IBM-Client-Id'] = config.client_id
        resp = requests.request(req.method, req.url,
                                params=req.params,
                                headers=req.headers,
                                json=req.json,
                                auth=req.auth,
                                verify=config.verify)
        if resp.status_code == 201 and req.method == 'POST':
            resp_json = resp.json()
            if res_type == 'books':
                config.books_database[resp_json['book_id']] = resp_json
            elif res_type == 'customers':
                config.customers_database[resp_json['customer_id']] = resp_json
            elif res_type == 'orders':
                config.orders_database[resp_json['order_id']] = resp_json

        debug_request(config, req, resp)


def make_argument_parser():
    parser = argparse.ArgumentParser(description='Bookshop API V1 client')
    parser.add_argument('--url', help='common service URL')
    parser.add_argument('--client-id', help='apic catalog client id')
    parser.add_argument(
        '--books-url', help='books endpoint (overrides the common URL)')
    parser.add_argument('--customers-url',
                        help='customers endpoint (overrides the common URL)')
    parser.add_argument('--count', type=int, default=1,
                        metavar='N', help='number of requests (default=1)')
    parser.add_argument('--config-file', metavar='FILE',
                        help='configuration file')
    parser.add_argument('--database-file', metavar='FILE',
                        help='books database file')
    parser.add_argument('--cert-verify', metavar='FILE',
                        help='certificate file (.pem) for HTTPS verification')
    parser.add_argument('--no-verify', action='store_false', dest='verify',
                        help='disable HTTPS verification')
    parser.add_argument('--no-async', action='store_false', dest='async_api',
                        help='disable asynchronous behaviour in the API')
    parser.add_argument('--no-loops', action='store_false', dest='looping_api',
                        help='disable looping behaviour in the API')
    parser.add_argument('--seed', type=int, default=0,
                        help='random number SEED to reproduce a request sequence')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='show request summary')
    parser.add_argument('-vv', '--debug', action='store_true',
                        help='show request detail')
    return parser


def main(args):
    parser = make_argument_parser()
    args, unknown = parser.parse_known_args(args)
    config = Config(args)
    if config.verify is False:
        urllib3.disable_warnings()
    send_requests(config)


if __name__ == "__main__":
    main(sys.argv[1:])
