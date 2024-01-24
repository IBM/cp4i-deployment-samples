# Requests on the Book resource

import uuid

from .books import book_generator
from .request import Request


def make_book_id(config, err=None):
    id = str(uuid.uuid4())
    if err == 'invalid_input':
        # make the UUID invalid
        id = id.replace('-', '.')
    elif err == 'not_found':
        return id
    else:
        id = config.books_database.get_random_key()
    return id


def make_author_id(book):
    return book.get('author_id', str(uuid.uuid4()))


def make_category(book):
    return book.get('category', 'computing')


def replace_first_name(author, new_name):
    found = author.find(' ')
    if found >= 0:
        author = author[found + 1:]
    return '{0} {1}'.format(new_name, author)


def clean_book(book):
    """Ensure that a book has no error markers"""

    # '92' in the ISBN implies a conflict
    book['isbn'] = book['isbn'].replace('92', '93')

    # '303' in the ISBN means the book is unavailable
    book['isbn'] = book['isbn'].replace('303', '304')

    # Author called 'Rob' doesn't exist
    if book['author'].startswith('Rob'):
        book['author'] = replace_first_name(book['author'], 'Janet')

    # Author called 'James' implies a conflict
    if book['author'].startswith('James'):
        book['author'] = replace_first_name(book['author'], 'Suzanne')


def set_invalid_input(book):
    del book['author']


def set_exists(book):
    book['isbn'] = book['isbn'][:-2] + '92'


def set_unavailable(book):
    book['isbn'] = book['isbn'][:-3] + '303'


def set_unknown(book):
    book['author'] = 'Robert Unknown'


def set_invalid_update(book):
    book['author'] = 'James Conflict'


def gen_post(config, books):
    err = config.random_error('books', 'post')

    url = config.books_url
    user = Request.make_user(True, err)
    book = next(books)
    clean_book(book)

    # add errors according to the configuration
    if err == 'invalid_input':
        set_invalid_input(book)
    elif err == 'exists':
        set_exists(book)
    elif err == 'unavailable':
        set_unavailable(book)
    elif err == 'unknown':
        set_unknown(book)

    req = Request('POST', url, user, json=book)
    return req


def gen_get(config):
    err = config.random_error('books', 'get')

    book_id = make_book_id(config, err)
    url = '{0}/{1}'.format(config.books_url, book_id)
    user = Request.make_user(False, err)

    req = Request('GET', url, user)
    return req


def gen_put(config, books):
    err = config.random_error('books', 'put')

    book_id = make_book_id(config, err)
    url = '{0}/{1}'.format(config.books_url, book_id)
    user = Request.make_user(True, err)
    book = config.books_database.get(book_id, next(books))
    if 'book_id' not in book:
        book['book_id'] = book_id
    if 'author_id' not in book:
        book['author_id'] = make_author_id(book)
    if 'category' not in book:
        book['category'] = make_category(book)
    if err == 'invalid_update':
        set_invalid_update(book)

    req = Request('PUT', url, user, json=book)
    return req


def gen_delete(config):
    err = config.random_error('books', 'delete')

    book_id = make_book_id(config, err)
    url = '{0}/{1}'.format(config.books_url, book_id)
    user = Request.make_user(True, err)
    config.books_database.remove(book_id)
    req = Request('DELETE', url, user)
    return req


def gen_request(config, books):
    if not config.books_database:
        return gen_post(config, books)
    method = config.random_method('books')
    if method == 'get':
        return gen_get(config)
    elif method == 'post':
        return gen_post(config, books)
    elif method == 'put':
        return gen_put(config, books)
    else:
        return gen_delete(config)


def book_request_generator(config):
    books = book_generator(config)
    # do an initial POST to be sure there's at least one book
    yield gen_post(config, books)
    while True:
        yield gen_request(config, books)
