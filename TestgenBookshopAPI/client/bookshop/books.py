# Create Book objects from the books database

import json
import re

# reduce titles to a single line
TITLE_RE = re.compile('\n.*')

# remove authors after the first
AUTHOR_RE_1 = re.compile('[;\n].*')

# rewrite 'Austen, Jane' --> 'Jane Austen'
AUTHOR_RE_2 = re.compile('([^,]*), *(.*)')


def make_title(book):
    title = book['title']
    title = TITLE_RE.sub('', title.strip())
    return title if title else 'Unknown'


def make_author(book):
    author = book['author']
    author = AUTHOR_RE_1.sub('', author.strip())
    author = AUTHOR_RE_2.sub(r'\2 \1', author)
    return author if author else 'Anonymous'


def make_isbn(config, book):
    publisher = config.random_int(1000)
    publication = config.random_int(100000)
    checksum = config.random_int(10)
    isbn = '0{0:03d}{1:05d}{2:1d}'.format(publisher, publication, checksum)
    if book['date'] > '2007':
        isbn = '978' + isbn
    return isbn


def make_format(config):
    n = config.random_int(10)
    if n < 3:
        return 'hardback'
    elif n < 7:
        return 'paperback'
    else:
        return 'digital'


def make_language(config):
    n = config.random_int(100)
    if n < 15:
        return 'fr'
    else:
        return 'en'


def make_book(config, line):
    book = json.loads(line)
    book['title'] = make_title(book)
    book['author'] = make_author(book)
    book['isbn'] = make_isbn(config, book)
    book['format'] = make_format(config)
    book['language'] = make_language(config)
    return book


def book_generator(config):
    """ Generates an infinite sequence of books.
        Once it's been through the entire database it will start again from the beginning.
    """
    while True:
        with open(config.books_file) as db:
            for line in db:
                yield make_book(config, line)
