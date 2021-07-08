# Create Orders for customers

def make_customer_id(config):
    return config.customers_database.get_random_key()


def make_book_ids(config):
    rand_books = config.random_pareto()
    n_books = int(rand_books * 5) + 1 if config.looping_api else 1
    return [config.books_database.get_random_key() for _ in range(n_books)]


def make_order(config):
    customer_id = make_customer_id(config)
    book_ids = make_book_ids(config)
    quantity = config.random_int(2) + 1
    status = 'placed'

    order = {
        'customer_id': customer_id,
        'book_ids': book_ids,
        'quantity': quantity,
        'status': status
    }

    return order


def order_generator(config):
    """Generates an infinite sequence of orders"""
    while True:
        yield make_order(config)
