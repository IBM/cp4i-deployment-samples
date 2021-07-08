# Configuration for the bookshop client

import os

import numpy as np
import yaml

from .virtual_db import Table

MODULE_DIRECTORY = os.path.dirname(__file__)


class Config:
    BOOKS_DATABASE = os.path.join(MODULE_DIRECTORY, 'books.db')
    CONFIG_FILE = os.path.join(MODULE_DIRECTORY, 'config.yaml')

    BOOKSHOP_SERVICE_URL = 'https://localhost:5000/v1'

    def __init__(self, args):
        self.books_file = args.database_file or Config.BOOKS_DATABASE
        self.books_database = Table(random_number_generator=self.random_int)
        self.customers_database = Table(
            random_number_generator=self.random_int)
        self.orders_database = Table(random_number_generator=self.random_int)
        self.request_count = args.count
        self.verbose = args.verbose or args.debug
        self.debug = args.debug
        self.async_api = args.async_api
        self.looping_api = args.looping_api
        self.verify = args.cert_verify or args.verify

        self.service_url = args.url or Config.BOOKSHOP_SERVICE_URL
        self.books_url = args.books_url or '{0}/books'.format(self.service_url)
        self.customers_url = args.customers_url or '{0}/customers'.format(
            self.service_url)
        self.client_id = args.client_id

        seed = args.seed if args.seed > 0 else np.random.randint(
            1, np.iinfo(np.int32).max)
        self.random = np.random.RandomState(seed)

        config_file = args.config_file or Config.CONFIG_FILE
        with open(config_file) as config:
            distributions = yaml.safe_load(config)
        distributions['resources'] = Distribution(
            self.random, distributions['resources'])
        for resource in ['books', 'customers', 'orders']:
            distributions['methods'][resource] = Distribution(
                self.random, distributions['methods'][resource])
            for method in ['delete', 'get', 'post', 'put']:
                distributions['errors'][resource][method] = Distribution(self.random,
                                                                         distributions['errors'][resource][method])
        self.distributions = distributions

    def random_resource(self):
        return self.distributions['resources'].get()

    def random_method(self, resource):
        return self.distributions['methods'][resource].get()

    def random_error(self, resource, method):
        return self.distributions['errors'][resource][method].get()

    def random_int(self, n):
        return self.random.randint(0, n)

    def random_pareto(self):
        return self.random.pareto(2)


class Distribution:
    """Random selection from a weighted distribution"""

    def __init__(self, random, weights):
        total_weight = 0
        entries = []
        for key, weight in weights.items():
            total_weight += weight
            entries.append((key, total_weight))
        self.entries = entries
        self.total_weight = total_weight
        self.random = random

    def get(self):
        n = self.random.randint(0, self.total_weight - 1)
        for key, weight in self.entries:
            if n < weight:
                return key
        raise Exception('Impossible case')
