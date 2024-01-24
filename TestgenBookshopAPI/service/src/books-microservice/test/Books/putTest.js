const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');


describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
    }
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3afdc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(403)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '403')
                assert.equal(res.body.message, 'The caller does not have permission to perform the operation')
                done();
            });
    });
});

describe('PUT /books', function () {
    it('respond with 401 if no authorization provided', function (done) {
        let data = {
            "title": "Book 1039",
        }
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3afdc32')
            .send(data)            
            .set('Accept', 'application/json')
            .expect('Content-Type', /json/)
            .expect(401)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '401');
                assert.equal(res.get('WWW-Authenticate'), 'Access to this resource requires authentication')
                assert.equal(res.body.message, 'The caller could not be authenticated');
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 415 if content-type is not json', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3afdc32')
            .set('Accept', 'application/json')
            .set('Content-Type', 'text/html')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(415)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '415');
                assert.equal(res.body.message, 'Content-Type is missing or is not supported');
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
    }
    it('respond with 400 if the book_id is not a valid UUID', function (done) {
        request(app)
            .put('/books/cd46b818-e714-b98-38')
            .send(data)            
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The book ID is invalid');
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "James Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-13aab3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 400 if url book id does not match body id', function (done) {
        request(app)
            .put('/books/cd46b101-a714-4e55-b978-1b9bb3a9da32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Book ID param does not match the specified ID');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "James Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-13acb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 404 if the book does not exist', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-13acb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.message, 'The requested book was not found in the shop');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "James Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 400 if the users changes the author', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The author of a book cannot be changed');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 5",
        "author": "An Author",
        "publisher": "test",
        "isbn": "9012475399919",
        "format": "stone",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 400 if the users attempts to change the isbn', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Invalid value provided for format');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "author": "An Author",
        "publisher": "test",
        "isbn": "9012475399919",
        "format": "stone",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 400 if the user does not provide a required field', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Title is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "Another Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 200 if multiple fields are updated', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                assert.equal(res.body.book.author, 'Another Author');
                assert.equal(res.body.book.format, 'digital')
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "An Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
    }
    it('respond with 200 if a single fields are updated', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                assert.equal(res.body.book.title, 'Book 1039');
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "title": "Book 1039",
        "author": "An Author",
        "publisher": "test949",
        "isbn": "9012475399729",
        "format": "digital",
        "date": "2001-01-01",
        "book_id": 'cd46b818-e714-4e55-b978-1b9bb3a9dc32',
        "author_id": 'cab3318e-3291-41ac-ab08-064634808e5e',
        "someExtraData": "randomStuff"
    }
    it('respond with 200 update successful, ignoring any additional fields not in spec', function (done) {
        request(app)
            .put('/books/cd46b818-e714-4e55-b978-1b9bb3a9dc32')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object')
                assert.notProperty(res.body.book, 'someExtraData')
                done();
            });

    });
});
