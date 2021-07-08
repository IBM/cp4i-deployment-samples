# Generate the books database from a directory of RDF files

import argparse
import json
import os
import sys

import untangle

DEFAULT_BOOK_DB = 'books.db'


def make_book(args, rdf_file):
    book = None
    doc = untangle.parse(rdf_file)
    try:
        ebook = doc.rdf_RDF.pgterms_ebook
        title = ebook.dcterms_title.cdata
        author = ebook.dcterms_creator.pgterms_agent.pgterms_name.cdata
        publisher = ebook.dcterms_publisher.cdata
        date = ebook.dcterms_issued.cdata
        language = ebook.dcterms_language.rdf_Description.rdf_value.cdata
        # avoid issues with character sets
        if language == 'en':
            book = {
                'title': title,
                'author': author,
                'publisher': publisher,
                'date': date
            }
    except AttributeError as err:
        pass
    return book


def make_books_db(args):
    limit = args.count
    count = 0
    with os.scandir(args.root_dir) as sub_dirs, \
            open(args.output, 'w') as db:
        for sub_dir in sub_dirs:
            if limit > 0 and count >= limit:
                break
            for filename in os.listdir(sub_dir.path):
                if filename.lower().endswith('.rdf'):
                    rdf_file = os.path.join(sub_dir.path, filename)
                    book = make_book(args, rdf_file)
                    if book:
                        json.dump(book, db, separators=(',', ':'))
                        db.write('\n')
                        count += 1


def make_argument_parser():
    parser = argparse.ArgumentParser(
        description='Generate the books database from a directory of RDF files')
    parser.add_argument('--count', type=int, default=0,
                        metavar='N', help='write at most N records')
    parser.add_argument('-o', '--output', default=DEFAULT_BOOK_DB,
                        metavar='FILE', help='write the database to FILE')
    parser.add_argument('root_dir', metavar='RDF-DIR',
                        help='directory of RDF files')
    return parser


def main(args):
    parser = make_argument_parser()
    args = parser.parse_args(args)
    make_books_db(args)


if __name__ == "__main__":
    main(sys.argv[1:])
